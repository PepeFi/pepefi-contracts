pragma solidity ^0.8.9;
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/ICustomWrapper.sol";

import "hardhat/console.sol";

import {VaultLib} from './VaultLib.sol';


contract Oracle {
    event OracleUpdate(address collection, uint256 value, uint256 timestamp);

    mapping (address => uint256) public prices;


    address public admin;
    address public vaultManager;


    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function setVaultManager(address _vaultManager) public onlyAdmin {
        vaultManager = _vaultManager;
    }

    function updatePrices(address[] calldata _addresses, uint256[] calldata _values) public onlyAdmin{

        require(_addresses.length == _values.length, "The length of two arrays must be same");

        for (uint i=0; i<_addresses.length; i++) {
            prices[_addresses[i]] = _values[i];
            emit OracleUpdate(_addresses[i], _values[i], block.timestamp);
        }
    }

    function getTraitBooster(address _address, uint256 _id) public view returns(uint256){
        //random boosting for now
        return 120;
    }

    function getPrice(address _address, uint256 _id) public view returns (uint256) {
        VaultLib.SUPPORTED_COLLECTIONS memory COLLECTION_DETAILS =  IVaultManager(vaultManager).getWhitelistedDetails(_address);

        if (COLLECTION_DETAILS.TYPE == VaultLib.COLLECTION_TYPE.Oracle) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(COLLECTION_DETAILS.VAULUATION_PERFORMER);
            (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

            if (answer != 0){
                return (uint256(answer) * getTraitBooster(_address, _id)) / 100;
            }
        } else if (COLLECTION_DETAILS.TYPE == VaultLib.COLLECTION_TYPE.Custom) {
            return prices[_address] * getTraitBooster(_address, _id);
        } else if (COLLECTION_DETAILS.TYPE == VaultLib.COLLECTION_TYPE.SmartContract) {
           return ICustomWrapper(COLLECTION_DETAILS.VAULUATION_PERFORMER).getPrice(_address, _id);
        }

        revert();
    }
}

