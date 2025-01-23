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
    /// @return amount0Collected Amount 0 collected
    /// @return amount1Collected Amount 1 collected
    function onRebalance(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external returns (uint256 amount0Collected, uint256 amount1Collected);
    /// @notice Called on deposit
    /// @param _lowerPrice Lower price
    /// @param _upperPrice Upper price
    /// @return amount0Collected Amount 0 collected
    /// @return amount1Collected Amount 1 collected
    function onDeposit(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external returns (uint256 amount0Collected, uint256 amount1Collected);
    /// @notice Called on withdraw
    /// @param _amount Amount
    /// @param _to To
    /// @param _isMinimizeTrading Minimize trading
    /// @param _zeroForOne Zero for one
    /// @return amount0Collected Amount 0 collected
    /// @return amount1Collected Amount 1 collected
    /// @return amount0 Amount 0
    /// @return amount1 Amount 1
    function onWithdraw(
        uint256 _amount,
        address _to,
        bool _isMinimizeTrading,
        bool _zeroForOne
    )
        external
        returns (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        );
}
