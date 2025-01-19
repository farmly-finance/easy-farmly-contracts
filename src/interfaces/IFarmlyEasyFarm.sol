pragma solidity ^0.8.13;

import {IFarmlyBaseStrategy} from "./IFarmlyBaseStrategy.sol";
import {IFarmlyBaseExecutor} from "./IFarmlyBaseExecutor.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IFarmlyEasyFarm {
    /// @notice Strategy address
    function strategy() external view returns (IFarmlyBaseStrategy);
    /// @notice Executor address
    function executor() external view returns (IFarmlyBaseExecutor);
    /// @notice Latest upper price
    function latestUpperPrice() external view returns (uint256);
    /// @notice Latest lower price
    function latestLowerPrice() external view returns (uint256);
    /// @notice Latest timestamp
    function latestTimestamp() external view returns (uint256);
    /// @notice Token 0 data feed
    function token0DataFeed() external view returns (AggregatorV3Interface);
    /// @notice Token 1 data feed
    function token1DataFeed() external view returns (AggregatorV3Interface);
    /// @notice Position threshold
    function positionThreshold() external view returns (uint256);
    /// @notice Performance fee
    function performanceFee() external view returns (uint256);
    /// @notice Fee address
    function feeAddress() external view returns (address);
    /// @notice Maximum capacity
    function maximumCapacity() external view returns (uint256);
    /// @notice Token 0
    function token0() external view returns (IERC20);
    /// @notice Token 1
    function token1() external view returns (IERC20);
    /// @notice Deposit event
    event Deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 shareAmount,
        uint256 depositUSD
    );
    /// @notice Withdraw event
    event Withdraw(
        uint256 amount0,
        uint256 amount1,
        uint256 shareAmount,
        uint256 withdrawUSD
    );
    /// @notice Perform position event
    event PerformPosition(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 upperPrice,
        uint256 lowerPrice,
        uint256 sharePrice,
        uint256 timestamp
    );
}
