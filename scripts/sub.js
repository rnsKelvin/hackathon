// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

//npx hardhat run   --network heco_test scripts/Pay.js
//npx hardhat run   --network bsc_test scripts/Pay.js
// npx hardhat run   --network bsc_mainnet scripts/Pay.js
//npx hardhat run  scripts/sub.js
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


    tokens = [usdt.address,met.address]
    const Pay = await hre.ethers.getContractFactory("Pay");
    const pay = await Pay.deploy(tokens, usdt.address, _weth.address, factory.address,accounts[0]);
    await pay.deployed();
    console.log("Pay deployed to:", pay.address);
    _merchant = accounts[2];
    _merchantId = 1000;
    await pay.addMerchant(_merchant, 1000, 10, 100);
    await pay.addMerchant(accounts[3], 1001, 10, 100);
    await usdt.approve(pay.address, web3.utils.toWei("100010", "ether"));
    await  pay.subScribes(_merchant)
    await  pay.subScribes(accounts[3])
    console.log("usdt:",usdt.address,"met:",met.address)


   tk=  await  pay.subScribe(accounts[0],_merchant);
    console.log(tk.toString())

    tk=  await  pay.subScribe(accounts[0],accounts[3]);
    console.log(tk.toString())

    await  pay.cancelSubScribe(_merchant)
    tk=  await  pay.subScribe(accounts[0],_merchant);
    console.log(tk.toString())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
