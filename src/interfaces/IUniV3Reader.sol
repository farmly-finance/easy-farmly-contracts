// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

interface IUniV3Reader {
    /// @notice Factory
    function factory() external view returns (IUniswapV3Factory);

    /// @notice Get price E18
    /// @param _pool Pool address
    /// @return priceE18 Price
    function getPriceE18(address _pool) external view returns (uint256);

    /// @notice Get slot0
    /// @param _pool Pool address
    /// @return sqrtPriceX96 sqrt price
    /// @return tick tick
    /// @return observationIndex observation index
    /// @return observationCardinality observation cardinality
    /// @return observationCardinalityNext observation cardinality next
    /// @return feeProtocol fee protocol
    /// @return unlocked unlocked
    function getSlot0(address _pool)
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice Get pool info
    /// @param _pool Pool address
    /// @return token0 token0
    /// @return token1 token1
    /// @return fee fee
    /// @return tickSpacing tick spacing
    function getPoolInfo(address _pool)
        external
        view
        returns (address token0, address token1, uint24 fee, int24 tickSpacing);
}
