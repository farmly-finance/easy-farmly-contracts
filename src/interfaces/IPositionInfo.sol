pragma solidity ^0.8.13;

interface IPositionInfo {
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
}
