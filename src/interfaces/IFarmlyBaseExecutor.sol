pragma solidity ^0.8.13;

interface IFarmlyBaseExecutor {
    /// @notice Called on rebalance
    function onRebalance() external;
    /// @notice Called on deposit
    function onDeposit(uint256 _amount) external;
    /// @notice Called on withdraw
    function onWithdraw(uint256 _amount) external;
}
