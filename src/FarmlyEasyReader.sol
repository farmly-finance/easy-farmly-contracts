pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IFarmlyPositionManager.sol";
import {SqrtPriceX96} from "./libraries/SqrtPriceX96.sol";
import {FarmlyZapV3, V3PoolCallee} from "./libraries/FarmlyZapV3.sol";

contract FarmlyEasyReader {
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;

    function getPoolInfo(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            address token0,
            address token1,
            uint24 poolFee,
            uint24 tickSpacing
        )
    {
        token0 = positionManager.token0();
        token1 = positionManager.token1();
        poolFee = positionManager.poolFee();
        tickSpacing = positionManager.tickSpacing();
    }

    function getDataFeeds(
        IFarmlyPositionManager positionManager
    ) public view returns (address token0DataFeed, address token1DataFeed) {
        token0DataFeed = positionManager.token0DataFeed();
        token1DataFeed = positionManager.token1DataFeed();
    }

    function getSlot0(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        (
            sqrtPriceX96,
            tick,
            observationIndex,
            observationCardinality,
            observationCardinalityNext,
            feeProtocol,
            unlocked
        ) = positionManager.pool().slot0();
    }

    function getLatest(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            int256 latestLowerPrice,
            int256 latestPrice,
            int256 latestUpperPrice,
            uint256 latestTimestamp,
            uint256 latestTokenId
        )
    {
        (uint160 sqrtPriceX96, , , , , , ) = getSlot0(positionManager);
        latestLowerPrice = positionManager.latestLowerPrice();
        latestPrice = int256(
            SqrtPriceX96.decodeSqrtPriceX96(
                sqrtPriceX96,
                IERC20Metadata(positionManager.token0()).decimals(),
                IERC20Metadata(positionManager.token1()).decimals()
            )
        );
        latestUpperPrice = positionManager.latestUpperPrice();
        latestTimestamp = positionManager.latestTimestamp();
        latestTokenId = positionManager.latestTokenId();
    }

    function getConfig(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            int256 positionThreshold,
            uint256 performanceFee,
            address feeAddress,
            address forwarderAddress,
            uint8 decimals
        )
    {
        positionThreshold = positionManager.positionThreshold();
        performanceFee = positionManager.performanceFee();
        feeAddress = positionManager.feeAddress();
        forwarderAddress = positionManager.forwarderAddress();
        decimals = positionManager.decimals();
    }

    function getUSDValues(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            uint256 sharePrice,
            uint256 totalUSDValue,
            uint256 positionFeesUSD,
            uint256 positionAmountsUSD,
            uint256 balancesUSD
        )
    {
        sharePrice = positionManager.sharePrice();
        totalUSDValue = positionManager.totalUSDValue();
        (, , positionFeesUSD) = positionManager.positionFeesUSD();
        (, , positionAmountsUSD) = positionManager.positionAmountsUSD();
        (, , balancesUSD) = positionManager.balancesUSD();
    }

    function getTokenBalances(
        IERC20[] memory tokens,
        address user
    ) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].balanceOf(user);
        }

        return balances;
    }

    function getTokenAllowances(
        IERC20[] memory tokens,
        address spender,
        address user
    ) public view returns (uint256[] memory) {
        uint256[] memory allowances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            allowances[i] = tokens[i].allowance(user, spender);
        }

        return allowances;
    }

    function getTokenPrices(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            int256 token0Price,
            int256 token1Price,
            uint8 token0PriceDecimals,
            uint8 token1PriceDecimals
        )
    {
        (address _token0DataFeed, address _token1DataFeed) = getDataFeeds(
            positionManager
        );

        AggregatorV3Interface token0DataFeed = AggregatorV3Interface(
            _token0DataFeed
        );

        AggregatorV3Interface token1DataFeed = AggregatorV3Interface(
            _token1DataFeed
        );

        (, token0Price, , , ) = token0DataFeed.latestRoundData();
        (, token1Price, , , ) = token1DataFeed.latestRoundData();
        token0PriceDecimals = token0DataFeed.decimals();
        token1PriceDecimals = token1DataFeed.decimals();
    }

    function shareToAmounts(
        IFarmlyPositionManager positionManager,
        uint256 amount
    ) public view returns (uint256 amount0, uint256 amount1) {
        (uint256 amount0Fee, uint256 amount1Fee) = positionManager
            .positionFees();

        amount0Fee -=
            (amount0Fee * positionManager.performanceFee()) /
            THRESHOLD_DENOMINATOR;

        amount1Fee -=
            (amount1Fee * positionManager.performanceFee()) /
            THRESHOLD_DENOMINATOR;

        IFarmlyUniV3Executor.PositionInfo
            memory positionInfo = IFarmlyUniV3Executor.PositionInfo(
                getTick(positionManager, positionManager.latestLowerPrice()),
                getTick(positionManager, positionManager.latestUpperPrice()),
                amount0Fee,
                amount1Fee
            );

        (
            IFarmlyUniV3Executor.SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        ) = positionManager.getAmountsForAdd(positionInfo);

        uint128 feesLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            swapInfo.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionInfo.tickLower),
            TickMath.getSqrtRatioAtTick(positionInfo.tickUpper),
            amount0Add,
            amount1Add
        );

        uint128 _positionLiquidity = positionLiquidity(positionManager);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            swapInfo.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionInfo.tickLower),
            TickMath.getSqrtRatioAtTick(positionInfo.tickUpper),
            ((feesLiquidity + _positionLiquidity) * uint128(amount)) /
                uint128(IERC20(address(positionManager)).totalSupply())
        );
    }

    function getTick(
        IFarmlyPositionManager positionManager,
        int256 price
    ) internal view returns (int24) {
        return
            SqrtPriceX96.nearestUsableTick(
                TickMath.getTickAtSqrtRatio(
                    SqrtPriceX96.encodeSqrtPriceX96(
                        uint256(price),
                        IERC20Metadata(positionManager.token0()).decimals(),
                        IERC20Metadata(positionManager.token1()).decimals()
                    )
                ),
                positionManager.tickSpacing()
            );
    }

    function positionLiquidity(
        IFarmlyPositionManager positionManager
    ) internal view returns (uint128 liquidity) {
        (, , , , , , , liquidity, , , , ) = positionManager
            .nonfungiblePositionManager()
            .positions(positionManager.latestTokenId());
    }
}
