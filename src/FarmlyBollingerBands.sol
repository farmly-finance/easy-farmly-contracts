pragma solidity ^0.8.13;

import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";

contract FarmlyBollingerBands is AutomationCompatibleInterface, Ownable {
    AggregatorV3Interface public token0DataFeed;

    AggregatorV3Interface public token1DataFeed;

    uint16 public ma;
    int16 public multiplier;
    uint256 public period;
    int256[] public prices;
    uint256 public pricesLength;
    uint256 public nextPeriodStartTimestamp;
    int256 public latestUpperBand;
    int256 public latestSma;
    int256 public latestLowerBand;

    address public forwarderAddress;

    modifier onlyForwarder() {
        require(msg.sender == forwarderAddress, "NOT FORWARDER");
        _;
    }

    event NewBand(
        int256 price,
        int256 upperBand,
        int256 sma,
        int256 lowerBand,
        uint256 timestamp
    );

    constructor(
        uint16 _ma,
        int16 _multiplier,
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
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (isUpkeepNeeded()) {
            (int256 token0Price, int256 token1Price) = getPrices();
            performData = abi.encode((token0Price * 1e18) / token1Price);
            upkeepNeeded = true;
        }
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        if (isUpkeepNeeded()) {
            int256 price = abi.decode(performData, (int256));
            prices.push(price);
            pricesLength++;
            if (prices.length >= ma) {
                (
                    int256 upperBand,
                    int256 sma,
                    int256 lowerBand
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

    function calculateSMA() internal view returns (int256) {
        int256 sum = 0;
        for (uint256 i = prices.length - ma; i < prices.length; i++) {
            sum += prices[i];
        }
        return sum / int16(ma);
    }

    function calculateStdDev(int256 sma) internal view returns (int256) {
        uint256 variance = 0;
        for (uint256 i = prices.length - ma; i < prices.length; i++) {
            int256 diff = int256(prices[i]) - sma;
            variance += uint256(diff * diff);
        }
        return int256(FarmlyFullMath.sqrt(variance / ma));
    }

    function calculateBollingerBands()
        internal
        view
        returns (int256 upperBand, int256 sma, int256 lowerBand)
    {
        sma = calculateSMA();
        int256 stdDev = calculateStdDev(sma);

        upperBand = sma + (multiplier * stdDev);
        lowerBand = sma - (multiplier * stdDev);
    }

    function getPrices()
        internal
        view
        returns (int256 token0Price, int256 token1Price)
    {
        (, int256 token0Answer, , , ) = token0DataFeed.latestRoundData();
        (, int256 token1Answer, , , ) = token1DataFeed.latestRoundData();

        token0Price =
            (token0Answer * 1e18) /
            int256(10 ** token0DataFeed.decimals());
        token1Price =
            (token1Answer * 1e18) /
            int256(10 ** token1DataFeed.decimals());
    }

    function setForwarder(address _forwarderAddress) public onlyOwner {
        forwarderAddress = _forwarderAddress;
    }
}
