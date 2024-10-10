pragma solidity ^0.8.13;
import {IFarmlyUniV3Executor} from "./IFarmlyUniV3Executor.sol";

interface IFarmlyPositionManager is IFarmlyUniV3Executor {
    function token0DataFeed() external view returns (address);

    function token1DataFeed() external view returns (address);

    function farmlyBollingerBands() external view returns (address);

    function latestUpperPrice() external view returns (int256);

    function latestLowerPrice() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function positionThreshold() external view returns (int256);

    function performanceFee() external view returns (uint256);

    function feeAddress() external view returns (address);

    function forwarderAddress() external view returns (address);

    function decimals() external view returns (uint8);

    function totalUSDValue() external view returns (uint256);

    function sharePrice() external view returns (uint256);

    function deposit(uint256 amount0, uint256 amount1) external;

    function withdraw(uint256 amount) external;

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;

    function setLatestBollingers(int256 lower, int256 upper) external;

    function emergency_withdraw() external;

    function setForwarder(address _forwarderAddress) external;

    function setPositionThreshold(int256 _threshold) external;

    function setFeeAddress(address _feeAddress) external;

    function setPerformanceFee(uint256 _fee) external;

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
}
