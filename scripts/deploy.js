// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

//npx hardhat run   --network heco_test scripts/Pay.js
//npx hardhat run   --network bsc_test scripts/deploy.js
// npx hardhat run   --network bsc_mainnet scripts/Pay.js
//npx hardhat run  scripts/deploy.js
async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled

    // We get the contract to deploy
    signers = await hre.ethers.getSigners();
    accounts = await web3.eth.getAccounts();
    _zero = "0x0000000000000000000000000000000000000000"
    const UsToken = await hre.ethers.getContractFactory("UsToken");
    _total = "100000000000000000000000000";
    const met = await UsToken.deploy("MET", "MET", _total);
    await met.deployed();
    console.log("MET deployed to:", met.address);

    const UsdtToken = await hre.ethers.getContractFactory("UsToken");
    _total = "100000000000000000000000000";
    const usdt = await UsdtToken.deploy("USDT", "USDT", _total);
    await usdt.deployed();
    console.log("usdt deployed to:", usdt.address);

    const WETH = await hre.ethers.getContractFactory("WETH9");
    const _weth = await WETH.deploy();
    await _weth.deployed();
    console.log("weth deployed to:", _weth.address);

    const factorytory = await ethers.getContractFactory("PancakeFactory");
    const factory = await factorytory.deploy(accounts[0]);
    await factory.deployed();
    console.log("factory deployed to:", factory.address);


    tokens = [usdt.address]
    const Pay = await hre.ethers.getContractFactory("Pay");
    const pay = await Pay.deploy(tokens, usdt.address, _weth.address, factory.address,"0xF8764265b6E929cF2bedc05D2cc1188195ba8e82");
    await pay.deployed();
    console.log("Pay deployed to:", pay.address);
    _wbnb = _weth.address
   // fra = await ethers.getContractAt("WBNB", _wbnb);
    //0x11b9ffd906d873a6e0fe381fdcc92398811cacfa972632bd94e2ef84e70a104d
    console.log("initial code:", await factory.INIT_CODE_PAIR_HASH());
    let _factory = factory.address;
    const Router = await ethers.getContractFactory("PancakeRouter01");
    const router = await Router.deploy(_factory, _wbnb);
    await router.deployed();
    console.log("cake router deployed to:", router.address);

    let tm = Date.parse(new Date()) / 1000;
    let deadline = tm + 10000;

    tx = await usdt.approve(router.address, ethers.utils.parseEther("10000"));
    console.log("usdt approve tx:",tx.hash.toString())
    // await _weth.deposit({value: ethers.utils.parseEther("10")});
    //
    // await _weth.approve(router.address, ethers.utils.parseEther("10"));
    tx =  await met.approve(router.address, ethers.utils.parseEther("10000"));
    console.log("met approve tx:",tx.hash.toString())
    _devaddr = accounts[0];
    sleep(100000);
    // tx = await router.addLiquidity(usdt.address, _wbnb, ethers.utils.parseEther("1000"), ethers.utils.parseEther("10"), 0, 0, _devaddr, deadline)
    // console.log(tx.hash.toString())
    // let _usdt_bnb = await factory.getPair(usdt.address, _wbnb);
    // console.log("usdt_bnb pair:", _usdt_bnb);
    // await router.addLiquidityETH(don.address, ethers.utils.parseEther("1"), 0, 0, accounts[0], deadline, {value: ethers.utils.parseEther("0.01")})
    tx = await router.addLiquidity(usdt.address, met.address, ethers.utils.parseEther("10000"), ethers.utils.parseEther("10000"), 0, 0, _devaddr, deadline)
    console.log(tx.hash.toString())
    let _usdt_met = await factory.getPair(usdt.address, met.address);
    console.log("_usdt_met pair:", _usdt_met);

    _merchant = accounts[0];
    _merchantId = 1000;
   tx= await pay.addMerchant(accounts[0], 1000, 10, 100);
   console.log("add:",tx.hash.toString())
    // tokenAmountIn = await pay.getTokenAmount(met.address, ethers.utils.parseEther("10"));
    // console.log("token amount:", (tokenAmountIn / 1e18).toString());
    // await met.approve(pay.address, ethers.utils.parseEther("12"));
    // tx = await pay.payOrder(ethers.utils.parseEther("10"), ethers.utils.parseEther("12"), 199999, met.address, _merchant, _merchantId);
    // console.log("pay txid:", tx.hash.toString())
    //
    // merchantBal = await pay.getMerchantBalance(_merchant,usdt.address);
    // console.log("merchant Bal:", (merchantBal / 1e18).toString())
    // merchantBal = await pay.getMerchantBalance(accounts[0],usdt.address);
    // console.log("owner Bal:", (merchantBal / 1e18).toString())
    // await pay.merchantWithdraw(usdt.address);
    // merchantBal = await pay.getMerchantBalance(accounts[0],usdt.address);
    // console.log("owner Bal:", (merchantBal / 1e18).toString())
    // await pay.connect(signers[2]).merchantWithdraw(usdt.address);
    // merchantBal = await pay.getMerchantBalance(_merchant,usdt.address);
    // console.log("merchant Bal:", (merchantBal / 1e18).toString())
}
// MET deployed to: 0x3017BE898267c028eB5EFab761806002757d14df
// usdt deployed to: 0xE543cb3DD74f12cF7F8E50F0EA1785B2c5955d9F
// weth deployed to: 0x7DB3C69302C9Cab2aa92c4573D51752Ef2d0e1B7
// factory deployed to: 0x5393bB31C34fAAE0F6D036ab17D6DA04FaDe76bf
// Pay deployed to: 0x8742218C9B0e4af9f2c33a42a8F914F3f44c3Ca4
// initial code: 0x11b9ffd906d873a6e0fe381fdcc92398811cacfa972632bd94e2ef84e70a104d
// cake router deployed to: 0x1FBa18Be95113103bcC80c3aFd02aB13e99b2cc3
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
