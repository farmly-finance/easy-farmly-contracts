pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

interface IFarmlyUniV3Executor {
    struct PositionInfo {
        int24 tickLower;
        int24 tickUpper;
        uint amount0Add;
        uint amount1Add;
    }

    struct SwapInfo {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint160 sqrtPriceX96;
    }

    function token0() external view returns (address);

    function token1() external view returns (address);

    function poolFee() external view returns (uint24);

    function tickSpacing() external view returns (uint24);

    function latestTokenId() external view returns (uint256);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    function getAmountsForAdd(
        PositionInfo memory positionInfo
    )
        external
        view
        returns (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        );

    function positionAmounts()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function positionFees()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function pool() external view returns (IUniswapV3Pool pool);

    function nonfungiblePositionManager()
        external
        view
        returns (INonfungiblePositionManager nonfungiblePositionManager);
}
