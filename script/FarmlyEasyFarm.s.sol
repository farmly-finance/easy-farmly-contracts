pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {FarmlyEasyFarmFactory} from "../src/factories/FarmlyEasyFarmFactory.sol";
import {FarmlyUniV3Executor} from "../src/FarmlyUniV3Executor.sol";

contract FarmlyEasyFarmScript is Script {
    function run() external {
        address btcAddress = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        address ethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        address usdtAddress = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address factoryAddress = vm.envAddress(
            "FARMLY_EASY_FARM_FACTORY_ADDRESS"
        );

        address feeAddress = 0x0000001b8d3053c19e2070Bc98F98ee9709d9980;
        uint256 performanceFee = 20000;
        uint256 positionThreshold = 500;

        vm.startBroadcast(deployerPrivateKey);

        FarmlyEasyFarmFactory farmlyEasyFarmFactory = FarmlyEasyFarmFactory(
            factoryAddress
        );

        // *** //
        FarmlyUniV3Executor executor1 = new FarmlyUniV3Executor(
            btcAddress,
            ethAddress,
            500
        );

        farmlyEasyFarmFactory.createNewEasyFarm(
            "BTC-ETH/TEST",
            "BETEST",
            500e18,
            0x1f4138c534e675FDa62b55A107af1E57BCc83A3C,
            address(executor1)
        );

        executor1.transferOwnership(
            address(farmlyEasyFarmFactory.farmlyEasyFarms(0))
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(0).setPositionThreshold(
            positionThreshold
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(0).setPerformanceFee(
            performanceFee
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(0).setFeeAddress(feeAddress);

        console.log(address(farmlyEasyFarmFactory.farmlyEasyFarms(0)));
        // *** //

        // *** //
        FarmlyUniV3Executor executor2 = new FarmlyUniV3Executor(
            ethAddress,
            usdcAddress,
            500
        );

        farmlyEasyFarmFactory.createNewEasyFarm(
            "ETH-USDC/TEST",
            "EUCTEST",
            1000e18,
            0x6038aA752B8ef0A4e07553Cd0De8C54fCF56F5e2,
            address(executor2)
        );

        executor2.transferOwnership(
            address(farmlyEasyFarmFactory.farmlyEasyFarms(1))
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(1).setPositionThreshold(
            positionThreshold
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(1).setPerformanceFee(
            performanceFee
        );

        farmlyEasyFarmFactory.farmlyEasyFarms(1).setFeeAddress(feeAddress);

        console.log(address(farmlyEasyFarmFactory.farmlyEasyFarms(1)));
        // *** //

        vm.stopBroadcast();
    }
}
