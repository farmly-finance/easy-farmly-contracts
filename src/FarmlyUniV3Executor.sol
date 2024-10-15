pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {SqrtPriceX96} from "./libraries/SqrtPriceX96.sol";
import {FarmlyZapV3, V3PoolCallee} from "./libraries/FarmlyZapV3.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {FarmlyTransferHelper} from "./libraries/FarmlyTransferHelper.sol";

contract FarmlyUniV3Executor is IERC721Receiver {
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    IERC20Metadata public token0;
    IERC20Metadata public token1;

    IUniswapV3Pool public pool;
    uint24 public poolFee;
    uint24 public tickSpacing;
    uint256 public latestTokenId;

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

    constructor(address _token0, address _token1, uint24 _poolFee) {
        pool = IUniswapV3Pool(factory.getPool(_token0, _token1, _poolFee));
        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);
        poolFee = _poolFee;
        tickSpacing = uint24(pool.tickSpacing());
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
        if (amount0Add > 0)
            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                amount0Add
            );

        if (amount1Add > 0)
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                amount1Add
            );

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
        if (amount0Add > 0)
            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                amount0Add
            );

        if (amount1Add > 0)
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                amount1Add
            );

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

    function burnPositionToken() internal {
        nonfungiblePositionManager.burn(latestTokenId);
        latestTokenId = 0;
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) internal returns (uint amountOut) {
        if (amountIn > 0) {
            FarmlyTransferHelper.safeApprove(
                tokenIn,
                address(swapRouter),
                amountIn
            );

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

    function positionFees()
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
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = nonfungiblePositionManager.positions(latestTokenId);

        (
            uint256 poolFeeGrowthInside0LastX128,
            uint256 poolFeeGrowthInside1LastX128
        ) = getFeeGrowthInside(tickLower, tickUpper);

        amount0 =
            FarmlyFullMath.mulDiv(
                poolFeeGrowthInside0LastX128 - feeGrowthInside0LastX128,
                liquidity,
                FixedPoint128.Q128
            ) +
            tokensOwed0;

        amount1 =
            FarmlyFullMath.mulDiv(
                poolFeeGrowthInside1LastX128 - feeGrowthInside1LastX128,
                liquidity,
                FixedPoint128.Q128
            ) +
            tokensOwed1;
    }

    function getFeeGrowthInside(
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (, int24 tick, , , , , ) = pool.slot0();

        (
            ,
            ,
            uint256 lowerFeeGrowthOutside0X128,
            uint256 lowerFeeGrowthOutside1X128,
            ,
            ,
            ,

        ) = pool.ticks(tickLower);
        (
            ,
            ,
            uint256 upperFeeGrowthOutside0X128,
            uint256 upperFeeGrowthOutside1X128,
            ,
            ,
            ,

        ) = pool.ticks(tickUpper);

        uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
        uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();

        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tick >= tickLower) {
            feeGrowthBelow0X128 = lowerFeeGrowthOutside0X128;
            feeGrowthBelow1X128 = lowerFeeGrowthOutside1X128;
        } else {
            unchecked {
                feeGrowthBelow0X128 =
                    feeGrowthGlobal0X128 -
                    lowerFeeGrowthOutside0X128;
                feeGrowthBelow1X128 =
                    feeGrowthGlobal1X128 -
                    lowerFeeGrowthOutside1X128;
            }
        }

        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tick < tickUpper) {
            feeGrowthAbove0X128 = upperFeeGrowthOutside0X128;
            feeGrowthAbove1X128 = upperFeeGrowthOutside1X128;
        } else {
            unchecked {
                feeGrowthAbove0X128 =
                    feeGrowthGlobal0X128 -
                    upperFeeGrowthOutside0X128;
                feeGrowthAbove1X128 =
                    feeGrowthGlobal1X128 -
                    upperFeeGrowthOutside1X128;
            }
        }

        unchecked {
            feeGrowthInside0X128 =
                feeGrowthGlobal0X128 -
                feeGrowthBelow0X128 -
                feeGrowthAbove0X128;
            feeGrowthInside1X128 =
                feeGrowthGlobal1X128 -
                feeGrowthBelow1X128 -
                feeGrowthAbove1X128;
        }
    }

    function getTick(uint256 price) internal view returns (int24) {
        return
            SqrtPriceX96.nearestUsableTick(
                TickMath.getTickAtSqrtRatio(
                    SqrtPriceX96.encodeSqrtPriceX96(
                        price,
                        token0.decimals(),
                        token1.decimals()
                    )
                ),
                tickSpacing
            );
    }

    function decodeTick(int24 tick) internal view returns (uint256) {
        return
            SqrtPriceX96.decodeSqrtPriceX96(
                TickMath.getSqrtRatioAtTick(tick),
                token0.decimals(),
                token1.decimals()
            );
    }

    function positionLiquidity() internal view returns (uint128 liquidity) {
        (, , , , , , , liquidity, , , , ) = nonfungiblePositionManager
            .positions(latestTokenId);
    }
}
