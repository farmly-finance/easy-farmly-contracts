pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IFarmlyPriceFeedLib {
    /// @notice Token 0 data feed
    function token0DataFeed() external view returns (AggregatorV3Interface);
    /// @notice Token 1 data feed
    function token1DataFeed() external view returns (AggregatorV3Interface);
}
