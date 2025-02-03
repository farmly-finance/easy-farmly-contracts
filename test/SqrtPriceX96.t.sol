pragma solidity 0.8.19;

import {SqrtPriceX96} from "../src/libraries/SqrtPriceX96.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract SqrtPriceX96Test is Test {
    uint256 price = 1000e18;
    uint256 token0Decimal = 18;
    uint256 token1Decimal = 6;

    function test_encodeSqrtPriceX96() public {
        uint256 sqrtPriceX96 = SqrtPriceX96.encodeSqrtPriceX96(price, token0Decimal, token1Decimal);

        assertEq(sqrtPriceX96, 2505352955026066883383046);
    }

    function test_decodeSqrtPriceX96() public {
        uint256 decodedPrice = SqrtPriceX96.decodeSqrtPriceX96(2505352955026066883383046, token0Decimal, token1Decimal);
        assertEq(decodedPrice, 999950883000000000000);

        assertEq(
            SqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 18, 18),
            340282366920938463463374607431768211455999999999534338712
        );
        assertEq(SqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 1, 18), 3402823669209384634633746074317682114559);
        assertEq(
            SqrtPriceX96.decodeSqrtPriceX96(type(uint160).max, 18, 1),
            34028236692093846346337460743176821145599999999953433871200000000000000000
        );
    }
}
