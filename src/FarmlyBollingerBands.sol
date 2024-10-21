pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";

contract FarmlyBollingerBands is AutomationCompatibleInterface, Ownable {
    AggregatorV3Interface public token0DataFeed;

    AggregatorV3Interface public token1DataFeed;

    uint16 public ma;
    uint16 public multiplier;
    uint256 public period;
    uint256[] public prices;
    uint256 public pricesLength;
    uint256 public nextPeriodStartTimestamp;
    uint256 public latestUpperBand;
    uint256 public latestSma;
    uint256 public latestLowerBand;
    address public farmlyBollingerBandsFactory;

    event NewBand(
        uint256 price,
        uint256 upperBand,
        uint256 sma,
        uint256 lowerBand,
        uint256 timestamp
    );

    constructor(
        uint16 _ma,
        uint16 _multiplier,
        uint256 _period,
        uint256 _startTimestamp,
        address _token0DataFeed,
        address _token1DataFeed
    ) {
        ma = _ma;
        multiplier = _multiplier;
        period = _period;
        nextPeriodStartTimestamp = _startTimestamp;
        token0DataFeed = AggregatorV3Interface(_token0DataFeed);
        token1DataFeed = AggregatorV3Interface(_token1DataFeed);
        farmlyBollingerBandsFactory = msg.sender;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = isUpkeepNeeded();
    }

    function performUpkeep(
        bytes calldata /* performData  */
    ) external override {
        if (isUpkeepNeeded()) {
            (uint256 token0Price, uint256 token1Price) = getPrices();

            uint256 price = FarmlyFullMath.mulDiv(
                token0Price,
                1e18,
                token1Price
            );

            prices.push(price);

            pricesLength++;

            if (prices.length >= ma) {
                (
                    uint256 upperBand,
                    uint256 sma,
                    uint256 lowerBand
                ) = calculateBollingerBands();

                latestUpperBand = upperBand;

                latestSma = sma;

                latestLowerBand = lowerBand;

                emit NewBand(
                    price,
                    upperBand,
                    sma,
                    lowerBand,
                    nextPeriodStartTimestamp
                );
            }

            nextPeriodStartTimestamp += period;
        }
    }

    function isUpkeepNeeded() internal view returns (bool) {
        return block.timestamp >= nextPeriodStartTimestamp;
    }

    function calculateSMA() internal view returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = prices.length - ma; i < prices.length; i++) {
            sum += prices[i];
        }

        return sum / ma;
    }

    function calculateStdDev(uint256 sma) internal view returns (uint256) {
        uint256 variance = 0;

        for (uint256 i = prices.length - ma; i < prices.length; i++) {
            int256 diff = int256(prices[i]) - int256(sma);

            variance += uint256(diff * diff);
        }

        return FarmlyFullMath.sqrt(variance / ma);
    }

    function calculateBollingerBands()
        internal
        view
        returns (uint256 upperBand, uint256 sma, uint256 lowerBand)
    {
        sma = calculateSMA();
        uint256 stdDev = calculateStdDev(sma);

        upperBand = sma + (multiplier * stdDev);
        lowerBand = sma - (multiplier * stdDev);
    }

    function getPrices()
        internal
        view
        returns (uint256 token0Price, uint256 token1Price)
    {
        (, int256 token0Answer, , , ) = token0DataFeed.latestRoundData();
        (, int256 token1Answer, , , ) = token1DataFeed.latestRoundData();

        token0Price = FarmlyFullMath.mulDiv(
            uint256(token0Answer),
            1e18,
            10 ** token0DataFeed.decimals()
        );

        token1Price = FarmlyFullMath.mulDiv(
            uint256(token1Answer),
            1e18,
            10 ** token1DataFeed.decimals()
        );
    }
}
