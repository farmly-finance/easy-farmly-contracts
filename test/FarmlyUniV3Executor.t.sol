pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {MockERC20Token} from "./mocks/MockERC20Token.sol";
import {FarmlyUniV3ExecutorHelper} from "./helpers/FarmlyUniV3ExecutorHelper.sol";

contract FarmlyUniV3ExecutorTest is Test {
    IUniswapV3Factory uniswapV3Factory;
    INonfungiblePositionManager nonfungiblePositionManager;
    ISwapRouter swapRouter;
    MockERC20Token token0;
    MockERC20Token token1;
    FarmlyUniV3ExecutorHelper executor;

    function setUp() public {
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

        uniswapV3Factory.createPool(address(token0), address(token1), 500);

        deal(address(token0), alice, 1000000000000000000);
        deal(address(token1), alice, 1000000000000000000);

        executor = new FarmlyUniV3ExecutorHelper(
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

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
