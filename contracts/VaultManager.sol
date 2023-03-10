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
        // changed: saved length to memoty to save gas on repeated .length calls
        uint length = _WHITELISTED_COLLECTIONS.length;

        require(length == _supported_collections.length, "UNMATCHING_COLLECTIONS");

        // changed: made loop more efficient w/ unchecked ++i iteration & static length
        for (uint i; i < length; ) {
            WHITELISTED_DETAILS[_WHITELISTED_COLLECTIONS[i]] = _supported_collections[i];

            unchecked { ++i; }
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

        // review: below is your comment. duration of loan vs vault expiry is already handled in loan creation. is this an old comment?
        // add a check for MAX_DURATION and VAULT_EXPIRY

        // changed: saved lengths to save gas for multiple calls 
        uint current_length = current_value.ALLOWED_TRAITS.length;

        uint platform_length = platform_value.ALLOWED_TRAITS.length;

        if (platform_length == 0 && current_length == 0){
            return true;
        }

        // changed: previous implementations would give a false positive,
        //          if only 1 out of n traits matched while the rest didn't match it would've returned true

        //bool found = false;

        // loop thru current_value.ALLOWED_TRAITS and TRAIT_MULTIPLIER and refrence it with platform_value to check validitiy
        // for (uint i; i < current_length; ) {
        //     //loop thru to find current_value.ALLOWED_TRAITS[i] in platform_value.ALLOWED_TRAITS
        //     for (uint j; j < platform_length; ) {
        //         if (keccak256(bytes(current_value.ALLOWED_TRAITS[i])) == keccak256(bytes(platform_value.ALLOWED_TRAITS[j]))) {
        //             found = true;
        //             if (current_value.TRAIT_MULTIPLIER[i] > platform_value.TRAIT_MULTIPLIER[j]) {
        //                 return false;
        //             }
        //         }

        //         unchecked { ++j; }
        //     }

        //     unchecked { ++i; }

        // }

        // changed: rewrite of above that returns false if matching trait isn't found for any allowed trait in current_value
        for (uint i; i < current_length; ) {
            for (uint j; j < platform_length; ) {
                if (keccak256(bytes(current_value.ALLOWED_TRAITS[i])) == keccak256(bytes(platform_value.ALLOWED_TRAITS[j]))) {
                    if (current_value.TRAIT_MULTIPLIER[i] > platform_value.TRAIT_MULTIPLIER[j]) {
                        return false;
                    }

                    break;
                }

                // if matching trait unfound, return false
                unchecked { if (++j == platform_length) return false; }
            }

            unchecked { ++i; }
        }


        return true;
    }

    //Vault Creation
    function createVault(CreationParams memory _params, address[] memory _WHITELISTED_COLLECTIONS, SUPPORTED_COLLECTIONS[] memory _supported_collections) public returns (address vault) {
        // VaultLib.VaultDetails memory _details
        vault = Clones.clone(CONTRACTS.BASE_VAULT);
        
        // changed: saved length to save gas for multiple calls
        uint length = _WHITELISTED_COLLECTIONS.length;

        require(length == _supported_collections.length, "UNMATCHING_COLLECTIONS");

        // Do Risk check

        for (uint i; i < length; ) {
            require(_supported_collections[i].COLLECTION == _WHITELISTED_COLLECTIONS[i]);
            require(validCollectionCheck(_supported_collections[i]), "INVALID_COLLECTION");

            unchecked { ++i; }
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
        // changed: error messages

        require(isValidVault(_CURRENT_VAULT) == true, "INVALID_VAULT");
        require(isValidVault(_NEXT_VAULT) == true, "INVALID_VAULT");

        VaultDetails memory OldDetails = IVault(_CURRENT_VAULT).getVaultDetails();
        require(msg.sender == OldDetails.VAULT_CREATOR, "NOT_VAULT_CREATOR");
        require(block.timestamp + 14 days < OldDetails.CREATION_TIME + OldDetails.EXPIRY_IN, "EXPIRY_BUFFER_NOT_PASSED");


        //Should we check more like LTV increase etc here?

        NEXT_VAULT[_CURRENT_VAULT] = _NEXT_VAULT;
    }

    //A call to make after expiry to rollover to new vault
    function rolloverToNewVault(address _CURRENT_VAULT) external {
        // changed: require statements & error messages

        //Also go thru the withdraw queue here

        require(NEXT_VAULT[_CURRENT_VAULT] != address(0), "INVALID_ACTION");


        //Current Vault Must be expired
        VaultDetails memory VAULT_DETAILS = IVault(_CURRENT_VAULT).getVaultDetails();
        require(block.timestamp > VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN);


        //Send WETH to new vault and set it
        uint256 sendingAmt = IERC20(CONTRACTS.ASSET).balanceOf(_CURRENT_VAULT);

        if (sendingAmt > 0){
            bool success = IVault(_CURRENT_VAULT).performTransfer( NEXT_VAULT[_CURRENT_VAULT], sendingAmt);
            require(success, "TRANSFER_FAILED");
        }


        VAULT_ASSETS[NEXT_VAULT[_CURRENT_VAULT]] = VAULT_ASSETS[NEXT_VAULT[_CURRENT_VAULT]] + sendingAmt; //Track amount sent from previous vault
    }

    function increaseAsset(uint256 _amount) external {
        // changed: error message
        require(NEXT_VAULT[msg.sender] != address(0), "INVALID_SENDER");
        VAULT_ASSETS[msg.sender] = VAULT_ASSETS[NEXT_VAULT[msg.sender]] + _amount;
    }

    //perform the rollover in current vault after all active loans are settled. This means performing withdrawl, minting new token and such
    function performOldRollover(address _CURRENT_VAULT, address _PREVIOUS_VAULT) external{
        // changed: error messages

        //Ensure rollover is not done and all loans are settled
        require(ROLLOVER_DONE[_CURRENT_VAULT] == false, "ROLLOVER_COMPLETE");
        require(IVault(_PREVIOUS_VAULT).isRollable(), "LOANS_ACTIVE");

        // changed: moved this from bottom to here, it's good practice to make the previous checks revert so function
        //          can't be re-entered. see: https://dev.to/zaryab2000/the-significance-of-check-effects-interaction-pattern-5hn6
        ROLLOVER_DONE[_CURRENT_VAULT] = true;

        //burn old asset and mint new assets
        uint256 totalToken = VAULT_SUPPLY[_PREVIOUS_VAULT];
        uint256 totalWETH = VAULT_ASSETS[_CURRENT_VAULT];

        // changed: made loop more gas efficient
        uint length = WITHDRAW_QUEUE[ _PREVIOUS_VAULT].length;

        for (uint i; i < length; ){
            //some calculation optimization possible
            uint256 amt =  (WITHDRAW_QUEUE[ _PREVIOUS_VAULT][i].shares  * totalWETH) / totalToken;

            if (amt > 0){
                bool success = IVault(_CURRENT_VAULT).performTransfer(WITHDRAW_QUEUE[ _PREVIOUS_VAULT][i].user, amt);
                require(success, "TRANSFER_FAILED");
            }

            unchecked { ++i; }
        }

        delete WITHDRAW_QUEUE[ _PREVIOUS_VAULT];

        address[] memory liq_owners = LIQUIDITY_OWNERS[_PREVIOUS_VAULT];

        // changed: made loop more efficient
        length = liq_owners.length;

        //loop thru owners and burn old asset and mint new asset
        for (uint i; i < length; ){
            uint256 old_asset = IVault(_PREVIOUS_VAULT).balanceOf(liq_owners[i], LIQUIDITY);
            //some calculation optimization possible
            IVault(_PREVIOUS_VAULT).burn_old(liq_owners[i], LIQUIDITY, old_asset);
            IVault(_CURRENT_VAULT).mint_new(liq_owners[i], LIQUIDITY, (old_asset * totalWETH) / totalToken);

            unchecked { ++i; }
        }
        
    }


    function isValidVault(address _VAULT_ADDRESS) public view returns (bool valid) {
        
        // changed: made loop more efficient
        // review: might want to make this a mapping

        uint length = vaults.length;
        for (uint i; i < length; ) {
            if (vaults[i] == _VAULT_ADDRESS) return true;

            unchecked { ++i; }
        }
    }

    function addLiquidity(uint256 _amount, address _vault)  external {
        VaultDetails memory VAULT_DETAILS = IVault(_vault).getVaultDetails();

        require(block.timestamp < VAULT_DETAILS.CREATION_TIME + VAULT_DETAILS.EXPIRY_IN);

        // changed: logic flow
        if (msg.sender != VAULT_DETAILS.CONTRACTS.VAULT_MANAGER) {
            require(VAULT_DETAILS.EXTERNAL_LP_ENABLED, "PRIVATE_VAULT");
        }

        uint256 shares = _amount;

        if (VAULT_SUPPLY[_vault] > 0) {
            shares =  _amount * (VAULT_SUPPLY[_vault]  / IVault(_vault).getWETHBalance());
        }

        //change to openbook one
        bool success = IVault(_vault).performTransferFrom(msg.sender, _vault, _amount);
        
        require(success, "TRANSFER_FAILED");

        IVault(_vault).mint_new(msg.sender, LIQUIDITY, shares); //0 is liquidity token

        VAULT_SUPPLY[_vault] = VAULT_SUPPLY[_vault] + shares;

        // changed: made loop more efficient
        // review: might want to make this a mapping
        uint length = LIQUIDITY_OWNERS[_vault].length;
        //check if msg.sender is in LIQUIDITY_OWNERS
        for (uint i; i < length; ) {
            if (LIQUIDITY_OWNERS[_vault][i] == msg.sender) return;

            unchecked { ++i; }
        }

        LIQUIDITY_OWNERS[_vault].push(msg.sender);
    }

    function withdrawLiquidity(uint256 shares, address _vault) external nonReentrant {  
        //add to queue

        uint256 balance = IVault(_vault).balanceOf(msg.sender, LIQUIDITY);

        // changed: require statement
        require(balance >= shares, "INSUFFICIENT_FUNDS");

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