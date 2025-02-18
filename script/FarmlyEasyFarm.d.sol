pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyEasyFarm} from "../src/FarmlyEasyFarm.sol";
import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";

contract DeployFarmlyEasyFarm is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        string memory shareTokenName = "Farmly Easy Farm";
        string memory shareTokenSymbol = "FARM";

        address strategy = vm.parseAddress(
            vm.readFile("deployments/FarmlyBollingerBandsStrategy.txt")
        );
        address executor = vm.parseAddress(
            vm.readFile("deployments/FarmlyUniV3Executor.txt")
        );

        address token0 = 0xb7174F8B1927e49df49af654E76f5a7C180183CB;
        address token1 = 0xbb010C74c1441f152051951165B5031F618Ddae3;

        address token0PriceFeed = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        address token1PriceFeed = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

        FarmlyEasyFarm easyFarm = new FarmlyEasyFarm(
            shareTokenName,
            shareTokenSymbol,
            strategy,
            executor,
            token0,
            token1,
            token0PriceFeed,
            token1PriceFeed
        );

        FarmlyUniV3Executor(executor).transferOwnership(address(easyFarm));

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
