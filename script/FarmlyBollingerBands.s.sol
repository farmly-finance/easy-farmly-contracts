pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyBollingerBandsFactory} from "../src/factories/FarmlyBollingerBandsFactory.sol";

contract FarmlyBollingerBandsScript is Script {
    function run() external {
        address btcDataFeed = 0x6ce185860a4963106506C203335A2910413708e9;
        address ethDataFeed = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
        address usdcDataFeed = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
        address usdtDataFeed = 0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7;
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address factoryAddress = vm.envAddress(
            "FARMLY_BOLLINGER_BANDS_FACTORY_ADDRESS"
        );

        vm.startBroadcast(deployerPrivateKey);

        FarmlyBollingerBandsFactory farmlyBollingerBandsFactory = FarmlyBollingerBandsFactory(
                factoryAddress
            );

        farmlyBollingerBandsFactory.createNewBand(
            20,
            3,
            1 hours,
            1729018800,
            ethDataFeed,
            btcDataFeed
        );

        vm.stopBroadcast();
    }
}
