pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FarmlyBollingerBandsStrategy} from "../src/strategies/FarmlyBollingerBandsStrategy.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {console} from "forge-std/console.sol";
contract FarmlyBollingerBandsStrategyTest is Test {
    FarmlyBollingerBandsStrategy public strategy;

    function setUp() public {
        vm.warp(100 hours);
        MockPriceFeed token0PriceFeed = new MockPriceFeed(1000 * 1e8);
        MockPriceFeed token1PriceFeed = new MockPriceFeed(1 * 1e8);
        uint16 ma = 20;
        uint16 std = 2;
        uint256 period = 1 hours;
        uint256 rebalanceThreshold = 500;

        strategy = new FarmlyBollingerBandsStrategy(
            address(token0PriceFeed),
            address(token1PriceFeed),
            ma,
            std,
            period,
            rebalanceThreshold
        );
    }

    function test_constructor() public {
        assertEq(strategy.MA(), 20);
        assertEq(strategy.STD(), 2);
        assertEq(strategy.PERIOD(), 1 hours);
        assertEq(strategy.rebalanceThreshold(), 500);
        assertEq(strategy.latestTimestamp(), 100 hours);
        assertEq(strategy.nextPeriodStartTimestamp(), 101 hours);
    }

    function test_isRebalanceNeeded() public {
        uint256 lowerPrice = 100;
        uint256 upperPrice = 100;
        bool isRebalanceNeeded = strategy.isRebalanceNeeded(
            lowerPrice,
            upperPrice
        );
        assert(isRebalanceNeeded);
    }
}
