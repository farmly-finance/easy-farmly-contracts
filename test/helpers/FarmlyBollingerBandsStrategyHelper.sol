pragma solidity ^0.8.13;

import {FarmlyBollingerBandsStrategy} from "../../src/strategies/FarmlyBollingerBandsStrategy.sol";

contract FarmlyBollingerBandsStrategyHelper is FarmlyBollingerBandsStrategy {
    constructor(
        address token0PriceFeed,
        address token1PriceFeed,
        uint16 ma,
        uint16 std,
        uint256 period,
        uint256 rebalanceThreshold
    ) FarmlyBollingerBandsStrategy(token0PriceFeed, token1PriceFeed, ma, std, period, rebalanceThreshold) {}

    function exposed_setLatestPrice() external {
        _setLatestPrice();
    }

    function exposed_isUpkeepNeeded() external view returns (bool) {
        return isUpkeepNeeded();
    }

    function exposed_updateBands() external {
        updateBands();
    }

    function exposed_calculateSMA() external view returns (uint256) {
        return calculateSMA();
    }

    function exposed_calculateStdDev(uint256 sma) external view returns (uint256) {
        return calculateStdDev(sma);
    }

    function exposed_calculateBollingerBands() external view returns (uint256, uint256, uint256) {
        return calculateBollingerBands();
    }
}
