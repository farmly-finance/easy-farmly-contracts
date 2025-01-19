pragma solidity ^0.8.13;

import {IUniV3Reader} from "../IUniV3Reader.sol";
interface IFarmlyBaseStrategy {
    /*
    /// @notice Called before rebalance
    function beforeRebalance() external;
    /// @notice Called after rebalance
    function afterRebalance() external;

    /// @notice Called before deposit
    function beforeDeposit(uint256 _amount) external;
    /// @notice Called after deposit
    function afterDeposit(uint256 _amount) external;

    /// @notice Called before withdraw
    function beforeWithdraw(uint256 _amount) external;
    /// @notice Called after withdraw
    function afterWithdraw(uint256 _amount) external;
    */

    /// @notice Latest lower price
    function latestLowerPrice() external view returns (uint256);
    /// @notice Latest upper price
    function latestUpperPrice() external view returns (uint256);
    /// @notice Latest timestamp
    function latestTimestamp() external view returns (uint256);
    /// @notice UniV3 reader
    function uniV3Reader() external view returns (IUniV3Reader);
    /// @notice Uniswap pool
    function uniswapPool() external view returns (address);
    /// @notice Is rebalance needed
    function isRebalanceNeeded(
        uint256 _upperPrice,
        uint256 _lowerPrice
    ) external view returns (bool);
}
