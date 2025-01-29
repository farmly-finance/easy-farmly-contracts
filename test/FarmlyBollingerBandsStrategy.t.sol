pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FarmlyBollingerBandsStrategy} from "../src/strategies/FarmlyBollingerBandsStrategy.sol";

contract FarmlyBollingerBandsStrategyTest is Test {
    FarmlyBollingerBandsStrategy public strategy;

    function setUp() public {
        strategy = new FarmlyBollingerBandsStrategy(
            address(0),
            address(0),
            10,
            2,
            100,
            100
        );
    }

    function test_isRebalanceNeeded() public {
        uint256 lowerPrice = 100;
        uint256 upperPrice = 100;
        bool isRebalanceNeeded = strategy.isRebalanceNeeded(
            lowerPrice,
            upperPrice
        );
        assert(isRebalanceNeeded);
    }
}
