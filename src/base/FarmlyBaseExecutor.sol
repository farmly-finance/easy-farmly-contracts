pragma solidity ^0.8.13;

import {IFarmlyBaseExecutor} from "../interfaces/base/IFarmlyBaseExecutor.sol";

abstract contract FarmlyBaseExecutor is IFarmlyBaseExecutor {
    error NotImplemented();

    /// @inheritdoc IFarmlyBaseExecutor
    function onRebalance() external virtual {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onDeposit(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external virtual {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseExecutor
    function onWithdraw(uint256 _amount) external virtual {
        revert NotImplemented();
    }
}
