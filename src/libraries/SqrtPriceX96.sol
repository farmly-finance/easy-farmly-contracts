pragma solidity 0.8.19;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {LibFullMath} from "src/libraries/LibFullMath.sol";
import {LibFixedPoint96} from "src/libraries/LibFixedPoint96.sol";

library SqrtPriceX96 {
    using SafeCastUpgradeable for uint256;

    function decodeSqrtPriceX96(
        uint160 _sqrtPriceX96,
        uint256 _token0Decimals,
        uint256 _token1Decimals
    ) internal pure returns (uint256 _priceE18) {
        uint256 _non18Price = LibFullMath.mulDiv(
            uint256(_sqrtPriceX96) * 1e18,
            _sqrtPriceX96,
            LibFixedPoint96.Q96 ** 2
        );
        return
            (_non18Price * (10 ** _token0Decimals)) / (10 ** _token1Decimals);
    }

    function encodeSqrtPriceX96(
        uint256 _priceE18,
        uint256 _token0Decimals,
        uint256 _token1Decimals
    ) internal pure returns (uint160 _sqrtPriceX96) {
        uint256 _sqrt = FixedPointMathLib.sqrt(
            (_priceE18 * (10 ** _token1Decimals)) / (10 ** _token0Decimals)
        );
        return ((_sqrt * LibFixedPoint96.Q96) / 1e9).toUint160();
    }
}
