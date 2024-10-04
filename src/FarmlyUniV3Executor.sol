pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {SqrtPriceX96} from "./libraries/SqrtPriceX96.sol";
import {FarmlyZapV3, V3PoolCallee} from "./libraries/FarmlyZapV3.sol";

contract FarmlyUniV3Executor is IERC721Receiver {
    IERC20Metadata public token0;
    IERC20Metadata public token1;
    uint24 poolFee = 500;
    uint24 tickSpacing = 10;
    uint256 public latestTokenId;

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    IUniswapV3Pool public pool =
        IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);

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

    constructor() {
        token0 = IERC20Metadata(pool.token0());
        token1 = IERC20Metadata(pool.token1());
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function mintPosition(
        PositionInfo memory positionInfo,
        uint256 amount0Add,
        uint256 amount1Add
    ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: poolFee,
                tickLower: positionInfo.tickLower,
                tickUpper: positionInfo.tickUpper,
                amount0Desired: amount0Add,
                amount1Desired: amount1Add,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, , amount0, amount1) = nonfungiblePositionManager.mint(params);
    }

    function increasePosition(
        uint256 amount0Add,
        uint256 amount1Add
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(latestTokenId);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: latestTokenId,
                    amount0Desired: amount0Add,
                    amount1Desired: amount1Add,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    function decreasePosition(
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: latestTokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        (amount0, amount1) = _collect();
    }

    function collectFees() internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _collect();
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) internal returns (uint amountOut) {
        IERC20Metadata(tokenIn).approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    function getAmountsForAdd(
        PositionInfo memory positionInfo
    )
        public
        view
        returns (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        )
    {
        (
            uint256 amountIn,
            uint256 amountOut,
            bool zeroForOne,
            uint160 sqrtPriceX96
        ) = FarmlyZapV3.getOptimalSwap(
                V3PoolCallee.wrap(address(pool)),
                positionInfo.tickLower,
                positionInfo.tickUpper,
                positionInfo.amount0Add,
                positionInfo.amount1Add
            );

        swapInfo.tokenIn = zeroForOne ? address(token0) : address(token1);

        swapInfo.tokenOut = zeroForOne ? address(token1) : address(token0);

        swapInfo.amountIn = amountIn;

        swapInfo.amountOut = amountOut;

        swapInfo.sqrtPriceX96 = sqrtPriceX96;

        amount0Add = zeroForOne
            ? positionInfo.amount0Add - amountIn
            : positionInfo.amount0Add + amountOut;

        amount1Add = zeroForOne
            ? positionInfo.amount1Add + amountOut
            : positionInfo.amount1Add - amountIn;
    }

    function _collect() private returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams(
                latestTokenId,
                address(this),
                type(uint128).max,
                type(uint128).max
            )
        );
    }

    function positionAmounts()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(latestTokenId);

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    function getTick(int256 price) internal view returns (int24) {
        return
            SqrtPriceX96.nearestUsableTick(
                TickMath.getTickAtSqrtRatio(
                    SqrtPriceX96.encodeSqrtPriceX96(
                        uint256(price),
                        token0.decimals(),
                        token1.decimals()
                    )
                ),
                tickSpacing
            );
    }
}
