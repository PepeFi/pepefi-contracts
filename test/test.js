const { expect } = require("chai");
const { ethers } = require("hardhat");
const axios = require('axios')

const { mine } = require("@nomicfoundation/hardhat-network-helpers");
const {deployContracts, getGenericVaultParams} =  require("../scripts/deploy.js")
let owner;
let WETH_CONTRACT;
let vault;



//Use testnet NFT to take and repay loan
describe('Contract tests', () => {

    before('Deploy Contract and Transfer Tokens', async () => {
        [owner] = await ethers.getSigners();
        [weth, mynft, fnft, pe, s_or, svb, vm, uw, WETH_CONTRACT, addresses] = await deployContracts(testnet=true, receivers=[owner.address]);


        let vaults = await vm.getVaults()

        const Vault = await ethers.getContractFactory("Vault");
        vault = await Vault.attach(vaults[0]);
    })

    it("Basic Stuff", async function () {
        let collection = await vault.WHITELISTED_COLLECTIONS(0)
        let details = await vault.WHITELISTED_DETAILS(collection)

        expect(details.TYPE).to.equal(2);
    })

    it("Vault Deploy", async function () {
        let vaultDetails = {"VAULT_NAME":"SSS","VAULT_DESCRIPTION":"asdasds","EXPIRY_IN":1681801200,"EXTERNAL_LP_ENABLED":"true","PREVIOUS_VAULT":"0x0000000000000000000000000000000000000000","WHITELISTED_NFT_LPS":[]}
        let collections = [mynft.address]
        let coll_details = [{"COLLECTION":mynft.address,"TYPE":"1","VAULUATION_PERFORMER":"0x0000000000000000000000000000000000000000","MAX_LTV":400,"MAX_DURATION":45,"slope":1,"APR":450,"MAX_LOAN":"1000000000000000000","ALLOWED_TRAITS":["Fur-Solid Gold"],"TRAIT_MULTIPLIER":[200]}]
        await vm.createVault(vaultDetails, collections, coll_details)
    })

    it("Get Accepted Collections", async function () {
        let err = undefined;
        let array = [];
        let item;

        while (err === undefined) {
          try {
            item = await vm.WHITELISTED_COLLECTIONS(array.length);            
            let item_detail = await vm.getWhitelistedDetails(item)
            accepted_details = {}
            accepted_details['address'] = item_detail.COLLECTION
            accepted_details['traits'] = item_detail.ALLOWED_TRAITS
            accepted_details['multiplier'] = item_detail.TRAIT_MULTIPLIER
            accepted_details['type'] = item_detail.TYPE
            accepted_details['valuation_performer'] = item_detail.VAULUATION_PERFORMER
            accepted_details['MAX_LTV'] = item_detail.MAX_LTV
            accepted_details['MAX_DURATION'] = item_detail.MAX_DURATION
            accepted_details['APR'] = item_detail.APR
            accepted_details['slope'] = item_detail.slope
            accepted_details['MAX_LOAN'] = item_detail.MAX_LOAN

            array.push(accepted_details);
          } catch (e) {
            err = e;
          }
        }

        expect(array[0]['type']).to.equal(2);
        expect(array[1]['type']).to.equal(1);
        
    })

    it("Add Liquidity", async function () {
        amt = 10
        await weth.approve(vault.address, ethers.constants.MaxUint256);
        await vm.addLiquidity(amt, vault.address);
        
        expect(await vault.balanceOf(owner.address, 0)).to.equal(amt);
        expect(parseInt(await weth.balanceOf(vault.address))).to.greaterThanOrEqual(parseInt(amt));
    })

    // it("Delayed Liquidity", async function () {
    //     await mine(10000)
    //     await vm.addLiquidity(10, vault.address);
    // })

    it("Take and Repay ERC721 Loan", async function () {
        await weth.approve(vault.address, ethers.constants.MaxUint256);
        await vm.addLiquidity(String(10**18), vault.address);

        await mynft.approve(vault.address, 1)


        await vault.takeERC721Loan(mynft.address, 1, String(10**16),   30);
        await vm.addLiquidity(10, vault.address);

        let all_loans = await vault.getAllLoans()
        let curr_loan = all_loans[all_loans.length-1]
        let loanDetails = await vault._loans(curr_loan)

        expect((loanDetails.repaymentAmount/10**16).toFixed(3)).to.be.oneOf(['1.021']);
        expect(loanDetails.loanPrincipalAmount).to.equal('10000000000000000');

        await weth.approve(vault.address, ethers.constants.MaxUint256);

        expect(await vault.getWETHBalance()/10**18).to.be.oneOf([1]);

        await vault.repayLoan(curr_loan)

    })

    it("Take and Repay Financial Loan", async function () {
        await fnft.approve(vault.address, 1)
        await vault.takeERC721Loan(fnft.address, 1, String(10**16),   30);
        let all_loans = await vault.getAllLoans()
        let curr_loan = all_loans[all_loans.length-1]
        let loanDetails = await vault._loans(curr_loan)

        expect((loanDetails.repaymentAmount/10**16).toFixed(3)).to.be.oneOf(['1.021']);
        expect(loanDetails.loanPrincipalAmount).to.equal('10000000000000000');

        expect((await vault.getWETHBalance()/10**18).toFixed(3)).to.be.oneOf(['1.000']);

        await vault.repayLoan(curr_loan)

    })

    it("Rollover", async function () {

        await mynft.approve(vault.address, 2)
        await vault.takeERC721Loan(mynft.address, 2, String(10**16),   30);

        let [vaultDetails, collections, collection_details] = getGenericVaultParams(mynft, fnft, uw, false)
        await vm.createVault(vaultDetails, collections, collection_details)

        let vaults = await vm.getVaults()

        const Vault = await ethers.getContractFactory("Vault");
        let new_vault = await Vault.attach(vaults[vaults.length-1]);


        await vm.setRolloverVault(vault.address, new_vault.address)
        expect(await vm.NEXT_VAULT(vault.address)).to.equal(new_vault.address)
        
        await vm.withdrawLiquidity(100, vault.address)

        withdraw_queue = await vm.WITHDRAW_QUEUE(vault.address, 0)

        expect(withdraw_queue.shares).to.equal(100)
        expect(withdraw_queue.user).to.equal(owner.address)

        await vault.expireVault()


        expect(parseInt(await weth.balanceOf(vault.address))).to.greaterThan(0)
        expect(await weth.balanceOf(new_vault.address)).to.equal(0)
        expect(await vm.VAULT_ASSETS(vault.address)).to.equal(0)
        expect(await vm.VAULT_ASSETS(new_vault.address)).to.equal(0)

        //see current assets
        await vm.rolloverToNewVault(vault.address)

        expect(await weth.balanceOf(vault.address)).to.equal(0)
        expect(parseInt(await weth.balanceOf(new_vault.address))).to.greaterThan(0)

        expect(await vm.VAULT_ASSETS(vault.address)).to.equal(0)
        expect(parseInt(await vm.VAULT_ASSETS(new_vault.address))).to.greaterThan(0) 


        expect(await vault.isRollable()).to.equal(false)
        await expect(vm.performOldRollover(new_vault.address, vault.address)).to.be.revertedWith("Previous loans must be settled")

        let all_loans = await vault.getAllLoans()
        let curr_loan = all_loans[all_loans.length-1]

        await vault.repayLoan(curr_loan)

        expect(parseInt(await vault.balanceOf(owner.address, 0))).to.greaterThan(0)
        expect(await new_vault.balanceOf(owner.address, 0)).to.equal(0)

        await vm.performOldRollover(new_vault.address, vault.address)
        expect(await vm.ROLLOVER_DONE(new_vault.address)).to.equal(true)

        expect(await vault.balanceOf(owner.address, 0)).to.equal(0)
        expect(parseInt(await new_vault.balanceOf(owner.address, 0))).to.greaterThan(0)

    })





})