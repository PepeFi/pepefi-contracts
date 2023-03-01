const util = require('util');
const exec = util.promisify(require('child_process').exec);
var fs = require('fs');
const { ethers } = require("hardhat");

async function main() {
    let [signer] = await ethers.getSigners();
    var contracts = JSON.parse(fs.readFileSync('data_goerli.json', 'utf8'));
    const VaultManager = await ethers.getContractFactory("VaultManager");
    let vm = VaultManager.attach(contracts['VM'])
    let vaults = await vm.getVaults()

    const Vault = await ethers.getContractFactory("Vault");
    let vault = Vault.attach(vaults[0])
    let first = await vm.WHITELISTED_COLLECTIONS(0)
    let second = await vm.WHITELISTED_COLLECTIONS(1)

    console.log(await vm.getWhitelistedDetails(first))
    console.log(await vm.getWhitelistedDetails(second))

    // console.log(await vault.getWETHBalance())

    // const WETH = await ethers.getContractFactory("WETH");
    // let weth = WETH.attach(contracts['WETH'])
    // await weth.mint(signer.address)
    // console.log(await weth.balanceOf(signer.address))

    // await weth.approve(vault.address, ethers.constants.MaxUint256);

    // await vm.addLiquidity("1000000000000000000", vault.address)
}

main()