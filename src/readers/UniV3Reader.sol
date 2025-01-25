pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../interfaces/IUniV3Reader.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SqrtPriceX96} from "../libraries/SqrtPriceX96.sol";

contract UniV3Reader is IUniV3Reader {
    /// @inheritdoc IUniV3Reader
    IUniswapV3Factory public override factory =
        IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);

    /// @inheritdoc IUniV3Reader
    function getPriceE18(
        address _pool
    ) external view override returns (uint256) {
        (uint160 sqrtPriceX96, , , , , , ) = getSlot0(_pool);
        (address token0, address token1, , ) = getPoolInfo(_pool);

        uint256 token0Decimals = IERC20Metadata(token0).decimals();
        uint256 token1Decimals = IERC20Metadata(token1).decimals();

        return
            SqrtPriceX96.decodeSqrtPriceX96(
                sqrtPriceX96,
                token0Decimals,
                token1Decimals
            );
    }

    /// @inheritdoc IUniV3Reader
    function getSlot0(
        address _pool
    )
        public
        view
        override
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return IUniswapV3Pool(_pool).slot0();
    }

    /// @inheritdoc IUniV3Reader
    function getPoolInfo(
        address _pool
    )
        public
        view
        override
        returns (address token0, address token1, uint24 fee, int24 tickSpacing)
    {
        token0 = IUniswapV3Pool(_pool).token0();
        token1 = IUniswapV3Pool(_pool).token1();
        fee = IUniswapV3Pool(_pool).fee();
        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();
    }
}
