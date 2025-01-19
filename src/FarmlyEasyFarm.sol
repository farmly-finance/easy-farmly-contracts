pragma solidity ^0.8.13;

import {IFarmlyEasyFarm} from "./interfaces/IFarmlyEasyFarm.sol";
import {IFarmlyBaseStrategy} from "./interfaces/IFarmlyBaseStrategy.sol";
import {IFarmlyBaseExecutor} from "./interfaces/IFarmlyBaseExecutor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FarmlyEasyFarm is IFarmlyEasyFarm, ERC20 {
    /// @inheritdoc IFarmlyEasyFarm
    IFarmlyBaseStrategy public override strategy;
    /// @inheritdoc IFarmlyEasyFarm
    IFarmlyBaseExecutor public override executor;

    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestUpperPrice;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestLowerPrice;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestTimestamp;
    /// @inheritdoc IFarmlyEasyFarm
    AggregatorV3Interface public override token0DataFeed;
    /// @inheritdoc IFarmlyEasyFarm
    AggregatorV3Interface public override token1DataFeed;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override positionThreshold;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override performanceFee;
    /// @inheritdoc IFarmlyEasyFarm
    address public override feeAddress;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override maximumCapacity;
    /// @inheritdoc IFarmlyEasyFarm
    IERC20 public override token0;
    /// @inheritdoc IFarmlyEasyFarm
    IERC20 public override token1;

    /// @notice Constructor
    /// @param _shareTokenName Name of the share token
    /// @param _shareTokenSymbol Symbol of the share token
    /// @param _maximumCapacity Maximum capacity of the farm
    /// @param _strategy Strategy of the farm
    /// @param _executor Executor of the farm
    constructor(
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        uint256 _maximumCapacity,
        IFarmlyBaseStrategy _strategy,
        IFarmlyBaseExecutor _executor
    ) ERC20(_shareTokenName, _shareTokenSymbol) {
        strategy = _strategy;

        executor = _executor;

        maximumCapacity = _maximumCapacity;
    }
}
