pragma solidity >=0.5.0;
import "uni-v3-lib/src/SwapMath.sol";
import "uni-v3-lib/src/TickBitmap.sol";
import "uni-v3-lib/src/TickMath.sol";

library FarmlyZapV3 {
    using TickMath for int24;
    using FullMath for uint256;
    using UnsafeMath for uint256;

    uint256 internal constant MAX_FEE = 1e6;

    error Invalid_Pool();
    error Invalid_Range();

    struct SwapState {
        uint128 liquidity;
        uint256 sqrtPriceX96;
        int24 tick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 sqrtRatioLowerX96;
        uint256 sqrtRatioUpperX96;
        uint256 fee;
        int24 tickSpacing;
    }

    function getOptimalSwap(
        V3PoolCallee pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        view
        returns (
            uint256 amountIn,
            uint256 amountOut,
            bool zeroForOne,
            uint160 sqrtPriceX96
        )
    {
        if (amount0Desired == 0 && amount1Desired == 0) return (0, 0, false, 0);
        if (
            tickLower >= tickUpper ||
            tickLower < TickMath.MIN_TICK ||
            tickUpper > TickMath.MAX_TICK
        ) revert Invalid_Range();

        assembly ("memory-safe") {
            let poolCodeSize := extcodesize(pool)
            if iszero(poolCodeSize) {
                // revert Invalid_Pool()
                mstore(0, 0x01ac05a5)
                revert(0x1c, 0x04)
            }
        }

        SwapState memory state;

        {
            int24 tick;
            (sqrtPriceX96, tick) = pool.sqrtPriceX96AndTick();
            assembly ("memory-safe") {
                // state.tick = tick
                mstore(add(state, 0x40), tick)
            }
        }
        {
            uint128 liquidity = pool.liquidity();
            uint256 fee = pool.fee();
            int24 tickSpacing = pool.tickSpacing();
            assembly ("memory-safe") {
                mstore(state, liquidity)
                mstore(add(state, 0x20), sqrtPriceX96)
                mstore(add(state, 0x60), amount0Desired)
                mstore(add(state, 0x80), amount1Desired)
                mstore(add(state, 0xe0), fee)
                mstore(add(state, 0x100), tickSpacing)
            }
        }
        uint160 sqrtRatioLowerX96 = tickLower.getSqrtRatioAtTick();
        uint160 sqrtRatioUpperX96 = tickUpper.getSqrtRatioAtTick();
        assembly ("memory-safe") {
            mstore(add(state, 0xa0), sqrtRatioLowerX96)
            mstore(add(state, 0xc0), sqrtRatioUpperX96)
        }
        zeroForOne = isZeroForOne(
            amount0Desired,
            amount1Desired,
            sqrtPriceX96,
            sqrtRatioLowerX96,
            sqrtRatioUpperX96
        );

        crossTicks(pool, state, sqrtPriceX96, zeroForOne);

        uint128 liquidityLast;

        uint160 sqrtPriceLastTickX96;

        uint256 amount0LastTick;

        uint256 amount1LastTick;
        assembly ("memory-safe") {
            liquidityLast := mload(state)
            sqrtPriceLastTickX96 := mload(add(state, 0x20))
            amount0LastTick := mload(add(state, 0x60))
            amount1LastTick := mload(add(state, 0x80))
        }
        unchecked {
            if (!zeroForOne) {
                if (sqrtPriceLastTickX96 < sqrtRatioLowerX96) {
                    sqrtPriceX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount1RoundingDown(
                            sqrtPriceLastTickX96,
                            liquidityLast,
                            amount1LastTick.mulDiv(
                                MAX_FEE - state.fee,
                                MAX_FEE
                            ),
                            true
                        );
                    if (sqrtPriceX96 < sqrtRatioLowerX96) {
                        amountIn = amount1Desired;
                    } else {
                        amount1LastTick -= SqrtPriceMath
                            .getAmount1Delta(
                                sqrtPriceLastTickX96,
                                sqrtRatioLowerX96,
                                liquidityLast,
                                true
                            )
                            .mulDiv(MAX_FEE, MAX_FEE - state.fee);
                        amount0LastTick += SqrtPriceMath.getAmount0Delta(
                            sqrtPriceLastTickX96,
                            sqrtRatioLowerX96,
                            liquidityLast,
                            false
                        );
                        sqrtPriceLastTickX96 = sqrtRatioLowerX96;
                        state.sqrtPriceX96 = sqrtPriceLastTickX96;
                        state.amount0Desired = amount0LastTick;
                        state.amount1Desired = amount1LastTick;
                    }
                }
                if (sqrtPriceLastTickX96 >= sqrtRatioLowerX96) {
                    sqrtPriceX96 = solveOptimalOneForZero(state);
                    amountIn =
                        amount1Desired -
                        amount1LastTick +
                        SqrtPriceMath
                            .getAmount1Delta(
                                sqrtPriceX96,
                                sqrtPriceLastTickX96,
                                liquidityLast,
                                true
                            )
                            .mulDiv(MAX_FEE, MAX_FEE - state.fee);
                }
                amountOut =
                    amount0LastTick -
                    amount0Desired +
                    SqrtPriceMath.getAmount0Delta(
                        sqrtPriceX96,
                        sqrtPriceLastTickX96,
                        liquidityLast,
                        false
                    );
            } else {
                if (sqrtPriceLastTickX96 > sqrtRatioUpperX96) {
                    sqrtPriceX96 = SqrtPriceMath
                        .getNextSqrtPriceFromAmount0RoundingUp(
                            sqrtPriceLastTickX96,
                            liquidityLast,
                            amount0LastTick.mulDiv(
                                MAX_FEE - state.fee,
                                MAX_FEE
                            ),
                            true
                        );
                    if (sqrtPriceX96 >= sqrtRatioUpperX96) {
                        amountIn = amount0Desired;
                    } else {
                        amount0LastTick -= SqrtPriceMath
                            .getAmount0Delta(
                                sqrtRatioUpperX96,
                                sqrtPriceLastTickX96,
                                liquidityLast,
                                true
                            )
                            .mulDiv(MAX_FEE, MAX_FEE - state.fee);
                        amount1LastTick += SqrtPriceMath.getAmount1Delta(
                            sqrtRatioUpperX96,
                            sqrtPriceLastTickX96,
                            liquidityLast,
                            false
                        );
                        sqrtPriceLastTickX96 = sqrtRatioUpperX96;
                        state.sqrtPriceX96 = sqrtPriceLastTickX96;
                        state.amount0Desired = amount0LastTick;
                        state.amount1Desired = amount1LastTick;
                    }
                }
                if (sqrtPriceLastTickX96 <= sqrtRatioUpperX96) {
                    sqrtPriceX96 = solveOptimalZeroForOne(state);
                    amountIn =
                        amount0Desired -
                        amount0LastTick +
                        SqrtPriceMath
                            .getAmount0Delta(
                                sqrtPriceX96,
                                sqrtPriceLastTickX96,
                                liquidityLast,
                                true
                            )
                            .mulDiv(MAX_FEE, MAX_FEE - state.fee);
                }
                amountOut =
                    amount1LastTick -
                    amount1Desired +
                    SqrtPriceMath.getAmount1Delta(
                        sqrtPriceX96,
                        sqrtPriceLastTickX96,
                        liquidityLast,
                        false
                    );
            }
        }
    }

    function crossTicks(
        V3PoolCallee pool,
        SwapState memory state,
        uint160 sqrtPriceX96,
        bool zeroForOne
    ) private view {
        int24 tickNext;
        int16 wordPos = type(int16).min;
        uint256 tickWord;

        do {
            (tickNext, wordPos, tickWord) = TickBitmap.nextInitializedTick(
                pool,
                state.tick,
                state.tickSpacing,
                zeroForOne,
                wordPos,
                tickWord
            );
            uint160 sqrtPriceNextX96 = tickNext.getSqrtRatioAtTick();
            uint256 amount0Desired;
            uint256 amount1Desired;

            unchecked {
                if (!zeroForOne) {
                    (sqrtPriceX96, amount1Desired, amount0Desired) = SwapMath
                        .computeSwapStepExactIn(
                            uint160(state.sqrtPriceX96),
                            sqrtPriceNextX96,
                            state.liquidity,
                            state.amount1Desired,
                            state.fee
                        );
                    amount0Desired = state.amount0Desired + amount0Desired;
                    amount1Desired = state.amount1Desired - amount1Desired;
                } else {
                    (sqrtPriceX96, amount0Desired, amount1Desired) = SwapMath
                        .computeSwapStepExactIn(
                            uint160(state.sqrtPriceX96),
                            sqrtPriceNextX96,
                            state.liquidity,
                            state.amount0Desired,
                            state.fee
                        );
                    amount0Desired = state.amount0Desired - amount0Desired;
                    amount1Desired = state.amount1Desired + amount1Desired;
                }
            }

            if (sqrtPriceX96 != sqrtPriceNextX96) break;
            if (
                isZeroForOne(
                    amount0Desired,
                    amount1Desired,
                    sqrtPriceX96,
                    state.sqrtRatioLowerX96,
                    state.sqrtRatioUpperX96
                ) != zeroForOne
            ) {
                break;
            } else {
                int128 liquidityNet = pool.liquidityNet(tickNext);
                assembly ("memory-safe") {
                    liquidityNet := add(
                        zeroForOne,
                        xor(sub(0, zeroForOne), liquidityNet)
                    )
                    mstore(state, add(mload(state), liquidityNet))
                    mstore(add(state, 0x20), sqrtPriceX96)
                    mstore(add(state, 0x40), sub(tickNext, zeroForOne))
                    mstore(add(state, 0x60), amount0Desired)
                    mstore(add(state, 0x80), amount1Desired)
                }
            }
        } while (true);
    }

    function solveOptimalZeroForOne(
        SwapState memory state
    ) private pure returns (uint160 sqrtPriceFinalX96) {
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 sqrtPriceX96;
        unchecked {
            uint256 liquidity;
            uint256 sqrtRatioLowerX96;
            uint256 sqrtRatioUpperX96;
            uint256 fee;
            uint256 FEE_COMPLEMENT;
            assembly ("memory-safe") {
                liquidity := mload(state)
                sqrtPriceX96 := mload(add(state, 0x20))
                sqrtRatioLowerX96 := mload(add(state, 0xa0))
                sqrtRatioUpperX96 := mload(add(state, 0xc0))
                fee := mload(add(state, 0xe0))
                FEE_COMPLEMENT := sub(MAX_FEE, fee)
            }
            {
                uint256 a0;
                assembly ("memory-safe") {
                    let amount0Desired := mload(add(state, 0x60))
                    let liquidityX96 := shl(96, liquidity)
                    a0 := add(
                        amount0Desired,
                        div(
                            mul(MAX_FEE, liquidityX96),
                            mul(FEE_COMPLEMENT, sqrtPriceX96)
                        )
                    )
                    a := sub(a0, div(liquidityX96, sqrtRatioUpperX96))
                    if iszero(gt(a, amount0Desired)) {
                        mstore(0, 0x20236808)
                        revert(0x1c, 0x04)
                    }
                }
                b = a0.mulDiv96(sqrtRatioLowerX96);
                assembly {
                    b := add(div(mul(fee, liquidity), FEE_COMPLEMENT), b)
                }
            }
            {
                uint256 c0 = liquidity.mulDiv96(sqrtPriceX96);
                assembly ("memory-safe") {
                    c0 := add(mload(add(state, 0x80)), c0)
                }
                c =
                    c0 -
                    liquidity.mulDiv96(
                        (MAX_FEE * sqrtRatioLowerX96) / FEE_COMPLEMENT
                    );
                b -= c0.mulDiv(FixedPoint96.Q96, sqrtRatioUpperX96);
            }
            assembly {
                a := shl(1, a)
                c := shl(1, c)
            }
        }
        unchecked {
            uint256 numerator = FullMath.sqrt(b * b + a * c) + b;
            assembly {
                // `numerator` and `a` must be positive so use `div`.
                sqrtPriceFinalX96 := div(shl(96, numerator), a)
            }
        }
        assembly {
            sqrtPriceFinalX96 := xor(
                sqrtPriceX96,
                mul(
                    xor(sqrtPriceX96, sqrtPriceFinalX96),
                    lt(sqrtPriceFinalX96, sqrtPriceX96)
                )
            )
        }
    }

    function solveOptimalOneForZero(
        SwapState memory state
    ) private pure returns (uint160 sqrtPriceFinalX96) {
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 sqrtPriceX96;
        unchecked {
            uint256 liquidity;
            uint256 sqrtRatioLowerX96;
            uint256 sqrtRatioUpperX96;
            uint256 fee;
            uint256 FEE_COMPLEMENT;
            assembly ("memory-safe") {
                liquidity := mload(state)
                sqrtPriceX96 := mload(add(state, 0x20))
                sqrtRatioLowerX96 := mload(add(state, 0xa0))
                sqrtRatioUpperX96 := mload(add(state, 0xc0))
                fee := mload(add(state, 0xe0))
                FEE_COMPLEMENT := sub(MAX_FEE, fee)
            }
            {
                uint256 a0;
                assembly ("memory-safe") {
                    let liquidityX96 := shl(96, liquidity)
                    a0 := add(
                        mload(add(state, 0x60)),
                        div(liquidityX96, sqrtPriceX96)
                    )
                    a := sub(
                        a0,
                        div(
                            mul(MAX_FEE, liquidityX96),
                            mul(FEE_COMPLEMENT, sqrtRatioUpperX96)
                        )
                    )
                }
                b = a0.mulDiv96(sqrtRatioLowerX96);
                assembly {
                    b := sub(b, div(mul(fee, liquidity), FEE_COMPLEMENT))
                }
            }
            {
                uint256 c0 = liquidity.mulDiv96(
                    (MAX_FEE * sqrtPriceX96) / FEE_COMPLEMENT
                );
                uint256 amount1Desired;
                assembly ("memory-safe") {
                    amount1Desired := mload(add(state, 0x80))
                    c0 := add(amount1Desired, c0)
                }
                c = c0 - liquidity.mulDiv96(sqrtRatioLowerX96);
                assembly ("memory-safe") {
                    if iszero(gt(c, amount1Desired)) {
                        mstore(0, 0x20236808)
                        revert(0x1c, 0x04)
                    }
                }
                b -= c0.mulDiv(FixedPoint96.Q96, state.sqrtRatioUpperX96);
            }
            assembly {
                a := shl(1, a)
                c := shl(1, c)
            }
        }
        unchecked {
            uint256 numerator = FullMath.sqrt(b * b + a * c) + b;
            assembly {
                sqrtPriceFinalX96 := sdiv(shl(96, numerator), a)
            }
        }
        assembly {
            sqrtPriceFinalX96 := xor(
                sqrtPriceX96,
                mul(
                    xor(sqrtPriceX96, sqrtPriceFinalX96),
                    gt(sqrtPriceFinalX96, sqrtPriceX96)
                )
            )
        }
    }

    function isZeroForOneInRange(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 sqrtPriceX96,
        uint256 sqrtRatioLowerX96,
        uint256 sqrtRatioUpperX96
    ) private pure returns (bool) {
        unchecked {
            return
                amount0Desired.mulDiv96(sqrtPriceX96).mulDiv96(
                    sqrtPriceX96 - sqrtRatioLowerX96
                ) >
                amount1Desired.mulDiv(
                    sqrtRatioUpperX96 - sqrtPriceX96,
                    sqrtRatioUpperX96
                );
        }
    }

    function isZeroForOne(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 sqrtPriceX96,
        uint256 sqrtRatioLowerX96,
        uint256 sqrtRatioUpperX96
    ) internal pure returns (bool) {
        if (sqrtPriceX96 <= sqrtRatioLowerX96) return false;
        else if (sqrtPriceX96 >= sqrtRatioUpperX96) return true;
        else
            return
                isZeroForOneInRange(
                    amount0Desired,
                    amount1Desired,
                    sqrtPriceX96,
                    sqrtRatioLowerX96,
                    sqrtRatioUpperX96
                );
    }
}
