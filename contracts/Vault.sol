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

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function initialize(VaultLib.VaultDetails memory _VAULT_DETAILS, address[] memory _WHITELISTED_COLLECTIONS, VaultLib.SUPPORTED_COLLECTIONS[] memory _supported_collections) external{
        // changed: assertion to require statement and added error message
        // todo: create custom errors to save gas, and move to those
        require(VAULT_DETAILS.CONTRACTS.PEPEFI_ADMIN == address(0), "ALREADY_INITIALIZED"); //call only once

        VAULT_DETAILS = _VAULT_DETAILS;
        ASSET = IERC20(_VAULT_DETAILS.CONTRACTS.ASSET);
        WHITELISTED_COLLECTIONS = _WHITELISTED_COLLECTIONS;
        
        // changed: made loop more gas efficient
        uint length = _supported_collections.length;
        for (uint i; i< length; ) {
            WHITELISTED_DETAILS[_supported_collections[i].COLLECTION] = _supported_collections[i];

            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 private ASSET; //The underlying ERC20 asset

    uint256[] private ALL_LOANS; //List of active loans on previous vault

    uint256[] private PREVIOUS_WITHDRAW; //Rolled over loans from previous vault that should be withdrawed
    uint256[] private NEXT_WITHDRAW; //Withdraw queue that will be withdrawn

    uint256 private PENDING_WITHDRAW; //Amount of asset that came from previous vault that is pending to be withdrawn

    mapping(uint256 => VaultLib.loanDetails) public _loans; //list of loans done
   
    uint32 private constant LIQUIDITY = 0;
    /// changed: no initialization of _nextId — previous implementation skipped 1
    uint256 private _nextId; /// The ID of the next token that will be minted. Skips 0

    VaultLib.VaultDetails private VAULT_DETAILS;

    bool private onlyOnce = true;

    address[] public WHITELISTED_COLLECTIONS;
    mapping(address => VaultLib.SUPPORTED_COLLECTIONS) public WHITELISTED_DETAILS;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                              ROLLOVER LOGIC
    //////////////////////////////////////////////////////////////*/

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

    //Removing and adding liquidity
    /// changed: made function external — if used internally, create a duplicate internal function _getWETHBalance for gas
    ///          and put it in the body of this function
    function getWETHBalance() external view returns (uint256) {
        uint256 loanBalance = 0;

        //this loop thru active loans and liquidated assets. 2 birds 1 stone.
        // changed: removed i definition & made i incrementation unchecked to save gas
        for (uint i; i < ALL_LOANS.length; ) {
            VaultLib.loanDetails memory details = _loans[ALL_LOANS[i]];
            
            uint256 oraclePrice = IPepeFiOracle(VAULT_DETAILS.CONTRACTS.ORACLE_CONTRACT).getPrice(details.collateral, details.assetId);

            if (oraclePrice * 900/1000 < details.repaymentAmount){
                loanBalance = loanBalance + (oraclePrice * 900/1000);
            } else {
                loanBalance = loanBalance + details.loanPrincipalAmount;
            }

            unchecked { ++i; }
        }

        return IERC20(ASSET).balanceOf(address(this)) + loanBalance;
    }

    /// changed: made function external — if used internally, create a duplicate internal function _isRollable for gas
    ///          and put it in the body of this function
    function isRollable() external view returns (bool) {
        
        // changed: made loop more gas effecient

        uint[] memory _allLoans = ALL_LOANS;

        uint length = _allLoans.length;

        for (uint i; i < length; ) {
            if (_loans[ALL_LOANS[i]].timestamp != 0) {
                return false;
            }

            unchecked { ++i; }
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                               LOANS
    //////////////////////////////////////////////////////////////*/

    function takeERC721Loan(
        address nftCollateralContract, 
        uint256 nftCollateralId, 
        uint256 _loanAmount, 
        uint32 _duration
    ) external nonReentrant checkExpired returns (uint256){
        VaultLib.SUPPORTED_COLLECTIONS memory risk_params = WHITELISTED_DETAILS[nftCollateralContract];

        uint max_ltv = risk_params.MAX_LTV - (_duration / 100) * risk_params.slope;

        // changed: expirty => expiry, keyboard typo
        return _createLoan(VaultLib.loanCreation({
            nftCollateralContract: nftCollateralContract, 
            nftCollateralId: nftCollateralId, 
            loanPrincipal: Math.min(Math.min(_loanAmount, max_ltv * IPepeFiOracle(VAULT_DETAILS.CONTRACTS.ORACLE_CONTRACT).getPrice(nftCollateralContract, nftCollateralId)), risk_params.MAX_LOAN), 
            apr: risk_params.APR, 
            loanExpiry: block.timestamp + (_duration * 86400)
        })); 

    }

    // changed: defined return variable
    function _createLoan(VaultLib.loanCreation memory new_loan) internal returns (uint256 loanId){
        // changed: set assertions as require statements, and added error messages
        // changed: expirty => expiry, keyboard typo
        // todo: create custom errors to save gas, and move to those
        require(new_loan.loanExpiry < VAULT_DETAILS.CREATION_TIME + (VAULT_DETAILS.EXPIRY_IN * 2), "EXPIRY_TOO_HIGH"); //loan must settle in the next vault
        require(new_loan.loanExpiry >= block.timestamp, "ALREADY_EXPIRED");
        require(ASSET.balanceOf(address(this)) >= new_loan.loanPrincipal, "TREASURY_TOO_LOW");

        bool success = ASSET.transfer(msg.sender, new_loan.loanPrincipal);

        require(success, "UNSUCCESSFUL_TRANSFER");

        IERC721(new_loan.nftCollateralContract).transferFrom(msg.sender, address(this), new_loan.nftCollateralId); //Transfer the NFT to our wallet. 
        
        // changed: increment _nextId and save to memory, previous implementation repeatedly read from storage ($$$)
        loanId = ++_nextId;

        _loans[loanId] = VaultLib.loanDetails({
            timestamp: block.timestamp,
            collateral: new_loan.nftCollateralContract,
            assetId: new_loan.nftCollateralId,
            expiry: new_loan.loanExpiry,
            loanPrincipalAmount: new_loan.loanPrincipal, 
            repaymentAmount: (((new_loan.loanExpiry-block.timestamp) * new_loan.apr * new_loan.loanPrincipal))/31536000000 + new_loan.loanPrincipal
        });

        ALL_LOANS.push(loanId);

        _mint(msg.sender, loanId , 1, "");
    }

    function repayLoan(uint32 _loanId) external {
        VaultLib.loanDetails storage curr_loan = _loans[_loanId];

        // changed: set assertion as require statement, and added error message
        // todo: create custom errors to save gas, and move to those
        require(curr_loan.expiry >= block.timestamp, "LOAN_EXPIRED");
        
        address transferTo = address(this);

        if (block.timestamp > VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN){
            transferTo = IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).NEXT_VAULT(address(this));
            IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).increaseAsset(curr_loan.repaymentAmount); 
        }
        
        bool success = ASSET.transferFrom(msg.sender, transferTo, curr_loan.repaymentAmount);  

        // changed: completed error message
        require(success, "UNSUCCESSFUL_TRANSFER");

        IERC721(curr_loan.collateral).transferFrom(address(this), msg.sender, curr_loan.assetId); //Transfer the NFT from our wallet to user

        delete _loans[_loanId];

        _burn(msg.sender, _loanId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                                MISC
    //////////////////////////////////////////////////////////////*/

    /// changed: made function pure and removed param variable to remove error message
    function uri(uint256) public pure override returns (string memory){
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

    /// todo: test gas vs Solady library for searching through array 
    ///       https://github.com/Vectorized/solady/blob/main/src/utils/LibSort.sol#L290
    function updateWhitelistDetails(address _collection,  VaultLib.SUPPORTED_COLLECTIONS memory _detail) public onlyVaultManager {
        //make sure LTV is not increase 5% from initial while keeping global requirements or sth like that?
        
        // changed: added error message
        require(IVaultManager(VAULT_DETAILS.CONTRACTS.VAULT_MANAGER).validCollectionCheck(_detail) == true, "INVALID_DETAIL");

        // changed: saved whitelisted collections to memory (much cheaper) and made the loop more gas efficient
        address[] memory _whitelistedCollections = WHITELISTED_COLLECTIONS;

        // changed: storing array length in variables saves gas in loops
        uint length = _whitelistedCollections.length;

        //loop thru WHITELISTED_COLLECTIONS
        for (uint i; i < length; ) {
            if (_whitelistedCollections[i] == _collection) {
                WHITELISTED_DETAILS[_collection] = _detail;
                return;
            }

            unchecked { ++i; }
        }

        // changed: added error message
        revert("NOT_WHITELISTED");
    }

    /// temp: a function for testing only
    function expireVault() external {
        require(msg.sender == VAULT_DETAILS.VAULT_CREATOR);
        VAULT_DETAILS.EXPIRY_IN = 0;
    }
}