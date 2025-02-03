pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IFarmlyBaseStrategy {
    /// @notice Latest price
    function latestPrice() external view returns (uint256);
    /// @notice Latest lower price
    function latestLowerPrice() external view returns (uint256);
    /// @notice Latest upper price
    function latestUpperPrice() external view returns (uint256);
    /// @notice Latest timestamp
    function latestTimestamp() external view returns (uint256);
    /// @notice Is rebalance needed
    function isRebalanceNeeded(uint256 _lowerPrice, uint256 _upperPrice) external view returns (bool);
}
