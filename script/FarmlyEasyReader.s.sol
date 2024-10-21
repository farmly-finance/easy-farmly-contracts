pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyEasyReader} from "../src/FarmlyEasyReader.sol";

contract FarmlyEasyReaderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new FarmlyEasyReader();

        vm.stopBroadcast();
    }
}
