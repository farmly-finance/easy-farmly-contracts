pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyEasyFarmFactory} from "../src/factories/FarmlyEasyFarmFactory.sol";

contract FarmlyEasyFarmFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new FarmlyEasyFarmFactory();

        vm.stopBroadcast();
    }
}
