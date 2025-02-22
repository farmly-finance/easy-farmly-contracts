pragma solidity 0.8.19;

import {FarmlyTickLib} from "../src/libraries/FarmlyTickLib.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract FarmlyTickLibTest is Test {
    uint256 price = 1000 * 1e18;
    uint8 token0Decimal = 18;
    uint8 token1Decimal = 6;
    uint24 tickSpacing = 10;

    function test_getTick_success() public {
        int24 tick = FarmlyTickLib.getTick(
            price,
            token0Decimal,
            token1Decimal,
            tickSpacing
        );

        assertEq(tick, -207240);
    }

    function test_getTick_failure() public {
        vm.expectRevert();
        FarmlyTickLib.getTick(0, token0Decimal, token1Decimal, tickSpacing);

        vm.expectRevert();
        FarmlyTickLib.getTick(price, token0Decimal, token1Decimal, 0);
    }

    function test_decodeTick() public {
        uint256 decodedPrice = FarmlyTickLib.decodeTick(
            -207250,
            token0Decimal,
            token1Decimal
        );

        assertEq(decodedPrice, 999302261000000000000);
    }

    function test_nearestPrice() public {
        uint256 nearestPrice = FarmlyTickLib.nearestPrice(
            price,
            token0Decimal,
            token1Decimal,
            tickSpacing
        );
        assertEq(nearestPrice, 1000302013000000000000);
    }
}
