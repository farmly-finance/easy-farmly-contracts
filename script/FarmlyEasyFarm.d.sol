pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyEasyFarm} from "../src/FarmlyEasyFarm.sol";
import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";
import {console} from "forge-std/console.sol";
contract DeployFarmlyEasyFarm is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        string memory shareTokenName = "Farmly Easy Farm";
        string memory shareTokenSymbol = "FARM";

        address strategy = 0xc6813Fea485321811632693AF3C3b07358b01E28;

        address uniswapV3Factory = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        address nonfungiblePositionManager = 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2;
        address swapRouter = 0x7abD0faBE1Da48F2486b951E2b6B6f3Ac07fd98C;

        address token0 = 0xb7174F8B1927e49df49af654E76f5a7C180183CB;
        address token1 = 0xe9Ce413353e4A285F9EFfe150e1Cba229B1947AB;
        uint24 poolFee = 3000;
        address token0PriceFeed = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        address token1PriceFeed = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

        FarmlyUniV3Executor executor = new FarmlyUniV3Executor(
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            token0,
            token1,
            poolFee
        );

        FarmlyEasyFarm easyFarm = new FarmlyEasyFarm(
            shareTokenName,
            shareTokenSymbol,
            strategy,
            address(executor),
            token0,
            token1,
            token0PriceFeed,
            token1PriceFeed
        );

        console.log("Executor deployed at: ", address(executor));
        console.log("EasyFarm deployed at: ", address(easyFarm));

        executor.transferOwnership(address(easyFarm));

        easyFarm.setPerformanceFee(20_000);

        easyFarm.setFeeAddress(0x000000000000000000000000000000000000dEaD);

        easyFarm.setMaximumCapacity(500_000e18);

        easyFarm.setMinimumDepositUSD(10e18);

        vm.writeFile(
            "./deployments/FarmlyEasyFarm.txt",
            vm.toString(address(easyFarm))
        );

        vm.stopBroadcast();
    }
}
