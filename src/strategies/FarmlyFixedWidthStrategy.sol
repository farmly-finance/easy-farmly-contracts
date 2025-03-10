pragma solidity ^0.8.13;

import {FarmlyBaseStrategy} from "../base/FarmlyBaseStrategy.sol";
import {FarmlyFullMath} from "../libraries/FarmlyFullMath.sol";

/// @title FarmlyFixedWidthStrategy
/// @notice Strategy that maintains a fixed price range around the current price
contract FarmlyFixedWidthStrategy is FarmlyBaseStrategy {
    /// @notice Width of the price range as a percentage of the current price (denominated by DENOMINATOR)
    uint256 public WIDTH;
    /// @notice Threshold for rebalancing as a percentage (denominated by DENOMINATOR)
    uint256 public THRESHOLD;
    /// @notice Denominator for percentage calculations (100,000 = 100%)
    uint256 public constant DENOMINATOR = 100_000;

    /// @notice Constructor
    /// @param _token0DataFeed Token0 price feed address
    /// @param _token1DataFeed Token1 price feed address
    /// @param _width Width of the price range
    /// @param _threshold Threshold for rebalancing
    constructor(
        address _token0DataFeed,
        address _token1DataFeed,
        uint256 _width,
        uint256 _threshold
    ) FarmlyBaseStrategy(_token0DataFeed, _token1DataFeed) {
        WIDTH = _width;
        THRESHOLD = _threshold;
    }

    /// @notice Checks if position needs rebalancing
    /// @param _lowerPrice Lower price of the current position
    /// @param _upperPrice Upper price of the current position
    /// @return bool True if rebalancing is needed
    function isRebalanceNeeded(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external view override returns (bool) {
        uint256 upperThreshold = FarmlyFullMath.mulDiv(
            _upperPrice,
            THRESHOLD,
            DENOMINATOR
        );
        uint256 lowerThreshold = FarmlyFullMath.mulDiv(
            _lowerPrice,
            THRESHOLD,
            DENOMINATOR
        );

        bool upperRebalanceNeeded = (latestUpperPrice() <
            _upperPrice - upperThreshold) ||
            (latestUpperPrice() > _upperPrice + upperThreshold);

        bool lowerRebalanceNeeded = (latestLowerPrice() <
            _lowerPrice - lowerThreshold) ||
            (latestLowerPrice() > _lowerPrice + lowerThreshold);

        return upperRebalanceNeeded || lowerRebalanceNeeded;
    }

    /// @notice Gets the latest price of token0 in terms of token1
    /// @return uint256 Latest price
    function latestPrice() public view override returns (uint256) {
        return _token0PriceInToken1();
    }

    /// @notice Gets the lower price based on WIDTH
    /// @return uint256 Lower price
    function latestLowerPrice() public view override returns (uint256) {
        return
            FarmlyFullMath.mulDiv(
                _token0PriceInToken1(),
                DENOMINATOR - WIDTH,
                DENOMINATOR
            );
    }

    /// @notice Gets the upper price based on WIDTH
    /// @return uint256 Upper price
    function latestUpperPrice() public view override returns (uint256) {
        return
            FarmlyFullMath.mulDiv(
                _token0PriceInToken1(),
                DENOMINATOR + WIDTH,
                DENOMINATOR
            );
    }
}
