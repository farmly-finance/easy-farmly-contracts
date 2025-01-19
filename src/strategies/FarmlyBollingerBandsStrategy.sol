pragma solidity ^0.8.13;

import {FarmlyBaseStrategy} from "../base/FarmlyBaseStrategy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FarmlyFullMath} from "../libraries/FarmlyFullMath.sol";

contract FarmlyBollingerBandsStrategy is
    FarmlyBaseStrategy,
    AutomationCompatibleInterface,
    Ownable
{
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

    /// @notice New bands event
    event NewBands(
        uint256 price,
        uint256 lowerBand,
        uint256 upperBand,
        uint256 midBand,
        uint256 timestamp
    );

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
            (
                uint256 upperBand,
                uint256 sma,
                uint256 lowerBand
            ) = calculateBollingerBands();

            latestLowerPrice = lowerBand;
            latestUpperPrice = upperBand;
            latestMidPrice = sma;
            latestTimestamp = block.timestamp;

            emit NewBands(
                price,
                lowerBand,
                upperBand,
                sma,
                nextPeriodStartTimestamp
            );
        }

        nextPeriodStartTimestamp += PERIOD;
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

    function isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp >= nextPeriodStartTimestamp;
    }

    /// @notice Prices length
    function pricesLength() external view returns (uint256) {
        return prices.length;
    }
}
