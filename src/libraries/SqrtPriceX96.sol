pragma solidity 0.8.19;

import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FarmlyFullMath} from "./FarmlyFullMath.sol";

library SqrtPriceX96 {
    int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;
    int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    using SafeCast for uint256;

    function decodeSqrtPriceX96(
        uint160 _sqrtPriceX96,
        uint256 _token0Decimals,
        uint256 _token1Decimals
    ) internal pure returns (uint256 _priceE18) {
        uint256 _non18Price = FarmlyFullMath.mulDiv(
            uint256(_sqrtPriceX96) * 1e18,
            _sqrtPriceX96,
            FixedPoint96.Q96 ** 2
        );
        return
            (_non18Price * (10 ** _token0Decimals)) / (10 ** _token1Decimals);
    }

    function encodeSqrtPriceX96(
        uint256 _priceE18,
        uint256 _token0Decimals,
        uint256 _token1Decimals
    ) internal pure returns (uint160 _sqrtPriceX96) {
        uint256 _sqrt = FarmlyFullMath.sqrt(
            (_priceE18 * (10 ** _token1Decimals)) / (10 ** _token0Decimals)
        );
        return uint160((_sqrt * FixedPoint96.Q96) / 1e9);
    }

    function ABDKMath64x64div(
        int128 x,
        int128 y
    ) internal pure returns (int128) {
        unchecked {
            require(y != 0);
            int256 result = (int256(x) << 64) / y;
            require(result >= MIN_64x64 && result <= MAX_64x64);
            return int128(result);
        }
    }

    function divRound(
        int128 x,
        int128 y
    ) internal pure returns (int128 result) {
        int128 quot = ABDKMath64x64div(x, y);
        result = quot >> 64;

        // Check if remainder is greater than 0.5
        if (quot % 2 ** 64 >= 0x8000000000000000) {
            result += 1;
        }
    }

    function nearestUsableTick(
        int24 tick_,
        uint24 tickSpacing
    ) internal pure returns (int24 result) {
        result =
            int24(divRound(int128(tick_), int128(int24(tickSpacing)))) *
            int24(tickSpacing);

        if (result < TickMath.MIN_TICK) {
            result += int24(tickSpacing);
        } else if (result > TickMath.MAX_TICK) {
            result -= int24(tickSpacing);
        }
    }
}
