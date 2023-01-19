import "./INonfungiblePositionManager.sol";

interface IPositionValue {
    function total(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) external view returns (uint256 amount0, uint256 amount1);
}