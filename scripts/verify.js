const util = require('util');
const exec = util.promisify(require('child_process').exec);
var fs = require('fs');
const { ethers } = require("hardhat");

async function main() {
    let [signer] = await ethers.getSigners();

    var contracts = JSON.parse(fs.readFileSync('data_goerli.json', 'utf8'));
    console.log(contracts)

    console.log(signer.address)
    await exec(`npx hardhat verify "${contracts['WETH']}" --network goerli "${signer.address}"`)
}

main()