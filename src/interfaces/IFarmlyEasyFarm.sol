pragma solidity ^0.8.13;

import {IFarmlyUniV3Executor} from "./IFarmlyUniV3Executor.sol";
import {IFarmlyBollingerBands} from "./IFarmlyBollingerBands.sol";

interface IFarmlyEasyFarm {
    // Events
    event Deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 shareAmount,
        uint256 depositUSD
    );

    event Withdraw(uint256 amount0, uint256 amount1, uint256 shareAmount);

    event PerformPosition(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 upperPrice,
        uint256 lowerPrice,
        uint256 sharePrice,
        uint256 timestamp
    );

    // Chainlink Keepers functions
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory);

    function performUpkeep(bytes calldata performData) external;

    // User actions
    function deposit(uint256 amount0, uint256 amount1) external;

    function withdraw(
        uint256 amount,
        bool isMinimizeTrading,
        bool zeroForOne
    ) external;

    // View functions
    function THRESHOLD_DENOMINATOR() external view returns (uint256);

    function farmlyUniV3Executor() external view returns (IFarmlyUniV3Executor);

    function farmlyBollingerBands()
        external
        view
        returns (IFarmlyBollingerBands);

    function token0DataFeed() external view returns (address);

    function token1DataFeed() external view returns (address);

    function latestUpperPrice() external view returns (uint256);

    function latestLowerPrice() external view returns (uint256);

    function latestTimestamp() external view returns (uint256);

    function positionThreshold() external view returns (uint256);

    function performanceFee() external view returns (uint256);

    function feeAddress() external view returns (address);

    function maximumCapacity() external view returns (uint256);

    function sharePrice() external view returns (uint256);

    function totalUSDValue() external view returns (uint256);

    function positionFeesUSD()
        external
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD);

    function positionAmountsUSD()
        external
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD);

    function balancesUSD()
        external
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD);

    // Owner-only functions
    function setPositionThreshold(uint256 _threshold) external;

    function setFeeAddress(address _feeAddress) external;

    function setPerformanceFee(uint256 _fee) external;

    function pause() external;

    function unpause() external;
}
