pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IFarmlyBollingerBands} from "../src/interfaces/IFarmlyBollingerBands.sol";
import {FarmlyEasyFarm} from "../src/FarmlyEasyFarm.sol";

contract FarmlyEasyFarmTest is Test {
    FarmlyEasyFarm public farmlyEasyFarm;
    address public tester = address(this);
    uint256 testAmount0 = 0;
    uint256 testAmount1 = 1000e6;

    function setUp() public {
        farmlyEasyFarm = new FarmlyEasyFarm(
            tester,
            tester,
            500,
            "Test",
            "TEST",
            IFarmlyBollingerBands(tester),
            1e18
        );

        farmlyEasyFarm.setLatestBollingers(2000 * 1e18, 2500 * 1e18);
        deal(address(farmlyEasyFarm.token0()), tester, testAmount0 * 2);
        deal(address(farmlyEasyFarm.token1()), tester, testAmount1 * 2);

        console.log(
            farmlyEasyFarm.latestTimestamp() +
                farmlyEasyFarm.farmlyBollingerBands().period()
        );
    }

    function test_PositionFees() public {
        (uint256 amount0, uint256 amount1) = farmlyEasyFarm.positionFees();

        console.log(amount0);
        console.log(amount1);
    }

    function test_Deposit() public {
        console.log(
            "Lower bollinger band: ",
            farmlyEasyFarm.latestLowerPrice()
        );
        console.log(
            "Upper bollinger band: ",
            farmlyEasyFarm.latestUpperPrice()
        );

        farmlyEasyFarm.token0().approve(address(farmlyEasyFarm), testAmount0);
        farmlyEasyFarm.token1().approve(address(farmlyEasyFarm), testAmount1);
        farmlyEasyFarm.deposit(testAmount0, testAmount1);
        console.log("tokenId", farmlyEasyFarm.latestTokenId());
        console.log(
            "token0 remaining: ",
            farmlyEasyFarm.token0().balanceOf(address(farmlyEasyFarm))
        );

        console.log(
            "token1 remaining: ",
            farmlyEasyFarm.token1().balanceOf(address(farmlyEasyFarm))
        );

        console.log("share price: ", farmlyEasyFarm.sharePrice());
        console.log("total supply: ", farmlyEasyFarm.totalSupply());
        console.log("total usd value: ", farmlyEasyFarm.totalUSDValue());
        farmlyEasyFarm.token0().approve(address(farmlyEasyFarm), testAmount0);
        farmlyEasyFarm.token1().approve(address(farmlyEasyFarm), testAmount1);
        farmlyEasyFarm.deposit(testAmount0, testAmount1);
        console.log("tokenId", farmlyEasyFarm.latestTokenId());
        console.log(
            "token0 remaining: ",
            farmlyEasyFarm.token0().balanceOf(address(farmlyEasyFarm))
        );

        console.log(
            "token1 remaining: ",
            farmlyEasyFarm.token1().balanceOf(address(farmlyEasyFarm))
        );

        console.log("share price: ", farmlyEasyFarm.sharePrice());
        console.log("total supply: ", farmlyEasyFarm.totalSupply());
        console.log("total usd value: ", farmlyEasyFarm.totalUSDValue());
    }

    function test_Withdraw() public {
        console.log(
            "token0 balance: ",
            farmlyEasyFarm.token0().balanceOf(address(this))
        );
        console.log(
            "token1 balance: ",
            farmlyEasyFarm.token1().balanceOf(address(this))
        );
        farmlyEasyFarm.token0().approve(address(farmlyEasyFarm), testAmount0);
        farmlyEasyFarm.token1().approve(address(farmlyEasyFarm), testAmount1);
        farmlyEasyFarm.deposit(testAmount0, testAmount1);

        console.log("share price: ", farmlyEasyFarm.sharePrice());
        console.log("total supply: ", farmlyEasyFarm.totalSupply());
        console.log("total usd value: ", farmlyEasyFarm.totalUSDValue());
        console.log(
            "token0 remaining: ",
            farmlyEasyFarm.token0().balanceOf(address(farmlyEasyFarm))
        );

        console.log(
            "token1 remaining: ",
            farmlyEasyFarm.token1().balanceOf(address(farmlyEasyFarm))
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

        ) = farmlyEasyFarm.nonfungiblePositionManager().positions(
                farmlyEasyFarm.latestTokenId()
            );

        console.log("liquidity: ", liquidity);

        farmlyEasyFarm.withdraw(500e8);

        console.log("share price: ", farmlyEasyFarm.sharePrice());
        console.log("total supply: ", farmlyEasyFarm.totalSupply());
        console.log("total usd value: ", farmlyEasyFarm.totalUSDValue());
        console.log(
            "token0 remaining: ",
            farmlyEasyFarm.token0().balanceOf(address(farmlyEasyFarm))
        );

        console.log(
            "token1 remaining: ",
            farmlyEasyFarm.token1().balanceOf(address(farmlyEasyFarm))
        );

        console.log(
            "token0 balance: ",
            farmlyEasyFarm.token0().balanceOf(address(this))
        );
        console.log(
            "token1 balance: ",
            farmlyEasyFarm.token1().balanceOf(address(this))
        );
    }
}
