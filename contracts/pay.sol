// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "hardhat/console.sol";

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './uniswap/UniswapV2Library.sol';
import "./uniswap/IUniswapV2Factory.sol";
import "./uniswap/IUniswapV2Router02.sol";
import "./uniswap/IUniswapV2Callee.sol";
import "./uniswap/IUniswapV2Pair.sol";
import "./uniswap/IWETH.sol";

contract Pay is Ownable {
    using SafeMath for uint256;

    // bytes32 public root;

    IERC20  public tokenERC20;


    mapping(address => bool) baseTokenList;//稳定币
    address[] baseTokens;
    address  public adminer;
    address public FACTORY;
    address public WETH;
    address private feeWallet;
    IERC20 public usdtToken;

    //user=>merchant
    mapping(address => mapping(address => bool)) public subScribe;

    struct Merchant {
        uint256 merchantId;
        uint256 feePoint;
        uint256 feeDenominator;
        uint256 balance;
    }

    //    struct Scribe {
    //        address merchant;
    //        uint256 merchantId;
    //        uint256 lastTime;
    //    }

    //merchant=>token=>info
    mapping(address => mapping(address => Merchant)) public merchantInfo;
    /*
    payToken 用什么token支付的
    tokenAmount token 的数量
    payAmount   以u计算的应该支付的数量
    swapAmount  token swap后得到u的数量
    fee 手续费
    */
    event PayOrderEvent(uint256 orderId, address user, address payToken, uint256 tokenAmount, uint256 payAmount, uint256 swapAmount, uint256 fee);
    event MerchantWithdrawEvent(address user, address _usdt, uint256 amount);
    event SubScribe(address user, address merchant);
    event CancelSubScribe(address user, address merchant);
    event SubScribePay(address user, address merchant, address _token, uint256 amount, uint256 fee);

    receive() external payable {
        revert("R");
    }

    constructor(address[] memory tokens, address _usdt, address _weth, address _factory, address _feeWallet) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            baseTokenList[tokens[i]] = true;
            baseTokens.push(tokens[i]);
            //            merchantInfo[msg.sender][tokens[i]] = Merchant(
            //            {
            //            merchantId : 999999999,
            //            feePoint : 0,
            //            feeDenominator : 100,
            //            balance : 0
            //            }
            //            );
        }
        usdtToken = IERC20(_usdt);
        FACTORY = _factory;
        WETH = _weth;
        feeWallet = _feeWallet;

    }


    function setToken(address _tokenERC20, bool power) public onlyOwner {
        if (!baseTokenList[_tokenERC20]) {
            baseTokens.push(_tokenERC20);
        }
        baseTokenList[_tokenERC20] = power;

    }

    function setAdmin(address _admin) public onlyOwner {
        adminer = _admin;
    }

    //支持新增一个base token
    function addMerchantBase(address _merchant, uint256 _id, address _token, uint256 _point, uint256 _denominator) public onlyOwner {
        require(baseTokenList[_token], "error base token");
        if (merchantInfo[_merchant][_token].merchantId == 0) {
            merchantInfo[_merchant][_token] = Merchant(
            {
            merchantId : _id,
            feePoint : _point,
            feeDenominator : _denominator,
            balance : 0
            }
            );
        }

    }
    //添加商户
    function addMerchant(address _merchant, uint256 _id, uint256 _point, uint256 _denominator) public onlyOwner {
        for (uint256 i = 0; i < baseTokens.length; i++) {
            if (merchantInfo[_merchant][baseTokens[i]].merchantId == 0) {
                merchantInfo[_merchant][baseTokens[i]] = Merchant(
                {
                merchantId : _id,
                feePoint : _point,
                feeDenominator : _denominator,
                balance : 0
                }
                );
            }
        }
    }

    //修改商户信息
    function setMerchant(address _merchant, uint256 _point, uint256 _denominator) public onlyOwner {
        require(_denominator == 10 || _denominator == 100 || _denominator == 1000 || _denominator == 10000, "invalid denom");
        for (uint256 i = 0; i < baseTokens.length; i++) {
            Merchant storage merchant = merchantInfo[_merchant][baseTokens[i]];
            if (merchant.merchantId != 0) {
                merchant.feeDenominator = _denominator;
                merchant.feePoint = _point;
            }

        }

    }

    function getMerchantInfo(address _merchant, address token) public view returns (uint256, uint256, uint256){
        return (merchantInfo[_merchant][token].merchantId, merchantInfo[_merchant][token].feePoint, merchantInfo[_merchant][token].feeDenominator);
    }

    function getMerchantBalance(address _merchant, address token) public view returns (uint256){
        return merchantInfo[_merchant][token].balance;
    }

    function merchantWithdraw(address token) external {
        require(baseTokenList[token], "not allowed token");
        Merchant storage merchant = merchantInfo[msg.sender][token];
        require(merchant.balance > 0, "no balance");
        uint256 bal = IERC20(token).balanceOf(address(this));
        // console.log(bal/1e18);
        if (bal >= merchant.balance) {
            SafeERC20.safeTransfer(
                IERC20(token),
                address(msg.sender),
                merchant.balance
            );
            merchant.balance = 0;
            emit MerchantWithdrawEvent(msg.sender, token, merchant.balance);
        } else if (bal > 0) {
            SafeERC20.safeTransfer(
                IERC20(token),
                address(msg.sender),
                bal
            );
            merchant.balance = merchant.balance.sub(bal);
            emit MerchantWithdrawEvent(msg.sender, token, bal);
        }
    }


    function getTokenAmount(address _token, uint256 usdtAmount) public view returns (uint256){
        address pair = UniswapV2Library.pairFor(FACTORY, _token, address(usdtToken));
        (uint256 reserves0, uint256 reserves1,) = IUniswapV2Pair(pair).getReserves();
        (uint256 reserveUsdt, uint256 reserveToken) = IUniswapV2Pair(pair).token0() == address(usdtToken) ? (reserves0, reserves1) : (reserves1, reserves0);
        uint256 amountIn = UniswapV2Library.getAmountIn(
            usdtAmount,
            reserveToken,
            reserveUsdt
        );
        return amountIn;
    }

    function sellTokenToUsdt(uint256 amount, address _sender, address _token, address to) internal returns (uint256) {
        address pair = UniswapV2Library.pairFor(FACTORY, _token, address(usdtToken));
        (uint256 reserves0, uint256 reserves1,) = IUniswapV2Pair(pair).getReserves();
        (uint256 reserveUsdt, uint256 reserveToken) = IUniswapV2Pair(pair).token0() == address(usdtToken) ? (reserves0, reserves1) : (reserves1, reserves0);
        uint256 amountOut = UniswapV2Library.getAmountOut(
            amount,
            reserveToken,
            reserveUsdt
        );
        SafeERC20.safeTransferFrom(IERC20(_token), _sender, pair, amount);
        (uint256 amount0Out, uint256 amount1Out) =
        IUniswapV2Pair(pair).token0() == address(usdtToken) ? (amountOut, uint256(0)) : (uint256(0), amountOut);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
        return amountOut;
    }

    function convertEthToWETH(uint256 amount) internal {
        IWETH(WETH).deposit{value : amount}();
    }

    function changeMerchantBalance(address _merchant, address token, uint256 usdtAmount) internal returns (uint256) {
        if (merchantInfo[_merchant][token].feePoint != 0) {
            uint256 fee = usdtAmount.mul(merchantInfo[_merchant][token].feePoint).div(merchantInfo[_merchant][token].feeDenominator);
            //            merchantInfo[owner()][token].balance = merchantInfo[owner()][token].balance.add(fee);
            //            merchantInfo[_merchant][token].balance = merchantInfo[_merchant][token].balance.add(usdtAmount.sub(fee));
            SafeERC20.safeTransfer(IERC20(token), _merchant, usdtAmount.sub(fee));
            SafeERC20.safeTransfer(IERC20(token), feeWallet, fee);
            return fee;
        } else {
            //merchantInfo[_merchant][token].balance = merchantInfo[_merchant][token].balance.add(usdtAmount);
            SafeERC20.safeTransfer(IERC20(token), _merchant, usdtAmount);
        }
        return 0;
    }

    function subScribes(
        address _merchant
    ) public {
        require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0, "wrong param");
        uint256 _dec = ERC20(address(usdtToken)).decimals();
        require(ERC20(address(usdtToken)).allowance(msg.sender, address(this)) >= 100000 * (10 ** _dec), "low allownce");
        subScribe[msg.sender][_merchant] = true;
        emit SubScribe(msg.sender, _merchant);
    }

    function cancelSubScribe(
        address _merchant
    ) public {
        require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0, "wrong param");
        subScribe[msg.sender][_merchant] = false;
        emit CancelSubScribe(msg.sender, _merchant);
    }

    function subScribePay(address _merchant, address _user, address _token, uint256 usdtAmount) public onlyOwner {
        require(baseTokenList[_token], "not base token");
        require(subScribe[_user][_merchant], "not base token");
        SafeERC20.safeTransferFrom(IERC20(_token), _user, address(this), usdtAmount);
        uint256 fee = changeMerchantBalance(_merchant, _token, usdtAmount);
        emit SubScribePay(_user, _merchant, _token, usdtAmount, fee);
    }

    function payOrder(
        uint256 usdtAmount,
        uint256 tokenAmount,
        uint256 _orderid,
        address _token,
        address _merchant,
        uint256 _merchantId) external payable {
        if (baseTokenList[_token]) {
            require(merchantInfo[_merchant][_token].merchantId != 0 && merchantInfo[_merchant][_token].merchantId == _merchantId, "bad merchant");
        } else {
            require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0 && merchantInfo[_merchant][address(usdtToken)].merchantId == _merchantId, "bad merchant");
        }

        if (msg.value > 0) {//主币
            _token = address(0);
            convertEthToWETH(msg.value);
            uint256 _swapUsdtAmount = sellTokenToUsdt(msg.value, address(this), WETH, address(this));
            require(usdtAmount <= _swapUsdtAmount, "bad tokenAmount");
            if (_swapUsdtAmount > usdtAmount) {
                usdtToken.transfer(msg.sender, _swapUsdtAmount.sub(usdtAmount));
            }
            uint256 fee = changeMerchantBalance(_merchant, address(usdtToken), usdtAmount);
            emit PayOrderEvent(_orderid, msg.sender, _token, tokenAmount, usdtAmount, _swapUsdtAmount, fee);
        } else {
            //require(tokenList[_token] == true, "not allowed token");
            tokenERC20 = IERC20(_token);

            require(tokenERC20.balanceOf(address(msg.sender)) >= tokenAmount, "token balance is not enough");
            require(tokenERC20.allowance(msg.sender, address(this)) >= tokenAmount, "token allowance is not enough");
            if (!baseTokenList[_token]) {//非稳定币支付
                uint256 _swapUsdtAmount = sellTokenToUsdt(tokenAmount, msg.sender, _token, address(this));
                require(usdtAmount <= _swapUsdtAmount, "bad tokenAmount");
                if (_swapUsdtAmount > usdtAmount) {
                    usdtToken.transfer(msg.sender, _swapUsdtAmount.sub(usdtAmount));
                }
                uint256 fee = changeMerchantBalance(_merchant, address(usdtToken), usdtAmount);
                emit PayOrderEvent(_orderid, msg.sender, _token, tokenAmount, usdtAmount, _swapUsdtAmount, fee);
            } else {//稳定币支付
                SafeERC20.safeTransferFrom(IERC20(_token), address(this), address(this), usdtAmount);
                uint256 fee = changeMerchantBalance(_merchant, _token, usdtAmount);
                emit PayOrderEvent(_orderid, msg.sender, _token, tokenAmount, usdtAmount, 0, fee);
            }

        }


    }
}
