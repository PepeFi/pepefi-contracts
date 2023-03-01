pragma solidity ^0.8.9;

import {
    Withdrawl,
    SUPPORTED_COLLECTIONS
} from '../VaultLib.sol';

interface IVaultManager {
    function isValidVault(address _VAULT_ADDRESS) external view returns (bool);
    function NEXT_VAULT(address _CURRENT_VAULT) external view returns (address);
    function VAULT_ASSETS(address _VAULT) external view returns (uint256);
    function VAULT_SUPPLY(address _VAULT) external view returns (uint256);
    function addtoQueue(Withdrawl memory withdrawl) external;
    function increaseAsset(uint256 _amount) external;
    function WHITELISTED_DETAILS(address) external view returns (SUPPORTED_COLLECTIONS memory);
    function getWhitelistedDetails(address _vault) external view returns (SUPPORTED_COLLECTIONS memory);
    function validCollectionCheck(SUPPORTED_COLLECTIONS memory) external view returns (bool);
}