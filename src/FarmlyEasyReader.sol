pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IFarmlyEasyFarm.sol";
import "./interfaces/IPositionInfo.sol";

import {SqrtPriceX96} from "./libraries/SqrtPriceX96.sol";
import {FarmlyZapV3, V3PoolCallee} from "./libraries/FarmlyZapV3.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";

contract FarmlyEasyReader is IPositionInfo {
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;

    function getPoolInfo(
        IFarmlyEasyFarm farmlyEasyFarm
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
        token0 = farmlyEasyFarm.farmlyUniV3Executor().token0();
        token1 = farmlyEasyFarm.farmlyUniV3Executor().token1();
        poolFee = farmlyEasyFarm.farmlyUniV3Executor().poolFee();
        tickSpacing = farmlyEasyFarm.farmlyUniV3Executor().tickSpacing();
    }

    function getDataFeeds(
        IFarmlyEasyFarm farmlyEasyFarm
    ) public view returns (address token0DataFeed, address token1DataFeed) {
        token0DataFeed = farmlyEasyFarm.token0DataFeed();
        token1DataFeed = farmlyEasyFarm.token1DataFeed();
    }

    function getSlot0(
        IFarmlyEasyFarm farmlyEasyFarm
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
        ) = farmlyEasyFarm.farmlyUniV3Executor().pool().slot0();
    }

    function getLatest(
        IFarmlyEasyFarm farmlyEasyFarm
    )
        public
        view
        returns (
            uint256 latestLowerPrice,
            uint256 latestPrice,
            uint256 latestUpperPrice,
            uint256 latestTimestamp,
            uint256 latestTokenId
        )
    {
        (uint160 sqrtPriceX96, , , , , , ) = getSlot0(farmlyEasyFarm);
        latestLowerPrice = farmlyEasyFarm.latestLowerPrice();
        latestPrice = SqrtPriceX96.decodeSqrtPriceX96(
            sqrtPriceX96,
            IERC20Metadata(farmlyEasyFarm.farmlyUniV3Executor().token0())
                .decimals(),
            IERC20Metadata(farmlyEasyFarm.farmlyUniV3Executor().token1())
                .decimals()
        );
        latestUpperPrice = farmlyEasyFarm.latestUpperPrice();
        latestTimestamp = farmlyEasyFarm.latestTimestamp();
        latestTokenId = farmlyEasyFarm.farmlyUniV3Executor().latestTokenId();
    }

    function getConfig(
        IFarmlyEasyFarm farmlyEasyFarm
    )
        public
        view
        returns (
            uint256 positionThreshold,
            uint256 performanceFee,
            address feeAddress
        )
    {
        positionThreshold = farmlyEasyFarm.positionThreshold();
        performanceFee = farmlyEasyFarm.performanceFee();
        feeAddress = farmlyEasyFarm.feeAddress();
    }

    function getUSDValues(
        IFarmlyEasyFarm farmlyEasyFarm
    )
        public
        view
        returns (
            uint256 sharePrice,
            uint256 totalUSDValue,
            uint256 positionFeesUSD,
            uint256 positionAmountsUSD,
            uint256 maximumCapacity
        )
    {
        sharePrice = farmlyEasyFarm.sharePrice();
        totalUSDValue = farmlyEasyFarm.totalUSDValue();
        (, , positionFeesUSD) = farmlyEasyFarm.positionFeesUSD();
        (, , positionAmountsUSD) = farmlyEasyFarm.positionAmountsUSD();
        maximumCapacity = farmlyEasyFarm.maximumCapacity();
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
        IFarmlyEasyFarm farmlyEasyFarm
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
            farmlyEasyFarm
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
        IFarmlyEasyFarm farmlyEasyFarm,
        uint256 amount
    ) public view returns (uint256 amount0, uint256 amount1) {
        // Calculate fees
        (uint256 amount0Fee, uint256 amount1Fee) = calculateFees(
            farmlyEasyFarm
        );

        // Get position info
        PositionInfo memory positionInfo = getPositionInfo(
            farmlyEasyFarm,
            amount0Fee,
            amount1Fee
        );

        // Calculate swap info and amounts
        (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        ) = calculateSwapInfo(farmlyEasyFarm, positionInfo);

        // Calculate liquidity and amounts
        (amount0, amount1) = calculateLiquidityAmounts(
            swapInfo,
            positionInfo,
            amount0Add,
            amount1Add,
            farmlyEasyFarm,
            amount
        );
    }

    function positionAmounts(
        IFarmlyEasyFarm farmlyEasyFarm
    ) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = farmlyEasyFarm
            .farmlyUniV3Executor()
            .positionAmounts();
    }

    function totalPortfolioValue(
        IERC20[] memory farmlyEasyFarms,
        address user
    ) public view returns (uint256[] memory, uint256) {
        uint256[] memory portfolio = new uint256[](farmlyEasyFarms.length);
        uint256 tpv = 0;

        for (uint256 i = 0; i < farmlyEasyFarms.length; i++) {
            IERC20 farmlyEasyFarm = farmlyEasyFarms[i];
            uint256 balance = farmlyEasyFarm.balanceOf(user);
            uint256 sharePrice = IFarmlyEasyFarm(address(farmlyEasyFarm))
                .sharePrice();
            uint256 usdValue = FarmlyFullMath.mulDiv(balance, sharePrice, 1e18);

            portfolio[i] = usdValue;
            tpv += usdValue;
        }

        return (portfolio, tpv);
    }

    function tvl(
        IFarmlyEasyFarm[] memory farmlyEasyFarms
    ) public view returns (uint256) {
        uint256 _tvl = 0;
        for (uint256 i = 0; i < farmlyEasyFarms.length; i++) {
            IFarmlyEasyFarm farmlyEasyFarm = farmlyEasyFarms[i];
            _tvl += farmlyEasyFarm.totalUSDValue();
        }

        return _tvl;
    }

    function calculateFees(
        IFarmlyEasyFarm farmlyEasyFarm
    ) internal view returns (uint256 amount0Fee, uint256 amount1Fee) {
        (amount0Fee, amount1Fee) = farmlyEasyFarm
            .farmlyUniV3Executor()
            .positionFees();

        amount0Fee -= FarmlyFullMath.mulDiv(
            amount0Fee,
            farmlyEasyFarm.performanceFee(),
            THRESHOLD_DENOMINATOR
        );

        amount1Fee -= FarmlyFullMath.mulDiv(
            amount1Fee,
            farmlyEasyFarm.performanceFee(),
            THRESHOLD_DENOMINATOR
        );
    }

    function getPositionInfo(
        IFarmlyEasyFarm farmlyEasyFarm,
        uint256 amount0Fee,
        uint256 amount1Fee
    ) internal view returns (PositionInfo memory positionInfo) {
        positionInfo = PositionInfo(
            getTick(farmlyEasyFarm, farmlyEasyFarm.latestLowerPrice()),
            getTick(farmlyEasyFarm, farmlyEasyFarm.latestUpperPrice()),
            amount0Fee,
            amount1Fee
        );
    }

    function calculateSwapInfo(
        IFarmlyEasyFarm farmlyEasyFarm,
        PositionInfo memory positionInfo
    )
        internal
        view
        returns (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        )
    {
        (swapInfo, amount0Add, amount1Add) = farmlyEasyFarm
            .farmlyUniV3Executor()
            .getAmountsForAdd(positionInfo);
    }

    function calculateLiquidityAmounts(
        SwapInfo memory swapInfo,
        PositionInfo memory positionInfo,
        uint256 amount0Add,
        uint256 amount1Add,
        IFarmlyEasyFarm farmlyEasyFarm,
        uint256 amount
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            swapInfo.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionInfo.tickLower),
            TickMath.getSqrtRatioAtTick(positionInfo.tickUpper),
            amount0Add,
            amount1Add
        );

        uint256 positionLiquidityAmount = positionLiquidity(farmlyEasyFarm);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            swapInfo.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionInfo.tickLower),
            TickMath.getSqrtRatioAtTick(positionInfo.tickUpper),
            uint128(
                FarmlyFullMath.mulDiv(
                    liquidity + positionLiquidityAmount,
                    amount,
                    IERC20(address(farmlyEasyFarm)).totalSupply()
                )
            )
        );
    }

    function getTick(
        IFarmlyEasyFarm farmlyEasyFarm,
        uint256 price
    ) internal view returns (int24) {
        return
            SqrtPriceX96.nearestUsableTick(
                TickMath.getTickAtSqrtRatio(
                    SqrtPriceX96.encodeSqrtPriceX96(
                        price,
                        IERC20Metadata(
                            farmlyEasyFarm.farmlyUniV3Executor().token0()
                        ).decimals(),
                        IERC20Metadata(
                            farmlyEasyFarm.farmlyUniV3Executor().token1()
                        ).decimals()
                    )
                ),
                farmlyEasyFarm.farmlyUniV3Executor().tickSpacing()
            );
    }

    function positionLiquidity(
        IFarmlyEasyFarm farmlyEasyFarm
    ) internal view returns (uint128 liquidity) {
        (, , , , , , , liquidity, , , , ) = farmlyEasyFarm
            .farmlyUniV3Executor()
            .nonfungiblePositionManager()
            .positions(farmlyEasyFarm.farmlyUniV3Executor().latestTokenId());
    }
}
