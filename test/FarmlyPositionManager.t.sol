pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FarmlyPositionManager} from "../src/FarmlyPositionManager.sol";

contract FarmlyPositionManagerTest is Test {
    FarmlyPositionManager public farmlyPositionManager;
    address public tester = address(this);
    uint256 testAmount0 = 0;
    uint256 testAmount1 = 1000e6;

    function setUp() public {
        farmlyPositionManager = new FarmlyPositionManager();
        farmlyPositionManager.setLatestBollingers(2000 * 1e18, 2500 * 1e18);
        deal(address(farmlyPositionManager.token0()), tester, testAmount0 * 2);
        deal(address(farmlyPositionManager.token1()), tester, testAmount1 * 2);

        console.log(
            farmlyPositionManager.latestTimestamp() +
                farmlyPositionManager.farmlyBollingerBands().period()
        );
    }

    function test_PositionFees() public {
        (uint256 amount0, uint256 amount1) = farmlyPositionManager
            .positionFees();

        console.log(amount0);
        console.log(amount1);
    }

    function test_Deposit() public {
        console.log(
            "Lower bollinger band: ",
            farmlyPositionManager.latestLowerPrice()
        );
        console.log(
            "Upper bollinger band: ",
            farmlyPositionManager.latestUpperPrice()
        );

        farmlyPositionManager.token0().approve(
            address(farmlyPositionManager),
            testAmount0
        );
        farmlyPositionManager.token1().approve(
            address(farmlyPositionManager),
            testAmount1
        );
        farmlyPositionManager.deposit(testAmount0, testAmount1);
        console.log("tokenId", farmlyPositionManager.latestTokenId());
        console.log(
            "token0 remaining: ",
            farmlyPositionManager.token0().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log(
            "token1 remaining: ",
            farmlyPositionManager.token1().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log("share price: ", farmlyPositionManager.sharePrice());
        console.log("total supply: ", farmlyPositionManager.totalSupply());
        console.log("total usd value: ", farmlyPositionManager.totalUSDValue());
        farmlyPositionManager.token0().approve(
            address(farmlyPositionManager),
            testAmount0
        );
        farmlyPositionManager.token1().approve(
            address(farmlyPositionManager),
            testAmount1
        );
        farmlyPositionManager.deposit(testAmount0, testAmount1);
        console.log("tokenId", farmlyPositionManager.latestTokenId());
        console.log(
            "token0 remaining: ",
            farmlyPositionManager.token0().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log(
            "token1 remaining: ",
            farmlyPositionManager.token1().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log("share price: ", farmlyPositionManager.sharePrice());
        console.log("total supply: ", farmlyPositionManager.totalSupply());
        console.log("total usd value: ", farmlyPositionManager.totalUSDValue());
    }

    function test_Withdraw() public {
        console.log(
            "token0 balance: ",
            farmlyPositionManager.token0().balanceOf(address(this))
        );
        console.log(
            "token1 balance: ",
            farmlyPositionManager.token1().balanceOf(address(this))
        );
        farmlyPositionManager.token0().approve(
            address(farmlyPositionManager),
            testAmount0
        );
        farmlyPositionManager.token1().approve(
            address(farmlyPositionManager),
            testAmount1
        );
        farmlyPositionManager.deposit(testAmount0, testAmount1);

        console.log("share price: ", farmlyPositionManager.sharePrice());
        console.log("total supply: ", farmlyPositionManager.totalSupply());
        console.log("total usd value: ", farmlyPositionManager.totalUSDValue());
        console.log(
            "token0 remaining: ",
            farmlyPositionManager.token0().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log(
            "token1 remaining: ",
            farmlyPositionManager.token1().balanceOf(
                address(farmlyPositionManager)
            )
        );
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = farmlyPositionManager.nonfungiblePositionManager().positions(
                farmlyPositionManager.latestTokenId()
            );

        console.log("liquidity: ", liquidity);

        farmlyPositionManager.withdraw(500e8);

        console.log("share price: ", farmlyPositionManager.sharePrice());
        console.log("total supply: ", farmlyPositionManager.totalSupply());
        console.log("total usd value: ", farmlyPositionManager.totalUSDValue());
        console.log(
            "token0 remaining: ",
            farmlyPositionManager.token0().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log(
            "token1 remaining: ",
            farmlyPositionManager.token1().balanceOf(
                address(farmlyPositionManager)
            )
        );

        console.log(
            "token0 balance: ",
            farmlyPositionManager.token0().balanceOf(address(this))
        );
        console.log(
            "token1 balance: ",
            farmlyPositionManager.token1().balanceOf(address(this))
        );
    }
}
