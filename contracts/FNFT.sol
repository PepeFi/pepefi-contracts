pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import './interfaces/INonfungiblePositionManager.sol';

contract FNFT is Ownable, ERC721URIStorage{

    struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(uint256 => Position) private _positions;

    uint256 tokenId = 1;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {

    }


    function mint(address recipient, string memory tokenURI) public {        
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: 0,
            tickLower: 0,
            tickUpper: 0,
            liquidity: 0,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        tokenId = tokenId + 1;        
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        return (
            position.nonce,
            position.operator,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            0,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

     function total(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) external view returns (uint256 amount0, uint256 amount1) {
        //return a constant for our purpose
        amount0 = 1 ether;
        amount1 = 1 ether;
    }




}