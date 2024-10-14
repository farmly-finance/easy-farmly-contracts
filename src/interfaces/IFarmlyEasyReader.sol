pragma solidity ^0.8.13;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IFarmlyPositionManager} from "./IFarmlyPositionManager.sol";

interface IFarmlyEasyReader {
    function getPoolInfo(
        IFarmlyPositionManager positionManager
    )
        external
        view
        returns (
            address token0,
            address token1,
            uint24 poolFee,
            uint24 tickSpacing
        );

    function getDataFeeds(
        IFarmlyPositionManager positionManager
    ) external view returns (address token0DataFeed, address token1DataFeed);

    function getLatest(
        IFarmlyPositionManager positionManager
    )
        external
        view
        returns (
            int256 latestLowerPrice,
            int256 latestPrice,
            int256 latestUpperPrice,
            uint256 latestTimestamp,
            uint256 latestTokenId
        );

    function getConfig(
        IFarmlyPositionManager positionManager
    )
        external
        view
        returns (
            int256 positionThreshold,
            uint256 performanceFee,
            address feeAddress,
            address forwarderAddress,
            uint8 decimals
        );

    function getUSDValues(
        IFarmlyPositionManager positionManager
    )
        external
        view
        returns (
            uint256 sharePrice,
            uint256 totalUSDValue,
            uint256 positionFeesUSD,
            uint256 positionAmountsUSD,
            uint256 balancesUSD
        );

    function getTokenBalances(
        IERC20Metadata[] calldata tokens,
        address user
    ) external view returns (uint256[] memory balances);

    function getTokenAllowances(
        IERC20Metadata[] memory tokens,
        address spender,
        address user
    ) external view returns (uint256[] memory allowances);

    function getTokenPrices(
        IFarmlyPositionManager positionManager
    )
        external
        view
        returns (
            int256 token0Price,
            int256 token1Price,
            uint8 token0PriceDecimals,
            uint8 token1PriceDecimals
        );

    function getSlot0(
        IFarmlyPositionManager positionManager
    )
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

    function shareToAmounts(
        IFarmlyPositionManager positionManager,
        uint256 amount
    ) external view returns (uint256 amount0, uint256 amount1);
}
