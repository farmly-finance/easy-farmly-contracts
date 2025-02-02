pragma solidity 0.8.12;

import {Script} from "forge-std/Script.sol";
import {UniswapV3Factory} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import {console} from "forge-std/console.sol";

contract DeployUniFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UniswapV3Factory uniswapV3Factory = new UniswapV3Factory();
        vm.writeFile(
            "deployments/uniswapV3Factory.txt",
            vm.toString(address(uniswapV3Factory))
        );
        console.log(
            "UniswapV3Factory deployed to: %s",
            address(uniswapV3Factory)
        );

        vm.stopBroadcast();
    }
}
