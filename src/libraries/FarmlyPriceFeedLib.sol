pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FarmlyFullMath} from "./FarmlyFullMath.sol";

abstract contract FarmlyPriceFeedLib {
    /// @notice Price precision
    uint256 internal constant PRICE_PRECISION = 1e18;
    /// @notice Token 0 data feed
    AggregatorV3Interface public token0DataFeed;
    /// @notice Token 1 data feed
    AggregatorV3Interface public token1DataFeed;

    /// @notice Constructor
    /// @param _token0DataFeed The Chainlink price feed for token0
    /// @param _token1DataFeed The Chainlink price feed for token1
    constructor(address _token0DataFeed, address _token1DataFeed) {
        token0DataFeed = AggregatorV3Interface(_token0DataFeed);
        token1DataFeed = AggregatorV3Interface(_token1DataFeed);
    }

    /// @notice Get the price of token0 in terms of token1
    /// @return price The price of token0 denominated in token1
    function _token0PriceInToken1() internal view returns (uint256 price) {
        uint256 token0Price = _token0Price();
        uint256 token1Price = _token1Price();

        price = FarmlyFullMath.mulDiv(
            token0Price,
            PRICE_PRECISION,
            token1Price
        );
    }

    /// @notice Get the price of token1 in terms of token0
    /// @return price The price of token1 denominated in token0
    function _token1PriceInToken0() internal view returns (uint256 price) {
        uint256 token0Price = _token0Price();
        uint256 token1Price = _token1Price();

        price = FarmlyFullMath.mulDiv(
            token1Price,
            PRICE_PRECISION,
            token0Price
        );
    }

    /// @notice Get the price of token0
    /// @return token0Price The price of token0
    function _token0Price() internal view returns (uint256) {
        (, int256 token0Answer, , , ) = token0DataFeed.latestRoundData();
        return
            FarmlyFullMath.mulDiv(
                uint256(token0Answer),
                PRICE_PRECISION,
                10 ** token0DataFeed.decimals()
            );
    }

    /// @notice Get the price of token1
    /// @return token1Price The price of token1
    function _token1Price() internal view returns (uint256) {
        (, int256 token1Answer, , , ) = token1DataFeed.latestRoundData();
        return
            FarmlyFullMath.mulDiv(
                uint256(token1Answer),
                PRICE_PRECISION,
                10 ** token1DataFeed.decimals()
            );
    }

    /// @notice Get the prices of the tokens
    /// @return token0Price The price of token0
    /// @return token1Price The price of token1
    function _tokenPrices()
        internal
        view
        returns (uint256 token0Price, uint256 token1Price)
    {
        token0Price = _token0Price();
        token1Price = _token1Price();
    }
}
