pragma solidity ^0.8.9;

import "./interfaces/IPositionValue.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "hardhat/console.sol";

contract UniswapWrapper {
    address UNISWAP_POSITION_VALUE;
    address UNISWAP_POSITION_MANAGER;
    
    constructor (address _UNISWAP_POSITION_VALUE, address _UNISWAP_POSITION_MANAGER) {
        UNISWAP_POSITION_VALUE = _UNISWAP_POSITION_VALUE;
        UNISWAP_POSITION_MANAGER = _UNISWAP_POSITION_MANAGER;
    }
    
    // changed: commented unused out var to remove compiler warning
    function getPrice(address /*_address*/, uint256 _tokenId) public view returns (uint256) {
        (uint256 token1, uint256 token2) = IPositionValue(UNISWAP_POSITION_VALUE).total(INonfungiblePositionManager(UNISWAP_POSITION_MANAGER), _tokenId, 0);
        // review: ??
        return token1 * 1 + token2 * 1;
    }
}