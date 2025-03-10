pragma solidity ^0.8.13;

import {FarmlyBaseStrategy} from "../base/FarmlyBaseStrategy.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FarmlyFullMath} from "../libraries/FarmlyFullMath.sol";
import {FarmlyDenominator} from "../libraries/FarmlyDenominator.sol";

contract FarmlyBollingerBandsStrategy is
    FarmlyBaseStrategy,
    AutomationCompatibleInterface
{
    /// @notice Not upkeep needed error
    error NotUpkeepNeeded();

    /// @notice Moving average period
    uint16 public MA;
    /// @notice Standard deviation multiplier
    uint16 public STD;
    /// @notice Period
    uint256 public PERIOD;
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

    /// @notice Constructor
    /// @param _token0DataFeed Token 0 data feed
    /// @param _token1DataFeed Token 1 data feed
    /// @param _ma Moving average period
    /// @param _std Standard deviation multiplier
    /// @param _period Period
    /// @param _rebalanceThreshold Rebalance threshold
    constructor(
        address _token0DataFeed,
        address _token1DataFeed,
        uint16 _ma,
        uint16 _std,
        uint256 _period,
        uint256 _rebalanceThreshold
    ) FarmlyBaseStrategy(_token0DataFeed, _token1DataFeed) {
        MA = _ma;
        STD = _std;
        PERIOD = _period;
        rebalanceThreshold = _rebalanceThreshold;
        latestTimestamp = (block.timestamp / PERIOD) * PERIOD;
        nextPeriodStartTimestamp = latestTimestamp + PERIOD;
    }

    /// @notice Is rebalance needed
    function isRebalanceNeeded(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external view override returns (bool) {
        uint256 upperThreshold = FarmlyFullMath.mulDiv(
            _upperPrice,
            rebalanceThreshold,
            FarmlyDenominator.DENOMINATOR
        );
        uint256 lowerThreshold = FarmlyFullMath.mulDiv(
            _lowerPrice,
            rebalanceThreshold,
            FarmlyDenominator.DENOMINATOR
        );

        bool upperRebalanceNeeded = (_latestUpperPrice <
            _upperPrice - upperThreshold) ||
            (_latestUpperPrice > _upperPrice + upperThreshold);

        bool lowerRebalanceNeeded = (_latestLowerPrice <
            _lowerPrice - lowerThreshold) ||
            (_latestLowerPrice > _lowerPrice + lowerThreshold);

        return upperRebalanceNeeded || lowerRebalanceNeeded;
    }

    /// @notice Is upkeep needed
    function isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp >= nextPeriodStartTimestamp;
    }

    /// @notice Check upkeep
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = isUpkeepNeeded();
    }

    /// @notice Perform upkeep
    function performUpkeep(bytes calldata performData) external override {
        if (!isUpkeepNeeded()) {
            revert NotUpkeepNeeded();
        }

        _setLatestPrice();

        prices.push(_latestPrice);

        if (prices.length >= MA) {
            updateBands();

            emit NewBands(
                _latestPrice,
                _latestLowerPrice,
                _latestUpperPrice,
                latestMidPrice,
                nextPeriodStartTimestamp
            );
        }

        latestTimestamp = nextPeriodStartTimestamp;
        nextPeriodStartTimestamp += PERIOD;
    }

    /// @notice Update bands
    function updateBands() internal {
        (
            uint256 upperBand,
            uint256 sma,
            uint256 lowerBand
        ) = calculateBollingerBands();

        _latestUpperPrice = upperBand;
        _latestLowerPrice = lowerBand;
        latestMidPrice = sma;
    }

    /// @notice Calculate SMA
    function calculateSMA() internal view returns (uint256) {
        if (prices.length < MA) {
            return 0;
        }

        uint256 sum = 0;

        for (uint256 i = prices.length - MA; i < prices.length; i++) {
            sum += prices[i];
        }

        return sum / MA;
    }

    /// @notice Calculate standard deviation
    function calculateStdDev(uint256 sma) internal view returns (uint256) {
        if (prices.length < MA) {
            return 0;
        }

        uint256 variance = 0;

        for (uint256 i = prices.length - MA; i < prices.length; i++) {
            int256 diff = int256(prices[i]) - int256(sma);
            variance += uint256(diff * diff);
        }

        return FarmlyFullMath.sqrt(variance / MA);
    }

    /// @notice Calculate Bollinger bands
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
