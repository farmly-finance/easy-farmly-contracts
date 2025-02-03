pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FarmlyBollingerBandsStrategyHelper} from "./helpers/FarmlyBollingerBandsStrategyHelper.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {console} from "forge-std/console.sol";

contract FarmlyBollingerBandsStrategyTest is Test {
    FarmlyBollingerBandsStrategyHelper public strategy;
    MockPriceFeed public token0PriceFeed;
    MockPriceFeed public token1PriceFeed;

    function setUp() public {
        vm.warp(100 hours);
        token0PriceFeed = new MockPriceFeed(1000 * 1e8);
        token1PriceFeed = new MockPriceFeed(1 * 1e8);
        uint16 ma = 20;
        uint16 std = 2;
        uint256 period = 1 hours;
        uint256 rebalanceThreshold = 500;

        strategy = new FarmlyBollingerBandsStrategyHelper(
            address(token0PriceFeed), address(token1PriceFeed), ma, std, period, rebalanceThreshold
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

    function test_setLatestPrice() public {
        strategy.exposed_setLatestPrice();
        assertEq(strategy.latestPrice(), 1000 * 1e18);
    }

    function test_isUpkeepNeeded_false() public {
        vm.warp(101 hours - 1 seconds);
        bool upkeepNeeded = strategy.exposed_isUpkeepNeeded();
        assertEq(upkeepNeeded, false);
    }

    function test_isUpkeepNeeded_true() public {
        vm.warp(101 hours);
        bool upkeepNeeded = strategy.exposed_isUpkeepNeeded();
        assertEq(upkeepNeeded, true);
        vm.warp(101 hours + 1 seconds);
        upkeepNeeded = strategy.exposed_isUpkeepNeeded();
        assertEq(upkeepNeeded, true);
    }

    function test_calculateSMA_pricesLengthLessThanMa() public {
        uint256 sma = strategy.exposed_calculateSMA();
        assertEq(sma, 0);
        vm.warp(101 hours);
        strategy.performUpkeep("");
        sma = strategy.exposed_calculateSMA();
        assertEq(sma, 0);
    }

    function test_calculateSMA_pricesLengthEqualToMa() public {
        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        uint256 sma = strategy.exposed_calculateSMA();
        assertEq(sma, 1000.95 * 1e18);
    }

    function test_calculateSMA_pricesLengthGreaterThanMa() public {
        for (uint256 i = 0; i < 21; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        uint256 sma = strategy.exposed_calculateSMA();
        assertEq(sma, 1001.05 * 1e18);
    }

    function test_calculateStdDev_pricesLengthLessThanMa() public {
        uint256 sma = strategy.exposed_calculateSMA();
        uint256 stdDev = strategy.exposed_calculateStdDev(sma);
        assertEq(stdDev, 0);
        vm.warp(101 hours);
        strategy.performUpkeep("");
        sma = strategy.exposed_calculateSMA();
        stdDev = strategy.exposed_calculateStdDev(sma);
        assertEq(stdDev, 0);
    }

    function test_calculateStdDev_pricesLengthEqualToMa() public {
        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        uint256 sma = strategy.exposed_calculateSMA();
        uint256 stdDev = strategy.exposed_calculateStdDev(sma);
        assertEq(stdDev, 0.576628129733539794 * 1e18);
    }

    function test_calculateStdDev_pricesLengthGreaterThanMa() public {
        for (uint256 i = 0; i < 21; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        uint256 sma = strategy.exposed_calculateSMA();
        uint256 stdDev = strategy.exposed_calculateStdDev(sma);
        assertEq(stdDev, 0.576628129733539794 * 1e18);
    }

    function test_calculateBollingerBands_pricesLengthLessThanMa() public {
        (uint256 upperBand, uint256 sma, uint256 lowerBand) = strategy.exposed_calculateBollingerBands();
        assertEq(upperBand, 0);
        assertEq(sma, 0);
        assertEq(lowerBand, 0);
        vm.warp(101 hours);
        strategy.performUpkeep("");
        (upperBand, sma, lowerBand) = strategy.exposed_calculateBollingerBands();
        assertEq(upperBand, 0);
        assertEq(sma, 0);
        assertEq(lowerBand, 0);
    }

    function test_calculateBollingerBands_pricesLengthEqualToMa() public {
        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        (uint256 upperBand, uint256 sma, uint256 lowerBand) = strategy.exposed_calculateBollingerBands();
        assertEq(upperBand, 1002.103256259467079588 * 1e18);
        assertEq(sma, 1000.95 * 1e18);
        assertEq(lowerBand, 999.796743740532920412 * 1e18);
    }

    function test_calculateBollingerBands_pricesLengthGreaterThanMa() public {
        for (uint256 i = 0; i < 21; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        (uint256 upperBand, uint256 sma, uint256 lowerBand) = strategy.exposed_calculateBollingerBands();
        assertEq(upperBand, 1002.203256259467079588 * 1e18);
        assertEq(sma, 1001.05 * 1e18);
        assertEq(lowerBand, 999.896743740532920412 * 1e18);
    }

    function test_updateBands_pricesLengthLessThanMa() public {
        strategy.exposed_updateBands();
        assertEq(strategy.latestUpperPrice(), 0);
        assertEq(strategy.latestLowerPrice(), 0);
        assertEq(strategy.latestMidPrice(), 0);
        vm.warp(101 hours);
        strategy.performUpkeep("");
        strategy.exposed_updateBands();
        assertEq(strategy.latestUpperPrice(), 0);
        assertEq(strategy.latestLowerPrice(), 0);
        assertEq(strategy.latestMidPrice(), 0);
    }

    function test_updateBands_pricesLengthEqualToMa() public {
        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        strategy.exposed_updateBands();
        assertEq(strategy.latestUpperPrice(), 1002.103256259467079588 * 1e18);
        assertEq(strategy.latestLowerPrice(), 999.796743740532920412 * 1e18);
        assertEq(strategy.latestMidPrice(), 1000.95 * 1e18);
    }

    function test_updateBands_pricesLengthGreaterThanMa() public {
        for (uint256 i = 0; i < 21; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        strategy.exposed_updateBands();
        assertEq(strategy.latestUpperPrice(), 1002.203256259467079588 * 1e18);
        assertEq(strategy.latestLowerPrice(), 999.896743740532920412 * 1e18);
        assertEq(strategy.latestMidPrice(), 1001.05 * 1e18);
    }

    function test_checkUpkeep_false() public {
        vm.warp(101 hours - 1 seconds);
        (bool upkeepNeeded,) = strategy.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function test_checkUpkeep_true() public {
        vm.warp(101 hours);
        (bool upkeepNeeded,) = strategy.checkUpkeep("");
        assertEq(upkeepNeeded, true);
        vm.warp(101 hours + 1 seconds);
        (upkeepNeeded,) = strategy.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    function test_performUpkeep_notUpkeepNeeded() public {
        (bool upkeepNeeded,) = strategy.checkUpkeep("");
        vm.expectRevert();
        strategy.performUpkeep("");
    }

    function test_performUpkeep_upkeepNeeded_pricesLengthLessThanMa() public {
        vm.warp(101 hours);
        strategy.performUpkeep("");
        assertEq(strategy.pricesLength(), 1);
        assertEq(strategy.latestTimestamp(), 101 hours);
        assertEq(strategy.nextPeriodStartTimestamp(), 102 hours);
        assertEq(strategy.latestPrice(), 1000 * 1e18);
        assertEq(strategy.latestLowerPrice(), 0);
        assertEq(strategy.latestUpperPrice(), 0);
        assertEq(strategy.latestMidPrice(), 0);
        assertEq(strategy.prices(0), 1000 * 1e18);
    }

    function test_performUpkeep_upkeepNeeded_pricesLengthEqualToMa() public {
        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        assertEq(strategy.pricesLength(), 20);
        assertEq(strategy.latestTimestamp(), 100 hours + 20 hours);
        assertEq(strategy.nextPeriodStartTimestamp(), 100 hours + 20 hours + 1 hours);
        assertEq(strategy.latestPrice(), 1001.9e18);
        assertEq(strategy.latestLowerPrice(), 999.796743740532920412 * 1e18);
        assertEq(strategy.latestUpperPrice(), 1002.103256259467079588 * 1e18);
        assertEq(strategy.latestMidPrice(), 1000.95 * 1e18);
        assertEq(strategy.prices(0), 1000 * 1e18);
        assertEq(strategy.prices(1), 1000.1e18);
        assertEq(strategy.prices(19), 1001.9e18);
    }

    function test_performUpkeep_upkeepNeeded_pricesLengthGreaterThanMa() public {
        for (uint256 i = 0; i < 21; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        assertEq(strategy.pricesLength(), 21);
        assertEq(strategy.latestTimestamp(), 100 hours + 21 hours);
        assertEq(strategy.nextPeriodStartTimestamp(), 100 hours + 21 hours + 1 hours);
        assertEq(strategy.latestPrice(), 1002.0e18);
        assertEq(strategy.latestLowerPrice(), 999.896743740532920412 * 1e18);
        assertEq(strategy.latestUpperPrice(), 1002.203256259467079588 * 1e18);
        assertEq(strategy.latestMidPrice(), 1001.05 * 1e18);
        assertEq(strategy.prices(0), 1000 * 1e18);
        assertEq(strategy.prices(1), 1000.1e18);
        assertEq(strategy.prices(20), 1002.0e18);
    }

    function test_isRebalanceNeeded() public {
        uint256 lowerPrice = 100;
        uint256 upperPrice = 100;
        bool isRebalanceNeeded = strategy.isRebalanceNeeded(lowerPrice, upperPrice);

        assert(isRebalanceNeeded);
    }
}
