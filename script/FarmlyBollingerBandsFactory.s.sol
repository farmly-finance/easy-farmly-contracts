pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyBollingerBandsFactory} from "../src/factories/FarmlyBollingerBandsFactory.sol";

contract FarmlyBollingerBandsFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FarmlyBollingerBandsFactory farmlyBollingerBandsFactory = new FarmlyBollingerBandsFactory();

        vm.stopBroadcast();
    }
}
