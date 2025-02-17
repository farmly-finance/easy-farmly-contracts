pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FarmlyUniV3Executor} from "../src/executors/FarmlyUniV3Executor.sol";

contract DeployFarmlyUniV3Executor is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address uniswapV3Factory = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        address nonfungiblePositionManager = 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2;
        address swapRouter = 0x7abD0faBE1Da48F2486b951E2b6B6f3Ac07fd98C;
        address token0 = 0xb7174F8B1927e49df49af654E76f5a7C180183CB;
        address token1 = 0xbb010C74c1441f152051951165B5031F618Ddae3;
        uint24 poolFee = 500;

        FarmlyUniV3Executor executor = new FarmlyUniV3Executor(
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            token0,
            token1,
            poolFee
        );

        vm.writeFile(
            "./deployments/FarmlyUniV3Executor.txt",
            vm.toString(address(executor))
        );

        vm.stopBroadcast();
    }
}
