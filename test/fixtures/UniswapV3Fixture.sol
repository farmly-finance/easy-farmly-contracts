pragma solidity ^0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {MockERC20Token} from "../mocks/MockERC20Token.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FarmlyTickLib} from "../../src/libraries/FarmlyTickLib.sol";

import {Test} from "forge-std/Test.sol";

abstract contract UniswapV3Fixture is Test {
    IUniswapV3Factory uniswapV3Factory;
    INonfungiblePositionManager nonfungiblePositionManager;
    ISwapRouter swapRouter;
    IUniswapV3Pool pool;
    MockERC20Token token0;
    MockERC20Token token1;
    uint24 poolFee;

    constructor() {
        address alice = makeAddr("Alice");

        uniswapV3Factory = IUniswapV3Factory(
            vm.parseAddress(vm.readFile("deployments/uniswapV3Factory.txt"))
        );

        nonfungiblePositionManager = INonfungiblePositionManager(
            vm.parseAddress(
                vm.readFile("deployments/nonfungiblePositionManager.txt")
            )
        );
        swapRouter = ISwapRouter(
            vm.parseAddress(vm.readFile("deployments/swapRouter.txt"))
        );

        token0 = new MockERC20Token("Mock tWETH", "tWETH");
        token1 = new MockERC20Token("Mock tUSDC", "tUSDC");
        poolFee = 500;

        token0.mint(alice, 1_00e18);
        token1.mint(alice, 1_000_000e18);

        bool zeroForOne = address(token0) < address(token1);

        if (!zeroForOne) {
            (token0, token1) = (token1, token0);
        }

        pool = IUniswapV3Pool(
            uniswapV3Factory.createPool(
                address(token0),
                address(token1),
                poolFee
            )
        );

        pool.initialize(
            TickMath.getSqrtRatioAtTick(
                FarmlyTickLib.getTick(
                    1000e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(pool.tickSpacing())
                )
            )
        );

        uint256 amount0 = zeroForOne ? 100e18 : 100_000e18;
        uint256 amount1 = zeroForOne ? 100_000e18 : 100e18;

        vm.startPrank(alice);
        token0.approve(address(nonfungiblePositionManager), amount0);
        token1.approve(address(nonfungiblePositionManager), amount1);

        nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: poolFee,
                tickLower: FarmlyTickLib.getTick(
                    900e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(pool.tickSpacing())
                ),
                tickUpper: FarmlyTickLib.getTick(
                    1100e18,
                    token0.decimals(),
                    token1.decimals(),
                    uint24(pool.tickSpacing())
                ),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp
            })
        );
        vm.stopPrank();
    }

    function _swapFromBob(bool zeroForOne) internal {
        address bob = makeAddr("Bob");
        if (zeroForOne) {
            token0.mint(bob, 1e18);
        } else {
            token1.mint(bob, 1e18);
        }
        vm.startPrank(bob);
        if (zeroForOne) {
            token0.approve(address(swapRouter), 1e18);
        } else {
            token1.approve(address(swapRouter), 1e18);
        }
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: zeroForOne ? address(token0) : address(token1),
                tokenOut: zeroForOne ? address(token1) : address(token0),
                fee: 500,
                recipient: bob,
                deadline: block.timestamp + 1000,
                amountIn: 1e18,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopPrank();
    }

    function _swapFromBob(bool zeroForOne, uint256 amount) internal {
        address bob = makeAddr("Bob");
        if (zeroForOne) {
            token0.mint(bob, amount);
        } else {
            token1.mint(bob, amount);
        }
        vm.startPrank(bob);
        if (zeroForOne) {
            token0.approve(address(swapRouter), amount);
        } else {
            token1.approve(address(swapRouter), amount);
        }
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: zeroForOne ? address(token0) : address(token1),
                tokenOut: zeroForOne ? address(token1) : address(token0),
                fee: 500,
                recipient: bob,
                deadline: block.timestamp + 1000,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopPrank();
    }
}
