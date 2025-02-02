pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {NonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {SwapRouter} from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import {console} from "forge-std/console.sol";

contract DeployNonfungiblePositionManager is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address uniswapV3Factory = vm.parseAddress(
            vm.readFile("deployments/uniswapV3Factory.txt")
        );
        address mockWeth = vm.parseAddress(
            vm.readFile("deployments/mockWeth.txt")
        );

        NonfungiblePositionManager nonfungiblePositionManager = new NonfungiblePositionManager(
                uniswapV3Factory,
                mockWeth,
                address(0)
            );

        SwapRouter swapRouter = new SwapRouter(uniswapV3Factory, mockWeth);

        vm.writeFile(
            "deployments/nonfungiblePositionManager.txt",
            vm.toString(address(nonfungiblePositionManager))
        );
        console.log(
            "NonfungiblePositionManager deployed to: %s",
            address(nonfungiblePositionManager)
        );

        vm.writeFile(
            "deployments/swapRouter.txt",
            vm.toString(address(swapRouter))
        );
        console.log("SwapRouter deployed to: %s", address(swapRouter));
    }
}
