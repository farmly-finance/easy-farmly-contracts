pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IFarmlyBaseExecutor} from "../interfaces/base/IFarmlyBaseExecutor.sol";
import {FarmlyBaseExecutor} from "../base/FarmlyBaseExecutor.sol";
import {FarmlyZapV3, V3PoolCallee} from "../libraries/FarmlyZapV3.sol";
import {FarmlyTickLib} from "../libraries/FarmlyTickLib.sol";
import {FarmlyTransferHelper} from "../libraries/FarmlyTransferHelper.sol";
import {FarmlyFullMath} from "../libraries/FarmlyFullMath.sol";
contract FarmlyUniV3Executor is FarmlyBaseExecutor {
    /// @notice Position
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint amount0Add;
        uint amount1Add;
    }

    /// @notice Swap
    struct Swap {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint160 sqrtPriceX96;
    }

    /// @notice Factory
    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x0000000000000000000000000000000000000000);
    /// @notice Nonfungible position manager
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0x0000000000000000000000000000000000000000);
    /// @notice Swap router
    ISwapRouter public swapRouter =
        ISwapRouter(0x0000000000000000000000000000000000000000);

    /// @notice Token 0
    IERC20Metadata public token0;
    /// @notice Token 1
    IERC20Metadata public token1;
    /// @notice Pool fee
    uint24 public poolFee;
    /// @notice Pool
    IUniswapV3Pool public pool;
    /// @notice Tick spacing
    uint24 public tickSpacing;
    /// @notice Latest token id
    uint256 public latestTokenId;

    /// @notice Constructor
    /// @param _token0 Token 0
    /// @param _token1 Token 1
    /// @param _poolFee Pool fee
    constructor(address _token0, address _token1, uint24 _poolFee) {
        pool = IUniswapV3Pool(factory.getPool(_token0, _token1, _poolFee));
        tickSpacing = uint24(pool.tickSpacing());
        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);
        poolFee = _poolFee;
    }

    /// @inheritdoc IFarmlyBaseExecutor
    function positionAmounts()
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        if (latestTokenId == 0) {
            (
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidity
            ) = positionInfo();

            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
        }
    }

    /// @inheritdoc IFarmlyBaseExecutor
    function positionFees()
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        if (latestTokenId != 0) {
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
            ) = feeGrowthInside(tickLower, tickUpper);

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
    }

    /// @inheritdoc IFarmlyBaseExecutor
    function onRebalance(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external override {
        collectFees();

        (, , uint128 liquidity) = positionInfo();

        decreasePosition(liquidity);

        burnPositionToken();

        addBalanceLiquidity(_lowerPrice, _upperPrice);
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onDeposit(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external override {
        addBalanceLiquidity(_lowerPrice, _upperPrice);
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onWithdraw(uint256 _amount) external override {
        collectFees();

        addBalanceLiquidity(0, 0);

        (, , uint128 liquidity) = positionInfo();

        decreasePosition(liquidity);
    }

    /// @notice Add balance liquidity
    /// @param _lowerPrice Lower price
    /// @param _upperPrice Upper price
    function addBalanceLiquidity(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) internal {
        (uint256 amount0, uint256 amount1) = tokenBalances();

        if (latestTokenId == 0) {
            Position memory position = Position(
                FarmlyTickLib.getTick(
                    _lowerPrice,
                    token0.decimals(),
                    token1.decimals(),
                    tickSpacing
                ),
                FarmlyTickLib.getTick(
                    _upperPrice,
                    token0.decimals(),
                    token1.decimals(),
                    tickSpacing
                ),
                amount0,
                amount1
            );

            (
                Swap memory swap,
                uint256 amount0Add,
                uint256 amount1Add
            ) = amountsForAdd(position);

            swapExactInput(swap);

            (latestTokenId, , ) = mintPosition(
                position,
                amount0Add,
                amount1Add
            );
        } else {
            (int24 tickLower, int24 tickUpper, ) = positionInfo();

            Position memory position = Position(
                tickLower,
                tickUpper,
                amount0,
                amount1
            );

            (
                Swap memory swap,
                uint256 amount0Add,
                uint256 amount1Add
            ) = amountsForAdd(position);

            swapExactInput(swap);

            increasePosition(amount0Add, amount1Add);
        }
    }

    /// @notice Increase position
    /// @param _amount0 Amount 0
    /// @param _amount1 Amount 1
    /// @return liquidity Liquidity
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function increasePosition(
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        if (_amount0 > 0) {
            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                _amount0
            );
        }

        if (_amount1 > 0) {
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                _amount1
            );
        }

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: latestTokenId,
                    amount0Desired: _amount0,
                    amount1Desired: _amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    /// @notice Decrease position
    /// @param _liquidity Liquidity
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function decreasePosition(
        uint128 _liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: latestTokenId,
                liquidity: _liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        (amount0, amount1) = collectFees();
    }

    /// @notice Mint position
    /// @param _position Position
    /// @param _amount0 Amount 0
    /// @param _amount1 Amount 1
    /// @return tokenId Token id
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function mintPosition(
        Position memory _position,
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        if (_amount0 > 0) {
            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                _amount0
            );
        }

        if (_amount1 > 0) {
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                _amount1
            );
        }

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: poolFee,
                tickLower: _position.tickLower,
                tickUpper: _position.tickUpper,
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, , amount0, amount1) = nonfungiblePositionManager.mint(params);
    }

    /// @notice Swap exact input
    /// @param _swap Swap
    /// @return amountOut Amount out
    function swapExactInput(
        Swap memory _swap
    ) internal returns (uint256 amountOut) {
        if (_swap.amountIn > 0) {
            FarmlyTransferHelper.safeApprove(
                _swap.tokenIn,
                address(swapRouter),
                _swap.amountIn
            );

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: _swap.tokenIn,
                    tokenOut: _swap.tokenOut,
                    fee: poolFee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: _swap.amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            amountOut = swapRouter.exactInputSingle(params);
        }
    }

    /// @notice Collect fees
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function collectFees() internal returns (uint256 amount0, uint256 amount1) {
        if (latestTokenId != 0) {
            (amount0, amount1) = nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: latestTokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }
    }

    /// @notice Burn position token
    function burnPositionToken() internal {
        if (latestTokenId != 0) {
            nonfungiblePositionManager.burn(latestTokenId);
            latestTokenId = 0;
        }
    }

    /// @notice Position info
    /// @return tickLower Tick lower
    /// @return tickUpper Tick upper
    /// @return liquidity Liquidity
    function positionInfo()
        internal
        view
        returns (int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        if (latestTokenId != 0) {
            (
                ,
                ,
                ,
                ,
                ,
                tickLower,
                tickUpper,
                liquidity,
                ,
                ,
                ,

            ) = nonfungiblePositionManager.positions(latestTokenId);
        }
    }

    /// @notice Amounts for add
    /// @param _position Position
    /// @return swap Swap
    /// @return amount0Add Amount 0 add
    /// @return amount1Add Amount 1 add
    function amountsForAdd(
        Position memory _position
    )
        internal
        view
        returns (Swap memory swap, uint256 amount0Add, uint256 amount1Add)
    {
        (uint256 amountIn, uint256 amountOut, bool zeroForOne, ) = FarmlyZapV3
            .getOptimalSwap(
                V3PoolCallee.wrap(address(pool)),
                _position.tickLower,
                _position.tickUpper,
                _position.amount0Add,
                _position.amount1Add
            );

        swap.tokenIn = zeroForOne ? address(token0) : address(token1);

        swap.tokenOut = zeroForOne ? address(token1) : address(token0);

        swap.amountIn = amountIn;

        swap.amountOut = amountOut;

        amount0Add = zeroForOne
            ? _position.amount0Add - amountIn
            : _position.amount0Add + amountOut;

        amount1Add = zeroForOne
            ? _position.amount1Add + amountOut
            : _position.amount1Add - amountIn;
    }

    /// @notice Token balances
    /// @return amount0 Balance of token 0
    /// @return amount1 Balance of token 1
    function tokenBalances()
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = token0.balanceOf(address(this));
        amount1 = token1.balanceOf(address(this));
    }

    /// @notice Fee growth inside
    /// @param tickLower Tick lower
    /// @param tickUpper Tick upper
    /// @return feeGrowthInside0X128 Fee growth inside 0X128
    /// @return feeGrowthInside1X128 Fee growth inside 1X128
    function feeGrowthInside(
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
}
