pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";
import {MockERC20Token} from "./mocks/MockERC20Token.sol";

contract FarmlyUniV3ExecutorTest is Test {
    IUniswapV3Factory uniswapV3Factory;
    INonfungiblePositionManager nonfungiblePositionManager;
    ISwapRouter swapRouter;
    MockERC20Token token0;
    MockERC20Token token1;
    FarmlyUniV3Executor executor;

    function setUp() public {
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

        uniswapV3Factory.createPool(address(token0), address(token1), 500);

        executor = new FarmlyUniV3Executor(
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            address(token0),
            address(token1),
            500
        );
    }

    function test_constructor() public {
        address factory = address(executor.factory());
        address nonfungiblePositionManager = address(
            executor.nonfungiblePositionManager()
        );
        address swapRouter = address(executor.swapRouter());
        address pool = address(executor.pool());
        address token0 = executor.token0();
        address token1 = executor.token1();
        uint24 poolFee = executor.poolFee();

        assertEq(factory, address(uniswapV3Factory));
        assertEq(
            nonfungiblePositionManager,
            address(nonfungiblePositionManager)
        );
        assertEq(swapRouter, address(swapRouter));
        assertNotEq(pool, address(0));
        assertEq(token0, address(token0));
        assertEq(token1, address(token1));
        assertEq(poolFee, 500);
    }
}
