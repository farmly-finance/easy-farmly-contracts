pragma solidity 0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockWETH} from "../test/mocks/MockWETH.sol";
import {console} from "forge-std/console.sol";

contract DeployMocks is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockWETH mockWeth = new MockWETH();
        vm.writeFile(
            "deployments/mockWeth.txt",
            vm.toString(address(mockWeth))
        );
        console.log("MockWETH deployed to: %s", address(mockWeth));

        vm.stopBroadcast();
    }
}
