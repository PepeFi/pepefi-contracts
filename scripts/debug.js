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
    let vault = Vault.attach(vaults[1])

    await vm.addLiquidity(100, vault.address)
}

main()