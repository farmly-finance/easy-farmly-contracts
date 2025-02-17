pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";
import {FarmlyUniV3ExecutorHelper} from "./helpers/FarmlyUniV3ExecutorHelper.sol";
import {FarmlyTickLib} from "../src/libraries/FarmlyTickLib.sol";
import {UniswapV3Fixture} from "./fixtures/UniswapV3Fixture.sol";

contract FarmlyUniV3ExecutorTest is Test, UniswapV3Fixture {
    FarmlyUniV3ExecutorHelper executor;

    constructor() UniswapV3Fixture() {}

    function setUp() public {
        executor = new FarmlyUniV3ExecutorHelper(
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            address(token0),
            address(token1),
            poolFee
        );
    }

    function test_constructor() public {
        address factory = address(executor.factory());
        address positionManager = address(
            executor.nonfungiblePositionManager()
        );
        address swapRouter = address(executor.swapRouter());
        address pool = address(executor.pool());
        uint24 tickSpacing = executor.tickSpacing();
        address token0 = executor.token0();
        address token1 = executor.token1();
        uint24 poolFee = executor.poolFee();

        assertEq(factory, address(uniswapV3Factory));
        assertEq(positionManager, address(nonfungiblePositionManager));
        assertEq(swapRouter, address(swapRouter));
        assertNotEq(pool, address(0));
        assertEq(tickSpacing, 10);
        assertEq(token0, address(token0));
        assertEq(token1, address(token1));
        assertEq(poolFee, 500);
    }

    function test_nearestRange() public {
        (uint256 lowerPrice, uint256 upperPrice) = executor.nearestRange(
            900e18,
            1100e18
        );
        assertEq(lowerPrice, 900238630045720369936);
        assertEq(upperPrice, 1099542950988669371071);
    }

    function test_nearestRange_zeroPrice_revert() public {
        vm.expectRevert();
        executor.nearestRange(0, 0);
    }

    function test_tokenBalances() public {
        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();
        assertEq(amount0, 0);
        assertEq(amount1, 0);

        token0.mint(address(executor), 100e18);
        token1.mint(address(executor), 100_000e18);

        (amount0, amount1) = executor.exposed_tokenBalances();
        assertEq(amount0, 100e18);
        assertEq(amount1, 100_000e18);
    }

    function test_addBalanceLiquidity_mintWithZeroBalance() public {
        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        assertEq(executor.latestTokenId(), 0);
    }

    function test_addBalanceLiquidity_mintWithNonZeroBalance() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);
        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();
        assertEq(executor.latestTokenId(), 2);
        assertTrue(amount0 < amount0ToAdd / 10_000);
        assertTrue(amount1 < amount1ToAdd / 10_000);
    }

    function test_addBalanceLiquidity_increaseWithZeroBalance() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();

        assertEq(executor.latestTokenId(), 2);
        assertTrue(amount0 < amount0ToAdd / 10_000);
        assertTrue(amount1 < amount1ToAdd / 10_000);
    }

    function test_addBalanceLiquidity_increaseWithNonZeroBalance() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();

        assertEq(executor.latestTokenId(), 2);
        assertTrue(amount0 < amount0ToAdd / 10_000);
        assertTrue(amount1 < amount1ToAdd / 10_000);
    }

    function test_increasePosition_withoutMint_revert() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        vm.expectRevert();
        executor.exposed_increasePosition(amount0ToAdd, amount1ToAdd);
    }

    function test_increasePosition_withZero_revert() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.exposed_increasePosition(0, 0);
    }

    function test_increasePosition_withNonZero() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_increasePosition(amount0ToAdd, amount1ToAdd);

        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();

        assertTrue(
            amount0 < amount0ToAdd / 10_000 || amount1 < amount1ToAdd / 10_000
        );
    }

    function test_decreasePosition_withoutMint() public {
        (uint256 amount0Decreased, uint256 amount1Decreased) = executor
            .exposed_decreasePosition(0);

        assertEq(amount0Decreased, 0);
        assertEq(amount1Decreased, 0);
    }

    function test_decreasePosition_withZero_revert() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.exposed_decreasePosition(0);
    }

    function test_decreasePosition_withNonZero() public {
        uint256 amount0ToAdd = 1e18;
        uint256 amount1ToAdd = 1000e18;
        token0.mint(address(executor), amount0ToAdd);
        token1.mint(address(executor), amount1ToAdd);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(executor.latestTokenId());

        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();

        (uint256 amount0Decreased, uint256 amount1Decreased) = executor
            .exposed_decreasePosition(liquidity);

        assertTrue(
            (amount0Decreased + amount0 < amount0ToAdd &&
                amount1Decreased + amount1 > amount1ToAdd) ||
                (amount0Decreased + amount0 > amount0ToAdd &&
                    amount1Decreased + amount1 < amount1ToAdd)
        );
    }

    function test_mintPosition_invalidRange_revert() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                amount0Add: 1e18,
                amount1Add: 1000e18
            });

        vm.expectRevert();
        executor.exposed_mintPosition(position, 1e18, 1000e18);

        position = FarmlyUniV3Executor.Position({
            tickLower: 0,
            tickUpper: 0,
            amount0Add: 1e18,
            amount1Add: 1000e18
        });

        vm.expectRevert();
        executor.exposed_mintPosition(position, 1e18, 1000e18);
    }

    function test_mintPosition_withZeroAmount() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                amount0Add: 0,
                amount1Add: 0
            });

        executor.exposed_mintPosition(position, 0, 0);

        assertEq(executor.latestTokenId(), 0);
    }

    function test_mintPosition_withNonZeroAmount() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                amount0Add: 1e18,
                amount1Add: 1000e18
            });

        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (uint256 tokenId, , ) = executor.exposed_mintPosition(
            position,
            1e18,
            1000e18
        );

        (uint256 amount0, uint256 amount1) = executor.exposed_tokenBalances();
        assertEq(tokenId, 2);
        assertTrue(amount0 == 0 || amount1 == 0);
    }

    function test_swapExactInput_withZeroAmount() public {
        FarmlyUniV3Executor.Swap memory swap = FarmlyUniV3Executor.Swap({
            tokenIn: address(token0),
            tokenOut: address(token1),
            amountIn: 0,
            amountOut: 0,
            sqrtPriceX96: 0
        });

        uint256 amountOut = executor.exposed_swapExactInput(swap);
        assertEq(amountOut, 0);
    }

    function test_swapExactInput_withNonZeroAmount() public {
        FarmlyUniV3Executor.Swap memory swap = FarmlyUniV3Executor.Swap({
            tokenIn: address(token0),
            tokenOut: address(token1),
            amountIn: 1e18,
            amountOut: 0,
            sqrtPriceX96: 0
        });

        token0.mint(address(executor), 1e18);

        uint256 amountOut = executor.exposed_swapExactInput(swap);
        assertGt(amountOut, 0);
    }

    function test_swapExactInput_exceedsBalance_revert() public {
        FarmlyUniV3Executor.Swap memory swap = FarmlyUniV3Executor.Swap({
            tokenIn: address(token0),
            tokenOut: address(token1),
            amountIn: 1e18,
            amountOut: 0,
            sqrtPriceX96: 0
        });

        vm.expectRevert();
        executor.exposed_swapExactInput(swap);
    }

    function test_collectFees_withoutMint() public {
        (uint256 amount0, uint256 amount1) = executor.exposed_collectFees();
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_collectFees_withMintZeroFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.exposed_collectFees();
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_collectFees_withMintNonZeroFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        _swapFromBob(true);

        (uint256 amount0, uint256 amount1) = executor.exposed_collectFees();
        assertEq(amount0, 456470799282880);
        assertEq(amount1, 0);

        _swapFromBob(false);

        (amount0, amount1) = executor.exposed_collectFees();
        assertEq(amount0, 0);
        assertEq(amount1, 456470799282880);
    }

    function test_burnPositionToken_withoutMint() public {
        executor.exposed_burnPositionToken();
        assertEq(executor.latestTokenId(), 0);
    }

    function test_burnPositionToken_withMintWithoutDecrease_revert() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.exposed_burnPositionToken();
    }

    function test_burnPositionToken_withMintAndDecrease() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(executor.latestTokenId());

        executor.exposed_decreasePosition(liquidity);

        executor.exposed_burnPositionToken();

        assertEq(executor.latestTokenId(), 0);
    }

    function test_positionInfo_withoutMint() public {
        (int24 tickLower, int24 tickUpper, uint128 liquidity) = executor
            .exposed_positionInfo();
        assertEq(tickLower, 0);
        assertEq(tickUpper, 0);
        assertEq(liquidity, 0);
    }

    function test_positionInfo() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (
            ,
            ,
            ,
            ,
            ,
            int24 _tickLower,
            int24 _tickUpper,
            uint128 _liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(executor.latestTokenId());

        (int24 tickLower, int24 tickUpper, uint128 liquidity) = executor
            .exposed_positionInfo();

        assertEq(tickLower, _tickLower);
        assertEq(tickUpper, _tickUpper);
        assertEq(liquidity, _liquidity);
    }

    function test_amountsForAdd() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                amount0Add: 1e18,
                amount1Add: 1000e18
            });

        (
            FarmlyUniV3Executor.Swap memory swap,
            uint256 amount0Add,
            uint256 amount1Add
        ) = executor.exposed_amountsForAdd(position);

        assertEq(swap.tokenIn, address(token0));
        assertEq(swap.tokenOut, address(token1));
        assertGt(swap.amountIn, 0);
        assertGt(swap.amountOut, 0);
        assertEq(swap.sqrtPriceX96, 0);
        assertEq(amount0Add, 1e18 - swap.amountIn);
        assertEq(amount1Add, 1000e18 + swap.amountOut);
        assertEq(amount0Add + swap.amountIn, 1e18);
        assertEq(amount1Add - swap.amountOut, 1000e18);
    }

    function test_amountsForAdd_withInvalidRange_revert() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: 0,
                tickUpper: 0,
                amount0Add: 1e18,
                amount1Add: 1000e18
            });

        vm.expectRevert();
        executor.exposed_amountsForAdd(position);
    }

    function test_amountsForAdd_withInvalidAmount() public {
        FarmlyUniV3Executor.Position memory position = FarmlyUniV3Executor
            .Position({
                tickLower: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(executor.tickSpacing())
                ),
                amount0Add: 0,
                amount1Add: 0
            });

        (
            FarmlyUniV3Executor.Swap memory swap,
            uint256 amount0Add,
            uint256 amount1Add
        ) = executor.exposed_amountsForAdd(position);

        if (address(token0) < address(token1)) {
            assertEq(swap.tokenIn, address(token1));
            assertEq(swap.tokenOut, address(token0));
        } else {
            assertEq(swap.tokenIn, address(token0));
            assertEq(swap.tokenOut, address(token1));
        }
        assertEq(swap.amountIn, 0);
        assertEq(swap.amountOut, 0);
        assertEq(swap.sqrtPriceX96, 0);
        assertEq(amount0Add, 0);
        assertEq(amount1Add, 0);
    }

    function test_feeGrowthInside_withoutMint() public {
        int24 tickLower = FarmlyTickLib.getTick(
            900e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );
        int24 tickUpper = FarmlyTickLib.getTick(
            1100e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = executor
            .exposed_feeGrowthInside(tickLower, tickUpper);
        assertEq(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);
    }

    function test_feeGrowthInside_zeroFeeGrowth() public {
        int24 tickLower = FarmlyTickLib.getTick(
            900e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );
        int24 tickUpper = FarmlyTickLib.getTick(
            1100e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );

        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = executor
            .exposed_feeGrowthInside(tickLower, tickUpper);

        assertGt(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);
    }

    function test_feeGrowthInside() public {
        int24 tickLower = FarmlyTickLib.getTick(
            900e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );
        int24 tickUpper = FarmlyTickLib.getTick(
            1100e18,
            token0.decimals(),
            token1.decimals(),
            uint24(executor.tickSpacing())
        );

        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        _swapFromBob(true);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = executor
            .exposed_feeGrowthInside(tickLower, tickUpper);

        assertGt(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);

        _swapFromBob(false);

        (feeGrowthInside0X128, feeGrowthInside1X128) = executor
            .exposed_feeGrowthInside(tickLower, tickUpper);

        assertGt(feeGrowthInside0X128, 0);
        assertGt(feeGrowthInside1X128, 0);
    }

    function test_positionAmounts_withoutMint() public {
        (uint256 amount0, uint256 amount1) = executor.positionAmounts();
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_positionAmounts() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.positionAmounts();
        assertEq(amount0, 995752494671009102);
        assertEq(amount1, 1004235758422338150160);
    }

    function test_positionFees_withoutMint() public {
        (uint256 amount0, uint256 amount1) = executor.positionFees();
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_positionFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        _swapFromBob(true);

        (uint256 amount0, uint256 amount1) = executor.positionFees();
        assertEq(amount0, 456470799282880);
        assertEq(amount1, 0);

        _swapFromBob(false);

        (amount0, amount1) = executor.positionFees();
        assertEq(amount0, 456470799282880);
        assertEq(amount1, 456470799282880);
    }

    function test_onRebalance() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        _swapFromBob(true);

        executor.onRebalance(950e18, 1050e18);

        (uint256 amount0, uint256 amount1) = executor.positionAmounts();
        assertEq(amount0, 1954061238454106981);
        assertEq(amount1, 92045189247507633410);
        assertEq(executor.latestTokenId(), 3);
        assertLt(token0.balanceOf(address(executor)), amount0 / 10_000);
        assertLt(token1.balanceOf(address(executor)), amount1 / 10_000);
    }

    function test_onRebalance_notOwner_revert() public {
        vm.prank(makeAddr("Alice"));
        vm.expectRevert();
        executor.onRebalance(0, 0);
    }

    function test_onRebalance_invalidRange_revert() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.onRebalance(0, 0);

        vm.expectRevert();
        executor.onRebalance(1050e18, 1050e18);

        vm.expectRevert();
        executor.onRebalance(1050e18, 950e18);
    }

    function test_onRebalance_zeroFees() public {}

    function test_onRebalance_withoutMint() public {}

    function test_onDeposit_notOwner_revert() public {
        vm.prank(makeAddr("Alice"));
        vm.expectRevert();
        executor.onDeposit(900e18, 1100e18);
    }

    function test_onDeposit_invalidRange_revert() public {
        vm.expectRevert();
        executor.onDeposit(0, 0);

        vm.expectRevert();
        executor.onDeposit(1000e18, 1000e18);

        vm.expectRevert();
        executor.onDeposit(1100e18, 900e18);
    }

    function test_onDeposit_zeroBalanceZeroFees_mint() public {
        (uint256 amount0Collected, uint256 amount1Collected) = executor
            .onDeposit(900e18, 1100e18);
        assertEq(executor.latestTokenId(), 0);
        assertEq(amount0Collected, 0);
        assertEq(amount1Collected, 0);
    }

    function test_onDeposit_zeroBalanceZeroFees_increase() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (uint256 amount0Collected, uint256 amount1Collected) = executor
            .onDeposit(900e18, 1100e18);

        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0Collected, 0);
        assertEq(amount1Collected, 0);

        deal(address(token0), address(executor), 0);
        deal(address(token1), address(executor), 0);

        vm.expectRevert();
        executor.onDeposit(900e18, 1100e18);
    }

    function test_onDeposit_zeroBalanceNonZeroFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (uint256 amount0Collected, uint256 amount1Collected) = executor
            .onDeposit(900e18, 1100e18);

        _swapFromBob(true);

        (amount0Collected, amount1Collected) = executor.onDeposit(
            900e18,
            1100e18
        );
        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0Collected, 456470799282880);
        assertEq(amount1Collected, 0);
    }

    function test_onDeposit_nonZeroBalanceZeroFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (uint256 amount0Collected, uint256 amount1Collected) = executor
            .onDeposit(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.positionAmounts();

        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0, 995752494671009102);
        assertEq(amount1, 1004235758422338150160);

        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (amount0Collected, amount1Collected) = executor.onDeposit(
            900e18,
            1100e18
        );

        (amount0, amount1) = executor.positionAmounts();

        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0Collected, 0);
        assertEq(amount1Collected, 0);
        assertEq(amount0, 1995557933376617342);
        assertEq(amount1, 2004428332497739602742);
    }

    function test_onDeposit_nonZeroBalanceNonZeroFees() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        (uint256 amount0Collected, uint256 amount1Collected) = executor
            .onDeposit(900e18, 1100e18);

        (uint256 amount0, uint256 amount1) = executor.positionAmounts();

        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0, 995752494671009102);
        assertEq(amount1, 1004235758422338150160);

        _swapFromBob(true);

        (amount0Collected, amount1Collected) = executor.onDeposit(
            900e18,
            1100e18
        );

        (amount0, amount1) = executor.positionAmounts();

        assertEq(executor.latestTokenId(), 2);
        assertEq(amount0, 1908691230425416280);
        assertEq(amount1, 134415115353098754797);
        assertEq(amount0Collected, 456470799282880);
        assertEq(amount1Collected, 0);
    }

    function test_onWithdraw_notOwner_revert() public {
        vm.prank(makeAddr("Alice"));
        vm.expectRevert();
        executor.onWithdraw(0, address(0));
    }

    function test_onWithdraw_amountTooLarge_revert() public {
        vm.expectRevert();
        executor.onWithdraw(100e18 + 1, address(0));
    }

    function test_onWithdraw_zeroAmount_revert() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.onWithdraw(0, address(0));
    }

    function test_onWithdraw_zeroAddress_revert() public {
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        vm.expectRevert();
        executor.onWithdraw(1e18, address(0));
    }

    function test_onWithdraw_zeroFees() public {
        address bob = makeAddr("Bob");
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        ) = executor.onWithdraw(100e18, bob);

        assertEq(amount0Collected, 0);
        assertEq(amount1Collected, 0);
        assertEq(token0.balanceOf(bob), amount0);
        assertEq(token1.balanceOf(bob), amount1);
        assertEq(token0.balanceOf(bob), 995752494671009102);
        assertEq(token1.balanceOf(bob), 1004235758422338150160);
    }

    function test_onWithdraw() public {
        address bob = makeAddr("Bob");
        token0.mint(address(executor), 1e18);
        token1.mint(address(executor), 1000e18);

        executor.exposed_addBalanceLiquidity(900e18, 1100e18);

        _swapFromBob(true);

        uint256 bobBalance0After = token0.balanceOf(bob);
        uint256 bobBalance1After = token1.balanceOf(bob);

        (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        ) = executor.onWithdraw(100e18, bob);

        assertEq(amount0Collected, 456470799282880);
        assertEq(amount1Collected, 0);
        assertEq(token0.balanceOf(bob), bobBalance0After + amount0);
        assertEq(token1.balanceOf(bob), bobBalance1After + amount1);
        assertEq(token0.balanceOf(bob), 1908691245357618704);
        assertEq(token1.balanceOf(bob), 1087184977576663259351);
    }
}
