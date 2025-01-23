pragma solidity ^0.8.13;

import {IFarmlyBaseExecutor} from "../interfaces/base/IFarmlyBaseExecutor.sol";

abstract contract FarmlyBaseExecutor is IFarmlyBaseExecutor {
    error NotImplemented();

    /// @inheritdoc IFarmlyBaseExecutor
    function nearestRange(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external view virtual returns (uint256 lowerPrice, uint256 upperPrice) {
        revert NotImplemented();
    }

    /// @inheritdoc IFarmlyBaseExecutor
    function positionAmounts()
        external
        view
        virtual
        returns (uint256 amount0, uint256 amount1)
    {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function positionFees()
        external
        view
        virtual
        returns (uint256 amount0, uint256 amount1)
    {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onRebalance(
        uint256 _lowerPrice,
        uint256 _upperPrice
    )
        external
        virtual
        returns (uint256 amount0Collected, uint256 amount1Collected)
    {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onDeposit(
        uint256 _lowerPrice,
        uint256 _upperPrice
    )
        external
        virtual
        returns (uint256 amount0Collected, uint256 amount1Collected)
    {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onWithdraw(
        uint256 _amount,
        address _to,
        bool _isMinimizeTrading,
        bool _zeroForOne
    )
        external
        virtual
        returns (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        )
    {
        revert NotImplemented();
    }
}
