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

    function getTokenPrices(
        IFarmlyPositionManager positionManager
    ) external view returns (int256 token0Price, int256 token1Price);
}
