pragma solidity ^0.8.13;

import {IFarmlyBaseStrategy} from "../interfaces/base/IFarmlyBaseStrategy.sol";
import {IUniV3Reader} from "../interfaces/IUniV3Reader.sol";

abstract contract FarmlyBaseStrategy is IFarmlyBaseStrategy {
    /// @inheritdoc IFarmlyBaseStrategy
    uint256 public override latestLowerPrice;
    /// @inheritdoc IFarmlyBaseStrategy
    uint256 public override latestUpperPrice;
    /// @inheritdoc IFarmlyBaseStrategy
    uint256 public override latestTimestamp;
    /// @inheritdoc IFarmlyBaseStrategy
    IUniV3Reader public override uniV3Reader =
        IUniV3Reader(0x0000000000000000000000000000000000000000);
    /// @inheritdoc IFarmlyBaseStrategy
    address public override uniswapPool =
        0x0000000000000000000000000000000000000000;

    /// @notice NotImplemented error
    error NotImplemented();

    /// @inheritdoc IFarmlyBaseStrategy
    function isRebalanceNeeded(
        uint256 _upperPrice,
        uint256 _lowerPrice
    ) external view virtual returns (bool) {
        revert NotImplemented();
    }

    /*
    /// @inheritdoc IFarmlyBaseStrategy
    function beforeRebalance() external virtual {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseStrategy
    function afterRebalance() external virtual {
        revert NotImplemented();
    }

    /// @inheritdoc IFarmlyBaseStrategy
    function beforeDeposit(uint256 _amount) external virtual {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseStrategy
    function afterDeposit(uint256 _amount) external virtual {
        revert NotImplemented();
    }

    /// @inheritdoc IFarmlyBaseStrategy
    function beforeWithdraw(uint256 _amount) external virtual {
        revert NotImplemented();
    }
    /// @inheritdoc IFarmlyBaseStrategy
    function afterWithdraw(uint256 _amount) external virtual {
        revert NotImplemented();
    }
    */
}
