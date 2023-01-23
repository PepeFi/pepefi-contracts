pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "solmate/src/tokens/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IPepeFiOracle.sol";
import "./interfaces/IVaultManager.sol";

contract Vault is ERC1155, ReentrancyGuard {
    IERC20 private ASSET; //The underlying ERC20 asset


    uint256[] private ALL_LOANS; //List of active loans on previous vault


    uint256[] private PREVIOUS_WITHDRAW; //Rolled over loans from previous vault that should be withdrawed
    uint256[] private NEXT_WITHDRAW; //Withdraw queue that will be withdrawn



    uint256 private PENDING_WITHDRAW; //Amount of asset that came from previous vault that is pending to be withdrawn


    mapping(uint256 => VaultLib.loanDetails) public _loans; //list of loans done
   
    
    uint32 private constant LIQUIDITY = 0;
    uint256 private _nextId = 1; /// The ID of the next token that will be minted. Skips 0


    VaultLib.VaultDetails private VAULT_DETAILS;

    bool private onlyOnce = true;

    address[] public WHITELISTED_COLLECTIONS;
    mapping(address => VaultLib.SUPPORTED_COLLECTIONS) public WHITELISTED_DETAILS;

    
    //Modifiers
    modifier checkExpired {
        require(block.timestamp < VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN);
        _;
    }

    modifier onlyAuction {
        require (msg.sender == VAULT_DETAILS.CONTRACTS.AUCTION_CONTRACT);
        _;
    }

    modifier onlyVaultManager {
        require(msg.sender == VAULT_DETAILS.CONTRACTS.VAULT_MANAGER);
        _;
    }

    //Rollover Management
    function performTransferFrom(address from, address to, uint256 sendingAmt) external onlyVaultManager returns (bool) {
        return ASSET.transferFrom(from, to, sendingAmt); //send WETH
    }

    function performTransfer(address receiver, uint256 sendingAmt) external onlyVaultManager returns (bool) {
        return ASSET.transfer(receiver, sendingAmt); //send WETH
    }


    function burn_old(address account, uint256 id, uint256 amount) external onlyVaultManager {
        _burn(account, id, amount);
    }

    function mint_new(address account, uint256 id, uint256 amount) external onlyVaultManager {
        _mint(account, id, amount, "");
    }

    function initialize(VaultLib.VaultDetails memory _VAULT_DETAILS, address[] memory _WHITELISTED_COLLECTIONS, VaultLib.SUPPORTED_COLLECTIONS[] memory _supported_collections) external{
        if (VAULT_DETAILS.CONTRACTS.PEPEFI_ADMIN != address(0)) {revert();} //call only once
        VAULT_DETAILS = _VAULT_DETAILS;
        ASSET = IERC20(_VAULT_DETAILS.CONTRACTS.ASSET);
        WHITELISTED_COLLECTIONS = _WHITELISTED_COLLECTIONS;

        for (uint i=0; i<=_supported_collections.length-1; i++) {
            WHITELISTED_DETAILS[_supported_collections[i].COLLECTION] = _supported_collections[i];
        }
    }

    
    function _createLoan(VaultLib.loanCreation memory new_loan) private returns (uint256){
        require(new_loan.loanExpirty < VAULT_DETAILS.CREATION_TIME + (VAULT_DETAILS.EXPIRY_IN * 2)); //loan must settle in the next vault
        if(new_loan.loanExpirty < block.timestamp) {revert();}
        if(ASSET.balanceOf(address(this)) < new_loan.loanPrincipal) {revert();}

        bool success = ASSET.transfer(msg.sender, new_loan.loanPrincipal);

        if (success == false) {revert();}

        IERC721(new_loan.nftCollateralContract).transferFrom(msg.sender, address(this), new_loan.nftCollateralId); //Transfer the NFT to our wallet. 

        _loans[_nextId+1] = VaultLib.loanDetails({
                timestamp: block.timestamp,
                collateral: new_loan.nftCollateralContract,
                assetId: new_loan.nftCollateralId,
                expiry: new_loan.loanExpirty,
                loanPrincipalAmount: new_loan.loanPrincipal, 
                repaymentAmount: (((new_loan.loanExpirty-block.timestamp) * new_loan.apr * new_loan.loanPrincipal))/31536000000 + new_loan.loanPrincipal
            });

        ALL_LOANS.push(_nextId+1);

        _mint(msg.sender, _nextId+1, 1, "");
        _nextId++;
        
        return _nextId;
    }

    function takeERC721Loan(address nftCollateralContract, uint256 nftCollateralId, uint256 _loanAmount, uint32 _duration) external nonReentrant checkExpired returns (uint256){
        
        VaultLib.SUPPORTED_COLLECTIONS memory risk_params = WHITELISTED_DETAILS[nftCollateralContract];

        uint max_ltv = risk_params.MAX_LTV - (_duration / 100) * risk_params.slope;

        return _createLoan(VaultLib.loanCreation({
            nftCollateralContract: nftCollateralContract, 
            nftCollateralId: nftCollateralId, 
            loanPrincipal: Math.min(Math.min(_loanAmount, max_ltv * IPepeFiOracle(VAULT_DETAILS.CONTRACTS.ORACLE_CONTRACT).getPrice(nftCollateralContract, nftCollateralId)), risk_params.MAX_LOAN), 
            apr: risk_params.APR, 
            loanExpirty: block.timestamp + (_duration * 86400)
        })); 

    }

    function repayLoan(uint32 _loanId) external {
        VaultLib.loanDetails storage curr_loan = _loans[_loanId];

        if(curr_loan.expiry < block.timestamp) {revert();}
        
        address transferTo = address(this);

        if (block.timestamp > VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN){
            transferTo = IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).NEXT_VAULT(address(this));
            IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).increaseAsset(curr_loan.repaymentAmount); 
        }
        
        
        bool success = ASSET.transferFrom(msg.sender, transferTo, curr_loan.repaymentAmount);        
        require(success, "F");


        IERC721(curr_loan.collateral).transferFrom(address(this), msg.sender,  curr_loan.assetId); //Transfer the NFT from our wallet to user

        delete _loans[_loanId];


        _burn(msg.sender, _loanId, 1);


    }

    function isRollable() public view returns (bool) {

        for (uint i=0; i<ALL_LOANS.length; i++) {
            if (_loans[ALL_LOANS[i]].timestamp != 0) {
                return false;
            }
        }

        return true;
    }

    //Removing and adding liquidity
    function getWETHBalance() public view returns (uint256) {
        uint256 loanBalance = 0;

        //this loop thru active loans and liquidated assets. 2 birds 1 stone.
        for (uint i=0; i<ALL_LOANS.length; i++) {
            VaultLib.loanDetails memory details = _loans[ALL_LOANS[i]];
            if (details.timestamp != 0){ //for repaid loans
                 uint256 oraclePrice = IPepeFiOracle(VAULT_DETAILS.CONTRACTS.ORACLE_CONTRACT).getPrice(details.collateral, details.assetId);

                if (oraclePrice * 900/1000 < details.repaymentAmount){
                    loanBalance = loanBalance + (oraclePrice * 900/1000);
                } else {
                    loanBalance = loanBalance + details.loanPrincipalAmount;
                }
            }
           
        }

        return IERC20(ASSET).balanceOf(address(this)) + loanBalance;
    }

    

    //etc
    function uri(uint256 id) public view override returns (string memory){
        return "";
    }

    function finishedAuction(uint256 _loanId) external onlyAuction {
        delete _loans[_loanId];
        _burn(msg.sender, _loanId, 1);
    }

    function getVaultDetails() external view returns (VaultLib.VaultDetails memory){
        return VAULT_DETAILS;
    }

    function getAllLoans() external view returns(uint256[] memory){
        return ALL_LOANS;
    }

    function updateWhitelistDetails(address _collection,  VaultLib.SUPPORTED_COLLECTIONS memory _detail) public onlyVaultManager {
        //make sure LTV is not increase 5% from initial while keeping global requirements or sth like that?
        
        require(IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).validCollectionCheck(_detail) == true);

        //loop thrue WHITELISTED_COLLECTIONS
        for (uint i=0; i<WHITELISTED_COLLECTIONS.length; i++) {
            if (WHITELISTED_COLLECTIONS[i] == _collection) {
                WHITELISTED_DETAILS[_collection] = _detail;
                return;
            }
        }

        revert();

        
    }


    //a function for testing only
    function expireVault() external {
        require(msg.sender == VAULT_DETAILS.VAULT_CREATOR);
        VAULT_DETAILS.EXPIRY_IN = 0;
    }
}