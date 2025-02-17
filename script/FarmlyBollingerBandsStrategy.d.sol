pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyBollingerBandsStrategy} from "../src/strategies/FarmlyBollingerBandsStrategy.sol";
import {console} from "forge-std/console.sol";

contract DeployFarmlyBollingerBandsStrategy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address token0PriceFeed = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        address token1PriceFeed = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
        uint16 ma = 20;
        uint16 std = 3;
        uint256 period = 1 hours;
        uint256 rebalanceThreshold = 500;

        FarmlyBollingerBandsStrategy strategy = new FarmlyBollingerBandsStrategy(
                address(token0PriceFeed),
                address(token1PriceFeed),
                ma,
                std,
                period,
                rebalanceThreshold
            );

        vm.writeFile(
            "./deployments/FarmlyBollingerBandsStrategy.txt",
            vm.toString(address(strategy))
        );

        console.log("Bollinger Bands Strategy deployed at", address(strategy));

        vm.stopBroadcast();
    }
}
