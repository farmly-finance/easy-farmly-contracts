pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyEasyReader} from "../src/readers/FarmlyEasyReader.sol";

contract DeployFarmlyEasyReader is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FarmlyEasyReader reader = new FarmlyEasyReader();

        vm.writeFile(
            "./deployments/FarmlyEasyReader.txt",
            vm.toString(address(reader))
        );

        vm.stopBroadcast();
    }
}
