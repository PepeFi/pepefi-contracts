pragma solidity ^0.8.9;

interface IPepeAuction {
  function balanceOf ( address account, uint256 id ) external view returns ( uint256 );
  function buy (  ) external;
  function createAuction ( uint256 _loanId, address _nft, uint256 _nftId, uint256 _startingPrice, uint256 _duration, uint256 _discountRate,   address _owner, address _liquidator, uint32 liquidatorFee ) external;
  function isApprovedForAll ( address account, address operator ) external view returns ( bool );
  function setApprovalForAll ( address operator, bool approved ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
}
