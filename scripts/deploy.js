const util = require('util');
const exec = util.promisify(require('child_process').exec);

const hre = require("hardhat");
const { promises: { readdir } } = require('fs')
const fs = require("fs");
const { ethers } = require("hardhat");

let acceptedCollections;

if (process.env.HARDHAT_NETWORK == 'goerli')
{

    acceptedCollections = [
        { name: 'Multifaucet NFT', address: '0xf5de760f2e916647fd766B4AD9E85ff943cE3A2b', imgSrc:'https://img.seadn.io/files/b4d419a67bc7dc52000e6d1336b24c46.png?fit=max&w=600', slug: 'multifaucet-nft-q55yxxitoz'},
    ]
}
else
{
    acceptedCollections = [
        { name: 'Bored Ape Yacht Club', address: '0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d',imgSrc:'/static/images/vaults/boredapeyachtclub.png', slug: 'boredapeyachtclub', },
        { name: 'Doodle', address: '0x8a90cab2b38dba80c64b7734e58ee1db38b8992e',imgSrc:'/static/images/vaults/doodles-official.png', slug: 'doodles-official'},
        { name: 'Moonbirds', address: '0x23581767a106ae21c074b2276d25e5c3e136a68b',imgSrc:'/static/images/vaults/proof-moonbirds.png', slug: 'proof-moonbirds'},
        { name: 'CloneX', address: '0x49cf6f5d44e70224e2e23fdcdd2c053f30ada28b',imgSrc:'/static/images/vaults/clonex.png', slug: 'clonex'},
        { name: 'CryptoDickbutts', address: '0x42069abfe407c60cf4ae4112bedead391dba1cdb', imgSrc: '/static/images/vaults/cryptodickbutts-s3.png', slug: 'cryptodickbutts-s3'},
        { name: 'Wrapped Cryptopunks', address: '0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6', imgSrc: '/static/images/vaults/wrapped-cryptopunks.png', slug: 'wrapped-cryptopunks'}
    ]
}




let abis = {}

abis['ERC20_ABI'] = '[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"owner","type":"address"},{"indexed":true,"name":"spender","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]'
abis['ERC721_ABI'] = '[{"inputs":[{"internalType":"address","name":"_admin","type":"address"},{"internalType":"address","name":"_nftfiHub","type":"address"},{"internalType":"address","name":"_loanCoordinator","type":"address"},{"internalType":"string","name":"_name","type":"string"},{"internalType":"string","name":"_symbol","type":"string"},{"internalType":"string","name":"_customBaseURI","type":"string"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"approved","type":"address"},{"indexed":true,"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"operator","type":"address"},{"indexed":false,"internalType":"bool","name":"approved","type":"bool"}],"name":"ApprovalForAll","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":true,"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"BASE_URI_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"LOAN_COORDINATOR_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"approve","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"baseURI","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_tokenId","type":"uint256"}],"name":"burn","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_tokenId","type":"uint256"}],"name":"exists","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"getApproved","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"hub","outputs":[{"internalType":"contract INftfiHub","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"operator","type":"address"}],"name":"isApprovedForAll","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"loans","outputs":[{"internalType":"address","name":"loanCoordinator","type":"address"},{"internalType":"uint256","name":"loanId","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"},{"internalType":"uint256","name":"_tokenId","type":"uint256"},{"internalType":"bytes","name":"_data","type":"bytes"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"ownerOf","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"safeTransferFrom","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"tokenId","type":"uint256"},{"internalType":"bytes","name":"_data","type":"bytes"}],"name":"safeTransferFrom","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"operator","type":"address"},{"internalType":"bool","name":"approved","type":"bool"}],"name":"setApprovalForAll","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_customBaseURI","type":"string"}],"name":"setBaseURI","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_account","type":"address"}],"name":"setLoanCoordinator","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"_interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"tokenURI","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"transferFrom","outputs":[],"stateMutability":"nonpayable","type":"function"}]'

function getGenericVaultParams(mynft, fnft, uw, is_platform) {
    let vaultDetails = { 
        VAULT_NAME: "Basic Vault", 
        VAULT_DESCRIPTION: "Low Risk yield parking", 
        EXPIRY_IN: "7776000",
        EXTERNAL_LP_ENABLED: true, 
        PREVIOUS_VAULT: '0x0000000000000000000000000000000000000000',
        WHITELISTED_NFT_LPS: []
    }

    let collections = [mynft.address, fnft.address]

    let MAX_LTV = 800
    let MAX_DURATION = 365
    let slope = 100
    let APR = 50
    let MAX_LOAN = '300000000000000000000'
    let ALLOWED_APE_TRAITS = ['Fur-Solid Gold', 'Eyes-Blue Beams', 'Fur-Trippy', 'Clothes-Black Suit', 'Clothes-Pimp Coat']
    let ALLOWED_MAX_MULTIPLIER = [10000, 10000, 10000, 10000, 10000]

    if (is_platform == false){
        MAX_LTV = 500
        MAX_DURATION = 90
        slope = 1
        APR = 450
        MAX_LOAN = '30000000000000000000'
        ALLOWED_MAX_MULTIPLIER = [800, 350, 350, 300, 125]
    }

    let collection_details = [
                    {
                        COLLECTION: mynft.address, 
                        TYPE: 2,
                        VAULUATION_PERFORMER: '0x0000000000000000000000000000000000000000',
                        MAX_LTV: MAX_LTV, 
                        MAX_DURATION: MAX_DURATION,
                        APR: APR, 
                        slope: slope,
                        MAX_LOAN: MAX_LOAN,
                        ALLOWED_TRAITS: ALLOWED_APE_TRAITS,
                        TRAIT_MULTIPLIER: ALLOWED_MAX_MULTIPLIER

                    },
                    {
                        COLLECTION: fnft.address, 
                        TYPE: 1,
                        VAULUATION_PERFORMER: uw.address, //need to add this
                        MAX_LTV: MAX_LTV, 
                        MAX_DURATION: MAX_DURATION,
                        APR: APR, 
                        slope: slope,
                        MAX_LOAN: MAX_LOAN,
                        ALLOWED_TRAITS: [],
                        TRAIT_MULTIPLIER: []
                    }
                ]
    
                
    return [vaultDetails, collections, collection_details]

}

async function deployContracts(testnet=true, receivers=[]){
    let weth;
    let mynft;
    let fnft;
    let [signer] = await ethers.getSigners();
    let addresses = {}

    WETH_CONTRACT = '0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6';
    const feeData = await signer.provider.getFeeData();
    console.log(feeData)

    if (testnet == true) {
        const WETH = await ethers.getContractFactory("WETH");
        weth = await WETH.deploy(signer.address);
        await weth.deployed();  
        console.log("WETH Contract Deployed at " + weth.address);
        addresses['WETH'] = weth.address

        const MyNFT = await ethers.getContractFactory("MyNFT");
        mynft = await MyNFT.deploy("FakeApeYachtClub", "FAYC");
        await mynft.deployed();  
        console.log("FAYC Contract Deployed at " + mynft.address);
        addresses['FAYC'] = mynft.address

        const FNFT = await ethers.getContractFactory("FNFT");
        fnft = await FNFT.deploy("Fake Uniswap Position", "FUNI");
        await fnft.deployed();  
        console.log("FUNI Contract Deployed at " + fnft.address);
        addresses['FUNI'] = fnft.address

        for (let addy of receivers) {
            await weth.mint(addy)

            for (let i = 0; i < 2; i++){
                await mynft.mint(addy, `https://ik.imagekit.io/bayc/assets/ape${Math.floor(Math.random() * 10000) + 1}.png`)
                await fnft.mint(addy, `https://openseauserdata.com/files/8072fadbd3c00513bfd94d66252965cd.svg`)
            } 
        }

        WETH_CONTRACT = weth.address
    }
    

    const PepeAuction = await ethers.getContractFactory("PepeAuction");
    pe = await PepeAuction.deploy(WETH_CONTRACT);
    await pe.deployed();  
    console.log("Auction Contract Deployed at " + pe.address);
    addresses['Auction'] = pe.address


    const Oracle = await ethers.getContractFactory("Oracle");
    or = await Oracle.deploy(signer.address);
    await or.deployed(); 
    console.log("Oracle Contract Deployed at " + or.address);
    addresses['Oracle'] = or.address
    

    const Vault = await ethers.getContractFactory("Vault");
    vb = await Vault.deploy()
    await vb.deployed();  
    
    const UniswapWrapper = await ethers.getContractFactory("UniswapWrapper");
    uw = await UniswapWrapper.deploy(fnft.address, fnft.address)
    await uw.deployed();  
    console.log("Uniswap Wrapper Deployed at " + uw.address);
    addresses['Uni_Wrapper'] = uw.address

    const VaultManager = await ethers.getContractFactory("VaultManager");
    console.log({ASSET: WETH_CONTRACT, AUCTION_CONTRACT: pe.address, BASE_VAULT: vb.address, ORACLE_CONTRACT: or.address, PEPEFI_ADMIN: signer.address, VAULT_MANAGER: '0x0000000000000000000000000000000000000000'})
    let vm = await VaultManager.deploy({ASSET: WETH_CONTRACT, AUCTION_CONTRACT: pe.address, BASE_VAULT: vb.address, ORACLE_CONTRACT: or.address, PEPEFI_ADMIN: signer.address, VAULT_MANAGER: '0x0000000000000000000000000000000000000000'} );
    await vm.deployed();  
    console.log("Vault Manager Contract Deployed at " + vm.address);
    addresses['VM'] = vm.address

    await or.setVaultManager(vm.address);

    let [vDetails, Cs, cDetails] = getGenericVaultParams(mynft, fnft, uw, true)
    await vm.updatePlatformParams(Cs, cDetails)


    let [vDetails2, Cs2, cDetails2] = getGenericVaultParams(mynft, fnft, uw, false)
    await vm.createVault(vDetails2, Cs2, cDetails2)


    console.log("Vault created")

    if (testnet == true) {
        await or.updatePrices([mynft.address], ["1000000000000000000"]);
    }

    let vaults = await vm.getVaults()
    // await weth.addWhitelisted([vaults[0]])


    return [weth, mynft, fnft, pe, or, vb, vm, uw, WETH_CONTRACT, addresses]
}

async function deploy(){

    let [weth, mynft, fnft, pe, or, vb, vm, uw, WETH_CONTRACT, addresses] = await deployContracts()


    let ABI_STRING = ""
    let export_string = "module.exports = {"


    await exec("yarn run hardhat export-abi")
    let path = './abi/contracts'
    let dir = await readdir(path, { withFileTypes: true })

    dir.forEach((value) => {
        let name = value.name

        if (name.includes(".sol")){
            let full_path = path + "/" + name + "/" + name.replace(".sol", ".json");
            let contents = fs.readFileSync(full_path).toString().replace(/(\r\n|\n|\r)/gm,"")

            let var_name = name.replace(".sol", "").toUpperCase()
            
            ABI_STRING = ABI_STRING + "let " + var_name + "_ABI" + " = " + contents.replace(/\s/g, '') + "\n"  
            export_string = export_string + var_name + "_ABI,"
         
        }
    })

    ABI_STRING = ABI_STRING + "\n\n"

    ABI_STRING = ABI_STRING + "let WETH_CONTRACT='" + weth.address + "'\n"
    ABI_STRING = ABI_STRING + "let VAULT_MANAGER='" + vm.address + "'\n"
    ABI_STRING = ABI_STRING + "let ORACLE='" + or.address + "'\n\n"
    ABI_STRING = ABI_STRING + "let JPEG_NFT='" + mynft.address + "'\n\n"
    ABI_STRING = ABI_STRING + "let UNI_NFT='" + fnft.address + "'\n\n"

    export_string = export_string + "WETH_CONTRACT,ORACLE,VAULT_MANAGER,JPEG_NFT,UNI_NFT}"

    ABI_STRING = ABI_STRING + export_string

    if (process.env.HARDHAT_NETWORK == 'goerli'){
        fs.writeFileSync('config_goerli.js', ABI_STRING);   
        fs.writeFileSync('data_goerli.json', JSON.stringify(addresses, null, 2) , 'utf-8');
    }
    else{
        fs.writeFileSync('config.js', ABI_STRING);
        fs.writeFileSync('data.json', JSON.stringify(addresses, null, 2) , 'utf-8');
    }
}


if (require.main === module) {
    deploy()
}



module.exports = {deployContracts, getGenericVaultParams};