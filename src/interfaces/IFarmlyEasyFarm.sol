pragma solidity ^0.8.13;

import {IFarmlyBaseStrategy} from "./base/IFarmlyBaseStrategy.sol";
import {IFarmlyBaseExecutor} from "./base/IFarmlyBaseExecutor.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFarmlyPriceFeedLib} from "./IFarmlyPriceFeedLib.sol";

interface IFarmlyEasyFarm is IFarmlyPriceFeedLib {
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
    /// @notice Performance fee
    function performanceFee() external view returns (uint256);
    /// @notice Fee address
    function feeAddress() external view returns (address);
    /// @notice Minimum deposit USD
    function minimumDepositUSD() external view returns (uint256);
    /// @notice Maximum capacity
    function maximumCapacity() external view returns (uint256);
    /// @notice Token 0
    function token0() external view returns (address);
    /// @notice Token 1
    function token1() external view returns (address);
    /// @notice Token 0 decimals
    function token0Decimals() external view returns (uint8);
    /// @notice Token 1 decimals
    function token1Decimals() external view returns (uint8);
    /// @notice Total USD value of easy farm
    function totalUSDValue() external view returns (uint256);
    /// @notice Position fees USD
    function positionFeesUSD()
        external
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD);
    /// @notice Position amounts USD
    function positionAmountsUSD()
        external
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD);

    /// @notice Deposit
    /// @param _amount0 Amount of token 0
    /// @param _amount1 Amount of token 1
    /// @param _minShareAmount Minimum share amount
    function deposit(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _minShareAmount
    ) external;
    /// @notice Withdraw
    /// @param _amount Amount of shares
    /// @param _minUSDValue Minimum USD value
    function withdraw(uint256 _amount, uint256 _minUSDValue) external;

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
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 timestamp
    );

    /// @notice Set performance fee
    /// @param _performanceFee Performance fee
    function setPerformanceFee(uint256 _performanceFee) external;
    /// @notice Set fee address
    /// @param _feeAddress Fee address
    function setFeeAddress(address _feeAddress) external;
    /// @notice Set maximum capacity
    /// @param _maximumCapacity Maximum capacity
    function setMaximumCapacity(uint256 _maximumCapacity) external;
    /// @notice Set minimum deposit USD
    /// @param _minimumDepositUSD Minimum deposit USD
    function setMinimumDepositUSD(uint256 _minimumDepositUSD) external;
}
