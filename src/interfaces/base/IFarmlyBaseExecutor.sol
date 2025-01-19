pragma solidity ^0.8.13;

interface IFarmlyBaseExecutor {
    /// @notice Position amounts
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function positionAmounts()
        external
        view
        returns (uint256 amount0, uint256 amount1);
    /// @notice Position fees
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function positionFees()
        external
        view
        returns (uint256 amount0, uint256 amount1);
    /// @notice Called on rebalance
    /// @param _lowerPrice Lower price
    /// @param _upperPrice Upper price
    function onRebalance(uint256 _lowerPrice, uint256 _upperPrice) external;
    /// @notice Called on deposit
    /// @param _lowerPrice Lower price
    /// @param _upperPrice Upper price
    function onDeposit(uint256 _lowerPrice, uint256 _upperPrice) external;
    /// @notice Called on withdraw
    /// @param _amount Amount
    function onWithdraw(uint256 _amount) external;
}
