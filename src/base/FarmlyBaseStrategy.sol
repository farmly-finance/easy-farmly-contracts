pragma solidity ^0.8.13;

import {IFarmlyBaseStrategy} from "../interfaces/base/IFarmlyBaseStrategy.sol";
import {FarmlyPriceFeedLib} from "../libraries/FarmlyPriceFeedLib.sol";

abstract contract FarmlyBaseStrategy is
    IFarmlyBaseStrategy,
    FarmlyPriceFeedLib
{
    /// @notice Latest price
    uint256 internal _latestPrice;
    /// @notice Latest lower price
    uint256 internal _latestLowerPrice;
    /// @notice Latest upper price
    uint256 internal _latestUpperPrice;
    /// @inheritdoc IFarmlyBaseStrategy
    uint256 public override latestTimestamp;

    /// @notice NotImplemented error
    error NotImplemented();

    /// @notice Constructor
    /// @param _token0DataFeed Token 0 data feed
    /// @param _token1DataFeed Token 1 data feed
    constructor(
        address _token0DataFeed,
        address _token1DataFeed
    ) FarmlyPriceFeedLib(_token0DataFeed, _token1DataFeed) {}

    /// @inheritdoc IFarmlyBaseStrategy
    function isRebalanceNeeded(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external view virtual returns (bool) {
        revert NotImplemented();
    }

    /// @inheritdoc IFarmlyBaseStrategy
    function latestPrice() external view virtual override returns (uint256) {
        return _latestPrice;
    }

    /// @inheritdoc IFarmlyBaseStrategy
    function latestLowerPrice()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _latestLowerPrice;
    }
    /// @inheritdoc IFarmlyBaseStrategy
    function latestUpperPrice()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _latestUpperPrice;
    }

    /// @notice Set price
    function _setLatestPrice() internal {
        _latestPrice = _token0PriceInToken1();
    }
}
