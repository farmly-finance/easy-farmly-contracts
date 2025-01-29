pragma solidity ^0.8.13;

import "./base/IFarmlyBaseExecutor.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

interface IFarmlyUniV3Executor is IFarmlyBaseExecutor {
    /// @notice Factory
    function factory() external view returns (IUniswapV3Factory);
    /// @notice Nonfungible position manager
    function nonfungiblePositionManager()
        external
        view
        returns (INonfungiblePositionManager);
    /// @notice Swap router
    function swapRouter() external view returns (ISwapRouter);
    /// @notice Pool fee
    function poolFee() external view returns (uint24);
    /// @notice Pool
    function pool() external view returns (IUniswapV3Pool);
    /// @notice Tick spacing
    function tickSpacing() external view returns (uint24);
    /// @notice Latest token id
    function latestTokenId() external view returns (uint256);
}
