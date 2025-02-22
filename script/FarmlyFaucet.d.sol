pragma solidity ^0.8.13;

import "../src/FarmlyFaucet.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract FarmlyFaucetScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FarmlyFaucet.Token[] memory tokens = new FarmlyFaucet.Token[](3);

        // tWETH
        tokens[0] = FarmlyFaucet.Token({
            token: IERC20(0xb7174F8B1927e49df49af654E76f5a7C180183CB),
            amount: 0.5e18
        });

        // tUSDC
        tokens[1] = FarmlyFaucet.Token({
            token: IERC20(0xbb010C74c1441f152051951165B5031F618Ddae3),
            amount: 200e18
        });

        // tBTC
        tokens[2] = FarmlyFaucet.Token({
            token: IERC20(0xe9Ce413353e4A285F9EFfe150e1Cba229B1947AB),
            amount: 0.1e18
        });

        FarmlyFaucet faucet = new FarmlyFaucet(tokens);

        console.log("Faucet deployed at", address(faucet));

        vm.writeFile(
            "./deployments/FarmlyFaucet.txt",
            vm.toString(address(faucet))
        );

        tokens[0].token.transfer(address(faucet), tokens[0].amount * 100);
        tokens[1].token.transfer(address(faucet), tokens[1].amount * 100);
        tokens[2].token.transfer(address(faucet), tokens[2].amount * 100);

        vm.stopBroadcast();
    }
}
