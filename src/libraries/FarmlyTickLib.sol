pragma solidity 0.8.19;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {SqrtPriceX96} from "./SqrtPriceX96.sol";

library FarmlyTickLib {
    function nearestPrice(
        uint256 price,
        uint8 token0Decimal,
        uint8 token1Decimal,
        uint24 tickSpacing
    ) internal view returns (uint256) {
        return
            decodeTick(
                getTick(price, token0Decimal, token1Decimal, tickSpacing),
                token0Decimal,
                token1Decimal
            );
    }

    function getTick(
        uint256 price,
        uint8 token0Decimal,
        uint8 token1Decimal,
        uint24 tickSpacing
    ) internal view returns (int24) {
        return
            SqrtPriceX96.nearestUsableTick(
                TickMath.getTickAtSqrtRatio(
                    SqrtPriceX96.encodeSqrtPriceX96(
                        price,
                        token0Decimal,
                        token1Decimal
                    )
                ),
                tickSpacing
            );
    }

    function decodeTick(
        int24 tick,
        uint8 token0Decimal,
        uint8 token1Decimal
    ) internal view returns (uint256) {
        return
            SqrtPriceX96.decodeSqrtPriceX96(
                TickMath.getSqrtRatioAtTick(tick),
                token0Decimal,
                token1Decimal
            );
    }
}
