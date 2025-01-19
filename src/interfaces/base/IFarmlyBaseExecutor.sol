pragma solidity ^0.8.13;

interface IFarmlyBaseExecutor {
    /// @notice Called on rebalance
    function onRebalance() external;
    /// @notice Called on deposit
    /// @param _lowerPrice Lower price
    /// @param _upperPrice Upper price
    function onDeposit(uint256 _lowerPrice, uint256 _upperPrice) external;
    /// @notice Called on withdraw
    /// @param _amount Amount
    function onWithdraw(uint256 _amount) external;
}
