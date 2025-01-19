pragma solidity ^0.8.13;

import {FarmlyBaseStrategy} from "../base/FarmlyBaseStrategy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FarmlyFullMath} from "../libraries/FarmlyFullMath.sol";
import {FarmlyTickLib} from "../libraries/FarmlyTickLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
contract FarmlyBollingerBandsStrategy is
    FarmlyBaseStrategy,
    AutomationCompatibleInterface,
    Ownable
{
    /// @notice Threshold denominator
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;
    /// @notice Not upkeep needed error
    error NotUpkeepNeeded();
    /// @notice Moving average period
    uint16 public constant MA = 20;
    /// @notice Standard deviation multiplier
    uint16 public constant STD = 2;
    /// @notice Period
    uint256 public constant PERIOD = 1 hours;
    /// @notice Prices
    uint256[] public prices;
    /// @notice Next period start timestamp
    uint256 public nextPeriodStartTimestamp;
    /// @notice Latest mid price
    uint256 public latestMidPrice;
    /// @notice Rebalance threshold
    uint256 public rebalanceThreshold;

    /// @notice New bands event
    event NewBands(
        uint256 price,
        uint256 lowerBand,
        uint256 upperBand,
        uint256 midBand,
        uint256 timestamp
    );

    /// @notice Is rebalance needed
    function isRebalanceNeeded(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external view override returns (bool) {
        uint256 upperThreshold = FarmlyFullMath.mulDiv(
            _upperPrice,
            rebalanceThreshold,
            THRESHOLD_DENOMINATOR
        );
        uint256 lowerThreshold = FarmlyFullMath.mulDiv(
            _lowerPrice,
            rebalanceThreshold,
            THRESHOLD_DENOMINATOR
        );

        bool upperRebalanceNeeded = (latestUpperPrice <
            _upperPrice - upperThreshold) ||
            (latestUpperPrice > _upperPrice + upperThreshold);

        bool lowerRebalanceNeeded = (latestLowerPrice <
            _lowerPrice - lowerThreshold) ||
            (latestLowerPrice > _lowerPrice + lowerThreshold);

        return upperRebalanceNeeded || lowerRebalanceNeeded;
    }

    function isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp >= nextPeriodStartTimestamp;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = isUpkeepNeeded();
    }

    function performUpkeep(bytes calldata performData) external override {
        if (!isUpkeepNeeded()) {
            revert NotUpkeepNeeded();
        }

        uint256 price = uniV3Reader.getPriceE18(uniswapPool);
        prices.push(price);

        if (prices.length >= MA) {
            updateBands();

            emit NewBands(
                price,
                latestLowerPrice,
                latestUpperPrice,
                latestMidPrice,
                nextPeriodStartTimestamp
            );
        }

        nextPeriodStartTimestamp += PERIOD;
    }

    function updateBands() internal {
        (
            uint256 upperBand,
            uint256 sma,
            uint256 lowerBand
        ) = calculateBollingerBands();

        (
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        ) = uniV3Reader.getPoolInfo(uniswapPool);

        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();

        latestLowerPrice = FarmlyTickLib.nearestPrice(
            lowerBand,
            token0Decimals,
            token1Decimals,
            uint24(tickSpacing)
        );
        latestUpperPrice = FarmlyTickLib.nearestPrice(
            upperBand,
            token0Decimals,
            token1Decimals,
            uint24(tickSpacing)
        );
        latestMidPrice = FarmlyTickLib.nearestPrice(
            sma,
            token0Decimals,
            token1Decimals,
            uint24(tickSpacing)
        );

        latestTimestamp = nextPeriodStartTimestamp;
    }

    function calculateSMA() internal view returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = prices.length - MA; i < prices.length; i++) {
            sum += prices[i];
        }

        return sum / MA;
    }

    function calculateStdDev(uint256 sma) internal view returns (uint256) {
        uint256 variance = 0;

        for (uint256 i = prices.length - MA; i < prices.length; i++) {
            int256 diff = int256(prices[i]) - int256(sma);
            variance += uint256(diff * diff);
        }

        return FarmlyFullMath.sqrt(variance / MA);
    }

    function calculateBollingerBands()
        internal
        view
        returns (uint256 upperBand, uint256 sma, uint256 lowerBand)
    {
        sma = calculateSMA();
        uint256 stdDev = calculateStdDev(sma);

        upperBand = sma + (STD * stdDev);
        lowerBand = sma - (STD * stdDev);
    }

    /// @notice Prices length
    function pricesLength() external view returns (uint256) {
        return prices.length;
    }
}
