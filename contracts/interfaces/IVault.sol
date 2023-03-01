pragma solidity ^0.8.9;

import {
    VaultDetails,
    LoanDetails,
    LoanCreation,
    SUPPORTED_COLLECTIONS
} from '../VaultLib.sol';

interface IVault {

    function initialize(
        VaultDetails memory _VAULT_DETAILS, 
        address[] memory _WHITELISTED_COLLECTIONS, 
        SUPPORTED_COLLECTIONS[] memory _supported_collections
    ) external;

    function finishedAuction(uint256 _loanId) external;

    function burn_old(address account, uint256 id, uint256 amount) external;

    function getVaultDetails() external view returns (VaultDetails memory);

    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    function performTransfer(address to, uint256 sendingAmt) external returns (bool);  

    function performTransferFrom(address from, address to, uint256 sendingAmt) external returns (bool);    

    function mint_new(address account, uint256 id, uint256 amount) external;

    function increaseAsset(uint256 _amount) external;

    function getWETHBalance() external view returns (uint256);

    function isRollable() external view returns (bool);

    function getWhitelistedDetails(address) external view returns (SUPPORTED_COLLECTIONS memory);

    function _createLoan(LoanCreation memory new_loan) external returns (uint256);

    //write interface for _loans of type VaultLib.loanDetails
    function _loans(uint256) external view returns (LoanDetails memory);

    function _repayLoan(
        uint32 _loanId,
        address transferTo, 
        LoanDetails memory curr_loan
    ) external;

}