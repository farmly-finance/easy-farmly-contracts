pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IPositionInfo} from "./IPositionInfo.sol";

interface IFarmlyUniV3Executor is IPositionInfo {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function poolFee() external view returns (uint24);

    function tickSpacing() external view returns (uint24);

    function latestTokenId() external view returns (uint256);

    function positionAmounts()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function positionFees()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function pool() external view returns (IUniswapV3Pool pool);

    function nonfungiblePositionManager()
        external
        view
        returns (INonfungiblePositionManager nonfungiblePositionManager);

    function getAmountsForAdd(
        PositionInfo memory positionInfo
    )
        external
        view
        returns (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        );

    function onPerformUpkeep(
        uint256 _lowerPrice,
        uint256 _upperPrice
    )
        external
        returns (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0Added,
            uint256 amount1Added
        );

    function onDeposit(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external returns (uint256 amount0Collected, uint256 amount1Collected);

    function onWithdraw(
        uint256 shareAmount,
        uint256 totalSupply,
        address to,
        bool isMinimizeTrading,
        bool zeroForOne
    )
        external
        returns (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        );
}
