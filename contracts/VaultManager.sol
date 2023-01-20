pragma solidity ^0.8.9;

import "./interfaces/IVault.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {
    Contracts,
    Withdrawl,
    CreationParams,
    SUPPORTED_COLLECTIONS
} from './VaultLib.sol';

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVault.sol";


contract VaultManager is ReentrancyGuard{
    Contracts public CONTRACTS;

    address[] public WHITELISTED_COLLECTIONS;
    mapping(address => SUPPORTED_COLLECTIONS) private WHITELISTED_DETAILS;

    address[] public vaults;

    mapping(address => uint256) public VAULT_ASSETS;
    mapping(address => uint256) public VAULT_SUPPLY;
    mapping(address => address) public NEXT_VAULT;
    mapping(address => bool) public ROLLOVER_DONE;
    mapping(address => Withdrawl[]) public WITHDRAW_QUEUE; //Withdraw queue
    mapping(address => address[]) public LIQUIDITY_OWNERS; //The addresses that hold liquidity positions in a vault

    address ADMIN;

    modifier onlyAdmin() {
        require(msg.sender == ADMIN, "Only Admin");
        _;
    }

    uint32 private constant LIQUIDITY = 0;

    constructor(Contracts memory _CONTRACTS){
       _CONTRACTS.VAULT_MANAGER = address(this);
       CONTRACTS = _CONTRACTS;
       ADMIN = msg.sender;
    }

    //set some global params here
    function updatePlatformParams(address[] memory _WHITELISTED_COLLECTIONS, SUPPORTED_COLLECTIONS[] memory _supported_collections) public onlyAdmin{
        require(_WHITELISTED_COLLECTIONS.length == _supported_collections.length, "Lengths must be equal");

        
        for (uint i=0; i<_WHITELISTED_COLLECTIONS.length; i++) {
            WHITELISTED_DETAILS[_WHITELISTED_COLLECTIONS[i]] = _supported_collections[i];
        }

        WHITELISTED_COLLECTIONS = _WHITELISTED_COLLECTIONS;

    }

    function validCollectionCheck(SUPPORTED_COLLECTIONS memory current_value) public view returns (bool) {
        SUPPORTED_COLLECTIONS memory platform_value = WHITELISTED_DETAILS[current_value.COLLECTION];

        if (platform_value.MAX_LTV == 0){
            console.log("LTV FAIL 1");
            return false; //meaning it doesn't exists on the global whitelist
        } else if (current_value.MAX_LTV > platform_value.MAX_LTV) {
            console.log("LTV FAIL 2");

            return false;
        } else if (current_value.APR < platform_value.APR) {
            console.log("APR FAIL");

            return false;
        } else if (current_value.MAX_LOAN > platform_value.MAX_LOAN) {
            console.log("max_loan FAIL");

            return false;
        } else if (current_value.MAX_DURATION > platform_value.MAX_DURATION) {

            console.log("MAX_duration FAIL");

            return false;
        }
        //add a check for MAX_DURATION and VAULT_EXPIRY


        if (platform_value.ALLOWED_TRAITS.length == 0 && current_value.ALLOWED_TRAITS.length == 0){
            return true;
        }

        bool found = false;

        //loop thru current_value.ALLOWED_TRAITS and TRAIT_MULTIPLIER and refrence it with platform_value to check validitiy
        for (uint i=0; i<current_value.ALLOWED_TRAITS.length; i++) {
            //loop thru to find current_value.ALLOWED_TRAITS[i] in platform_value.ALLOWED_TRAITS
            for (uint j=0; j<platform_value.ALLOWED_TRAITS.length; j++) {
                if (keccak256(bytes(current_value.ALLOWED_TRAITS[i])) == keccak256(bytes(platform_value.ALLOWED_TRAITS[j]))) {
                    found = true;
                    if (current_value.TRAIT_MULTIPLIER[i] > platform_value.TRAIT_MULTIPLIER[j]) {
                        return false;
                    }
                }
            }

        }


        return found;
    }

    //Vault Creation
    function createVault(CreationParams memory _params, address[] memory _WHITELISTED_COLLECTIONS, SUPPORTED_COLLECTIONS[] memory _supported_collections) public returns (address vault) {
        // VaultLib.VaultDetails memory _details
        vault = Clones.clone(CONTRACTS.BASE_VAULT);

        require(_WHITELISTED_COLLECTIONS.length == _supported_collections.length, "Lengths must be equal");

        // Do Risk check

        for (uint i=0; i<_WHITELISTED_COLLECTIONS.length; i++) {
            require(_supported_collections[i].COLLECTION == _WHITELISTED_COLLECTIONS[i]);
            require(validCollectionCheck(_supported_collections[i]) == true);
        }

        IVault(vault).initialize(VaultDetails({
            VAULT_NAME: _params.VAULT_NAME,
            VAULT_DESCRIPTION: _params.VAULT_DESCRIPTION,
            CONTRACTS: CONTRACTS,
            VAULT_CREATOR: msg.sender,
            PREVIOUS_VAULT: _params.PREVIOUS_VAULT,
            EXTERNAL_LP_ENABLED: _params.EXTERNAL_LP_ENABLED,
            WHITELISTED_NFT_LPS: _params.WHITELISTED_NFT_LPS,
            CREATION_TIME: block.timestamp,
            EXPIRY_IN: _params.EXPIRY_IN
        }), _WHITELISTED_COLLECTIONS, _supported_collections);

        vaults.push(address(vault));

        
    }
    
    //Updating Vaults
    //Function to call to set new rollover vault in present vault
    function setRolloverVault(address _CURRENT_VAULT, address _NEXT_VAULT) external {
        require(isValidVault(_CURRENT_VAULT) == true, "Vault is not valid");
        require(isValidVault(_NEXT_VAULT) == true, "Vault is not valid");

        VaultDetails memory OldDetails = IVault(_CURRENT_VAULT).getVaultDetails();
        require(msg.sender == OldDetails.VAULT_CREATOR, "Only creater can set rollover vault");
        require(block.timestamp + 14 days < OldDetails.CREATION_TIME + OldDetails.EXPIRY_IN, "Must be set at least 14 days before expiry");


        //Should we check more like LTV increase etc here?

        NEXT_VAULT[_CURRENT_VAULT] = _NEXT_VAULT;
    }

    //A call to make after expiry to rollover to new vault
    function rolloverToNewVault(address _CURRENT_VAULT) external {
        //Also go thru the withdraw queue here

        if (NEXT_VAULT[_CURRENT_VAULT] == address(0)) {revert();}


        //Current Vault Must be expired
        VaultDetails memory VAULT_DETAILS = IVault(_CURRENT_VAULT).getVaultDetails();
        require(block.timestamp > VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN);


        //Send WETH to new vault and set it
        uint256 sendingAmt = IERC20(CONTRACTS.ASSET).balanceOf(_CURRENT_VAULT);

        if (sendingAmt > 0){
            bool success = IVault(_CURRENT_VAULT).performTransfer( NEXT_VAULT[_CURRENT_VAULT], sendingAmt);
            require(success == true);
        }


        VAULT_ASSETS[NEXT_VAULT[_CURRENT_VAULT]] = VAULT_ASSETS[NEXT_VAULT[_CURRENT_VAULT]] + sendingAmt; //Track amount sent from previous vault
    }

    function increaseAsset(uint256 _amount) external{
        require(NEXT_VAULT[msg.sender] != address(0));
        VAULT_ASSETS[msg.sender] = VAULT_ASSETS[NEXT_VAULT[msg.sender]] + _amount;
    }

    //perform the rollover in current vault after all active loans are settled. This means performing withdrawl, minting new token and such
    function performOldRollover(address _CURRENT_VAULT, address _PREVIOUS_VAULT) external{
        //Ensure rollover is not done and all loans are settled
        require(ROLLOVER_DONE[_CURRENT_VAULT] == false);
        require(IVault(_PREVIOUS_VAULT).isRollable(), "Previous loans must be settled");

        //burn old asset and mint new assets
        uint256 totalToken = VAULT_SUPPLY[_PREVIOUS_VAULT];
        uint256 totalWETH = VAULT_ASSETS[_CURRENT_VAULT];


        for (uint i=0; i<WITHDRAW_QUEUE[ _PREVIOUS_VAULT].length; i++){
            //some calculation optimization possible
            uint256 amt =  (WITHDRAW_QUEUE[ _PREVIOUS_VAULT][i].shares  * totalWETH) / totalToken;

            if (amt > 0){
                bool success = IVault(_CURRENT_VAULT).performTransfer(WITHDRAW_QUEUE[ _PREVIOUS_VAULT][i].user, amt);
                require(success == true);
            }

        }

        delete WITHDRAW_QUEUE[ _PREVIOUS_VAULT];

        address[] memory liq_owners = LIQUIDITY_OWNERS[_PREVIOUS_VAULT];

        //loop thru owners and burn old asset and mint new asset
        for (uint i=0; i<liq_owners.length; i++){
            uint256 old_asset = IVault(_PREVIOUS_VAULT).balanceOf(liq_owners[i], LIQUIDITY);
            //some calculation optimization possible
            IVault(_PREVIOUS_VAULT).burn_old(liq_owners[i], LIQUIDITY, old_asset);
            IVault(_CURRENT_VAULT).mint_new(liq_owners[i], LIQUIDITY, (old_asset * totalWETH) / totalToken);
        }

        ROLLOVER_DONE[_CURRENT_VAULT] = true;
    }


    function isValidVault(address _VAULT_ADDRESS) public view returns (bool) {

        for (uint i; i < vaults.length; i++) {
            if (vaults[i] == _VAULT_ADDRESS)
                return true;
        }

        return false;
    }

    function addLiquidity(uint256 _amount, address _vault)  external {
        VaultDetails memory VAULT_DETAILS = IVault(_vault).getVaultDetails();

        require(block.timestamp < VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN);

        if (VAULT_DETAILS.EXTERNAL_LP_ENABLED == false){
            if (msg.sender != VAULT_DETAILS.CONTRACTS.VAULT_MANAGER) {revert();}
        }

        uint256 shares = _amount;


        if (VAULT_SUPPLY[_vault] > 0) {
            shares =  _amount * (VAULT_SUPPLY[_vault]  / IVault(_vault).getWETHBalance());
        }

        //change to openbook one
        bool success = IVault(_vault).performTransferFrom(msg.sender, _vault, _amount);
        
        if (success == false) {revert();}

        IVault(_vault).mint_new(msg.sender, LIQUIDITY, shares); //0 is liquidity token

        VAULT_SUPPLY[_vault] = VAULT_SUPPLY[_vault] + shares;

        //check if msg.sender is in LIQUIDITY_OWNERS
        for (uint i=0; i< LIQUIDITY_OWNERS[_vault].length; i++) {
            if (LIQUIDITY_OWNERS[_vault][i] == msg.sender){
                return;
            }
        }

        LIQUIDITY_OWNERS[_vault].push(msg.sender);
    }

    function withdrawLiquidity(uint256 shares, address _vault) external nonReentrant {  
        //add to queue

        uint256 balance = IVault(_vault).balanceOf(msg.sender, LIQUIDITY);

        if (balance <= shares) {revert();}

        WITHDRAW_QUEUE[_vault].push(Withdrawl({
            user: msg.sender,
            shares: shares
        }));

        IVault(_vault).burn_old(msg.sender, LIQUIDITY, shares);
    }


    function getVaults() public view returns (address[] memory) {
        return vaults;
    }

    function getWhitelistedDetails(address _vault) public view returns (SUPPORTED_COLLECTIONS memory) {
        return WHITELISTED_DETAILS[_vault];
    }
}