pragma solidity ^0.8.13;

import {UniswapV3Fixture} from "./fixtures/UniswapV3Fixture.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";
import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";
import {FarmlyEasyFarmHelper} from "./helpers/FarmlyEasyFarmHelper.sol";
import {FarmlyBollingerBandsStrategy} from "../src/strategies/FarmlyBollingerBandsStrategy.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {FarmlyFullMath} from "../src/libraries/FarmlyFullMath.sol";
import {FarmlyTickLib} from "../src/libraries/FarmlyTickLib.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
contract FarmlyEasyFarmTest is Test, UniswapV3Fixture {
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address john = makeAddr("John");
    FarmlyBollingerBandsStrategy strategy;
    FarmlyUniV3Executor executor;
    FarmlyEasyFarmHelper easyFarm;
    MockPriceFeed token0PriceFeed;
    MockPriceFeed token1PriceFeed;

    constructor() UniswapV3Fixture() {}

    function setUp() public {
        vm.warp(100 hours);

        token0PriceFeed = new MockPriceFeed(1000 * 1e8);
        token1PriceFeed = new MockPriceFeed(1 * 1e8);
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

        for (uint256 i = 0; i < 20; i++) {
            vm.warp(block.timestamp + 1 hours);
            token0PriceFeed.setPrice(int256(1000e8 + i * 0.1e8));
            strategy.performUpkeep("");
        }

        executor = new FarmlyUniV3Executor(
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            address(token0),
            address(token1),
            poolFee
        );

        easyFarm = new FarmlyEasyFarmHelper(
            "Farmly Easy Farm Test",
            "FARMLY_TEST",
            address(strategy),
            address(executor),
            address(token0),
            address(token1),
            address(token0PriceFeed),
            address(token1PriceFeed)
        );

        executor.transferOwnership(address(easyFarm));

        easyFarm.setPerformanceFee(20_000);
        easyFarm.setFeeAddress(bob);
        easyFarm.setMaximumCapacity(10_000e18);
        easyFarm.setMinimumDepositUSD(5e18);

        deal(address(token0), alice, 0);
        deal(address(token1), alice, 0);
        deal(address(token0), bob, 0);
        deal(address(token1), bob, 0);
    }

    function test_constructor() public {
        assertEq(easyFarm.name(), "Farmly Easy Farm Test");
        assertEq(easyFarm.symbol(), "FARMLY_TEST");
        assertEq(address(easyFarm.strategy()), address(strategy));
        assertEq(address(easyFarm.executor()), address(executor));
        assertEq(easyFarm.token0(), address(token0));
        assertEq(easyFarm.token1(), address(token1));
        assertEq(easyFarm.token0Decimals(), 18);
        assertEq(easyFarm.token1Decimals(), 18);
        assertEq(easyFarm.latestLowerPrice(), 999899349108443648671);
        assertEq(easyFarm.latestUpperPrice(), 1001901048755793706293);
    }

    function test_setPerformanceFee() public {
        easyFarm.setPerformanceFee(20_000);
        assertEq(easyFarm.performanceFee(), 20_000);
    }

    function test_setPerformanceFee_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.setPerformanceFee(100);
        vm.stopPrank();
    }

    function test_setFeeAddress() public {
        easyFarm.setFeeAddress(alice);
        assertEq(easyFarm.feeAddress(), alice);

        vm.expectRevert();
        easyFarm.setFeeAddress(address(0));
    }

    function test_setFeeAddress_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.setFeeAddress(alice);
        vm.stopPrank();
    }

    function test_setMaximumCapacity() public {
        easyFarm.setMaximumCapacity(1000);
        assertEq(easyFarm.maximumCapacity(), 1000);
    }

    function test_setMaximumCapacity_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.setMaximumCapacity(1000);
        vm.stopPrank();
    }

    function test_setMinimumDepositUSD() public {
        easyFarm.setMinimumDepositUSD(1000);
        assertEq(easyFarm.minimumDepositUSD(), 1000);
    }

    function test_setMinimumDepositUSD_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.setMinimumDepositUSD(1000);
        vm.stopPrank();
    }

    function test_pause() public {
        vm.expectRevert();
        easyFarm.unpause();

        easyFarm.pause();
        assertEq(easyFarm.paused(), true);
    }

    function test_pause_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.pause();
        vm.stopPrank();
    }

    function test_unpause() public {
        vm.expectRevert();
        easyFarm.unpause();

        easyFarm.pause();
        easyFarm.unpause();
        assertEq(easyFarm.paused(), false);
    }

    function test_unpause_notOwner_revert() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        easyFarm.unpause();
        vm.stopPrank();
    }

    function test_mintPerformanceFee_zeroAmount_noMint() public {
        easyFarm.exposed_mintPerformanceFee(0, 0, 0, 0);

        assertEq(easyFarm.totalSupply(), 0);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 0);
    }

    function test_mintPerformanceFee_zeroSupplyToken0_mint() public {
        easyFarm.exposed_mintPerformanceFee(0.1e18, 0, 0, 0);

        assertEq(easyFarm.totalSupply(), 20.038e18);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 20.038e18);
    }

    function test_mintPerformanceFee_zeroSupplyToken1_mint() public {
        easyFarm.exposed_mintPerformanceFee(0, 100e18, 0, 0);

        assertEq(easyFarm.totalSupply(), 20e18);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 20e18);
    }

    function test_mintPerformanceFee_zeroSupplyBoth_mint() public {
        easyFarm.exposed_mintPerformanceFee(0.1e18, 100e18, 0, 0);

        assertEq(easyFarm.totalSupply(), 40.038e18);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 40.038e18);
    }

    function test_mintPerformanceFee_token0_mint() public {
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(0, 100e18, 0);
        vm.stopPrank();

        uint256 totalSupplyBefore = easyFarm.totalSupply();

        easyFarm.exposed_mintPerformanceFee(
            0.1e18,
            0,
            totalSupplyBefore,
            easyFarm.totalUSDValue()
        );

        uint256 totalSupplyAfter = easyFarm.totalSupply();

        assertEq(totalSupplyAfter, 120037800715936136190);
        assertEq(
            easyFarm.balanceOf(easyFarm.feeAddress()),
            totalSupplyAfter - totalSupplyBefore
        );
    }

    function test_mintPerformanceFee_token1_mint() public {
        token0.mint(alice, 1e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        easyFarm.deposit(1e18, 0, 0);
        vm.stopPrank();

        uint256 totalSupplyBefore = easyFarm.totalSupply();

        easyFarm.exposed_mintPerformanceFee(
            0.1e18,
            0,
            totalSupplyBefore,
            easyFarm.totalUSDValue()
        );

        uint256 totalSupplyAfter = easyFarm.totalSupply();

        assertEq(totalSupplyAfter, 1021938000000000000020);
        assertEq(
            easyFarm.balanceOf(easyFarm.feeAddress()),
            totalSupplyAfter - totalSupplyBefore
        );
    }

    function test_mintPerformanceFee_both_mint() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        uint256 totalSupplyBefore = easyFarm.totalSupply();

        easyFarm.exposed_mintPerformanceFee(
            0.1e18,
            100e18,
            totalSupplyBefore,
            easyFarm.totalUSDValue()
        );

        uint256 totalSupplyAfter = easyFarm.totalSupply();

        assertEq(totalSupplyAfter, 1141937990915181186599);
        assertEq(
            easyFarm.balanceOf(easyFarm.feeAddress()),
            totalSupplyAfter - totalSupplyBefore
        );
    }

    function test_tokensUSDValue() public {
        (uint256 token0USD, uint256 token1USD, uint256 totalUSD) = easyFarm
            .exposed_tokensUSDValue(1e18, 100e18);

        assertEq(token0USD, 1001.9e18);
        assertEq(token1USD, 100e18);
        assertEq(totalUSD, 1101.9e18);

        (token0USD, token1USD, totalUSD) = easyFarm.exposed_tokensUSDValue(
            0,
            0
        );

        assertEq(token0USD, 0);
        assertEq(token1USD, 0);
        assertEq(totalUSD, 0);
    }

    function test_checkUpkeep_noRebalanceNeeded() public {
        (bool upkeepNeeded, bytes memory performData) = easyFarm.checkUpkeep(
            ""
        );
        assertEq(upkeepNeeded, false);
        assertEq(performData, "");
    }

    function test_checkUpkeep_rebalanceNeeded() public {
        vm.warp(block.timestamp + 1 hours);
        token0PriceFeed.setPrice(int256(1001.9e8 + 20e8));
        strategy.performUpkeep("");

        (bool upkeepNeeded, bytes memory performData) = easyFarm.checkUpkeep(
            ""
        );
        assertEq(upkeepNeeded, true);
    }

    function test_deposit() public {
        //   _mintFullRangePosition();
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        assertEq(easyFarm.balanceOf(alice), 550.95e18);
        assertEq(easyFarm.totalSupply(), 550.95e18);

        token0.mint(john, 1e18);
        token1.mint(john, 100e18);
        vm.startPrank(john);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        assertEq(easyFarm.balanceOf(john), 550949750387902151710);
        assertEq(easyFarm.totalSupply(), 1101899750387902151710);
        assertEq(
            easyFarm.totalSupply(),
            easyFarm.balanceOf(john) + easyFarm.balanceOf(alice)
        );
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 0);
        assertEq(easyFarm.totalUSDValue(), 1101900250026483618672);

        _swapFromBob(true);
        _swapFromBob(false, 300e18);

        (uint256 amount0, uint256 amount1) = easyFarm.executor().positionFees();

        (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD) = easyFarm
            .positionFeesUSD();

        vm.startPrank(alice);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        vm.startPrank(john);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        assertEq(easyFarm.balanceOf(alice), 1101910972251178612918);
        assertEq(easyFarm.balanceOf(john), 1101920757022600019610);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 33289912716463267);
        assertEq(easyFarm.totalSupply(), 2203865019186495095795);
        assertEq(easyFarm.totalUSDValue(), 2203777613617343486022);
        assertEq(
            easyFarm.totalSupply(),
            easyFarm.balanceOf(john) +
                easyFarm.balanceOf(alice) +
                easyFarm.balanceOf(easyFarm.feeAddress())
        );
    }

    function test_deposit_zeroAmounts_revert() public {
        vm.expectRevert();
        easyFarm.deposit(0, 0, 0);
    }

    function test_deposit_slippageNotExceeded() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        (, , uint256 totalUSD) = easyFarm.exposed_tokensUSDValue(1e18, 100e18);

        easyFarm.deposit(1e18, 100e18, totalUSD);
        vm.stopPrank();
    }

    function test_deposit_slippageExceeded_revert() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);

        (, , uint256 totalUSD) = easyFarm.exposed_tokensUSDValue(1e18, 100e18);

        vm.expectRevert();
        easyFarm.deposit(1e18, 100e18, totalUSD + 1);
        vm.stopPrank();
    }

    function test_deposit_paused_revert() public {
        easyFarm.pause();

        vm.expectRevert();
        easyFarm.deposit(1e18, 100e18, 0);
    }

    function test_deposit_minimumDepositUSD_revert() public {
        uint256 minimumDepositUSD = easyFarm.minimumDepositUSD();

        vm.expectRevert();
        easyFarm.deposit(0, minimumDepositUSD - 1, 0);
    }

    function test_deposit_maximumCapacity_revert() public {
        uint256 maximumCapacity = easyFarm.maximumCapacity();

        vm.expectRevert();
        easyFarm.deposit(0, maximumCapacity + 1, 0);
    }

    function test_withdraw() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        token0.mint(john, 1e18);
        token1.mint(john, 100e18);
        vm.startPrank(john);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        _swapFromBob(true);
        _swapFromBob(false, 300e18);

        vm.startPrank(alice);
        easyFarm.withdraw(easyFarm.balanceOf(alice), 0);
        vm.stopPrank();

        vm.startPrank(john);
        easyFarm.withdraw(easyFarm.balanceOf(john), 0);
        vm.stopPrank();

        assertEq(easyFarm.balanceOf(alice), 0);
        assertEq(token0.balanceOf(alice), 1000213750691698236);
        assertEq(token1.balanceOf(alice), 99886269144365036707);
        assertEq(easyFarm.balanceOf(john), 0);
        assertEq(token0.balanceOf(john), 1000177204667026134);
        assertEq(token1.balanceOf(john), 99882578623637822709);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 40012885071072485);
        assertEq(
            easyFarm.totalSupply(),
            easyFarm.balanceOf(easyFarm.feeAddress())
        );
        assertEq(easyFarm.totalUSDValue(), 40015077265156601);
    }

    function test_withdraw_slippageNotExceeded() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        uint256 balance = easyFarm.balanceOf(alice);
        uint256 totalUSD = easyFarm.totalUSDValue();
        uint256 totalSupply = easyFarm.totalSupply();

        uint256 expected = FarmlyFullMath.mulDiv(
            totalUSD,
            balance,
            totalSupply
        );

        vm.startPrank(alice);
        easyFarm.withdraw(balance, expected);
        vm.stopPrank();
    }

    function test_withdraw_slippageExceeded_revert() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        uint256 balance = easyFarm.balanceOf(alice);
        uint256 totalUSD = easyFarm.totalUSDValue();
        uint256 totalSupply = easyFarm.totalSupply();

        uint256 expected = FarmlyFullMath.mulDiv(
            totalUSD,
            balance,
            totalSupply
        );

        vm.startPrank(alice);
        vm.expectRevert();
        easyFarm.withdraw(balance, expected + 1);
        vm.stopPrank();
    }

    function test_withdraw_zeroAmounts_revert() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        token0.mint(john, 1e18);
        token1.mint(john, 100e18);
        vm.startPrank(john);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(0.5e18, 50e18, 0);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert();
        easyFarm.withdraw(0, 0);
        vm.stopPrank();

        vm.startPrank(john);
        vm.expectRevert();
        easyFarm.withdraw(0, 0);
        vm.stopPrank();
    }

    function test_performUpkeep_notUpkeepNeeded_revert() public {
        vm.expectRevert();
        easyFarm.performUpkeep("");
    }

    function test_performUpkeep_rebalanceNeeded_withoutMint() public {
        vm.warp(block.timestamp + 1 hours);
        token0PriceFeed.setPrice(int256(1001.9e8 + 20e8));
        strategy.performUpkeep("");

        easyFarm.performUpkeep("");

        assertEq(easyFarm.latestLowerPrice(), 992924841638183881677);
        assertEq(easyFarm.latestUpperPrice(), 1010958402291379433820);
        assertEq(easyFarm.latestTimestamp(), block.timestamp);
        assertEq(easyFarm.latestTimestamp(), 121 hours);
        assertEq(easyFarm.totalSupply(), 0);
        assertEq(easyFarm.totalUSDValue(), 0);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 0);
    }

    function test_performUpkeep_rebalanceNeeded_withMint_zeroFees() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
        token0PriceFeed.setPrice(int256(1001.9e8 + 15e8));
        strategy.performUpkeep("");

        easyFarm.performUpkeep("");

        assertEq(easyFarm.latestLowerPrice(), 994912579011074907525);
        assertEq(easyFarm.latestUpperPrice(), 1008938606943460321466);
        assertEq(easyFarm.latestTimestamp(), 121 hours);
        assertEq(easyFarm.totalSupply(), 1101.9e18);
        assertEq(easyFarm.totalUSDValue(), 1116830138507565774744);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 0);
    }

    function test_performUpkeep_rebalanceNeeded_withMint() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
        token0PriceFeed.setPrice(int256(1001.9e8 + 15e8));
        strategy.performUpkeep("");

        _swapFromBob(true);
        _swapFromBob(false);

        easyFarm.performUpkeep("");

        assertEq(easyFarm.latestLowerPrice(), 994912579011074907525);
        assertEq(easyFarm.latestUpperPrice(), 1008938606943460321466);
        assertEq(easyFarm.latestTimestamp(), 121 hours);
        assertEq(easyFarm.totalSupply(), 1101910004136749194150);
        assertEq(easyFarm.totalUSDValue(), 1118641702587282900748);
        assertEq(easyFarm.balanceOf(easyFarm.feeAddress()), 10004136749194150);
    }

    function test_totalUSDValue_withoutDeposits() public {
        assertEq(easyFarm.totalUSDValue(), 0);
    }

    function test_totalUSDValue_withDeposits() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        assertEq(easyFarm.totalUSDValue(), 1101900250026577799403);
    }

    function test_positionFeesUSD_withoutFees() public {
        (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD) = easyFarm
            .positionFeesUSD();

        assertEq(amount0USD, 0);
        assertEq(amount1USD, 0);
        assertEq(totalUSD, 0);
    }

    function test_positionFeesUSD_withFees() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        _swapFromBob(false);
        _swapFromBob(true);

        (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD) = easyFarm
            .positionFeesUSD();

        assertEq(amount0USD, 50531641888723603);
        assertEq(amount1USD, 499113205276844);
        assertEq(totalUSD, 51030755094000447);
        assertEq(totalUSD, amount0USD + amount1USD);
    }

    function test_positionAmountsUSD_withoutAmounts() public {
        (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD) = easyFarm
            .positionAmountsUSD();

        assertEq(amount0USD, 0);
        assertEq(amount1USD, 0);
        assertEq(totalUSD, 0);
    }

    function test_positionAmountsUSD_withAmounts() public {
        token0.mint(alice, 1e18);
        token1.mint(alice, 100e18);
        vm.startPrank(alice);
        token0.approve(address(easyFarm), 1e18);
        token1.approve(address(easyFarm), 100e18);
        easyFarm.deposit(1e18, 100e18, 0);
        vm.stopPrank();

        (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD) = easyFarm
            .positionAmountsUSD();

        assertEq(amount0USD, 1002077697537605619951);
        assertEq(amount1USD, 99822552488972179452);
        assertEq(totalUSD, 1101900250026577799403);
        assertEq(totalUSD, amount0USD + amount1USD);
    }

    /*
    function _mintFullRangePosition() internal {
        token0.mint(alice, 1000e18);
        token1.mint(alice, 1_000_000e18);
        vm.startPrank(alice);
        token0.approve(address(nonfungiblePositionManager), 1000e18);
        token1.approve(address(nonfungiblePositionManager), 1_000_000e18);

        nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: poolFee,
                tickLower: FarmlyTickLib.getTick(
                    500e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(pool.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    5000e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(pool.tickSpacing())
                ),
                amount0Desired: 1000e18,
                amount1Desired: 1_000_000e18,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp
            })
        );
        vm.stopPrank();
        deal(address(token0), alice, 0);
        deal(address(token1), alice, 0);
    }
    */
}
