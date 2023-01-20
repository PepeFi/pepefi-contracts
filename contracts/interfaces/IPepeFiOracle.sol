pragma solidity ^0.8.9;

interface IPepeFiOracle {
  function getPrice ( address _collection, uint256 _id ) external view returns ( uint256 );
  function prices ( address ) external view returns ( uint256 );
  function updatePrice ( address _collection, uint256 _value ) external;
}
