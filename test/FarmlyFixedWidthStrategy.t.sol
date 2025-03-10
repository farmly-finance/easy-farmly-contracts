pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FarmlyFixedWidthStrategy} from "../src/strategies/FarmlyFixedWidthStrategy.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {console} from "forge-std/console.sol";

contract FarmlyFixedWidthStrategyTest is Test {
    FarmlyFixedWidthStrategy public strategy;
    MockPriceFeed public token0PriceFeed;
    MockPriceFeed public token1PriceFeed;

    function setUp() public {
        vm.warp(100 hours);
        token0PriceFeed = new MockPriceFeed(1000 * 1e8);
        token1PriceFeed = new MockPriceFeed(1 * 1e8);
        uint256 WIDTH = 10_000;
        uint256 THRESHOLD = 500;

        strategy = new FarmlyFixedWidthStrategy(
            address(token0PriceFeed),
            address(token1PriceFeed),
            WIDTH,
            THRESHOLD
        );
    }

    function test_constructor() public {
        assertEq(strategy.WIDTH(), 10_000);
        assertEq(strategy.THRESHOLD(), 500);
    }

    function test_latestPrice() public {
        assertEq(strategy.latestPrice(), 1000000000000000000000);
    }

    function test_latestLowerPrice() public {
        assertEq(strategy.latestLowerPrice(), 900000000000000000000);
    }

    function test_latestUpperPrice() public {
        assertEq(strategy.latestUpperPrice(), 1100000000000000000000);
    }

    function test_isRebalanceNeeded() public {
        uint256 price = 1000e18;
        uint256 lowerPrice = (price * 9) / 10;
        uint256 upperPrice = (price * 11) / 10;

        token0PriceFeed.setPrice(int256((lowerPrice * 1e8) / 1e18));
        bool isRebalanceNeeded = strategy.isRebalanceNeeded(
            lowerPrice,
            upperPrice
        );
        assert(isRebalanceNeeded);

        token0PriceFeed.setPrice(int256((upperPrice * 1e8) / 1e18));
        isRebalanceNeeded = strategy.isRebalanceNeeded(lowerPrice, upperPrice);
        assert(isRebalanceNeeded);

        token0PriceFeed.setPrice(int256((lowerPrice * 1e8) / 1e18) - 1);
        isRebalanceNeeded = strategy.isRebalanceNeeded(lowerPrice, upperPrice);
        assert(isRebalanceNeeded);

        token0PriceFeed.setPrice(int256((price * 1e8) / 1e18));
        isRebalanceNeeded = strategy.isRebalanceNeeded(lowerPrice, upperPrice);
        assert(!isRebalanceNeeded);

        token0PriceFeed.setPrice(int256((upperPrice * 1e8) / 1e18) + 1);

        isRebalanceNeeded = strategy.isRebalanceNeeded(lowerPrice, upperPrice);
        assert(isRebalanceNeeded);
    }
}
