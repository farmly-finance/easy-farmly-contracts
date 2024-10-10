pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IFarmlyPositionManager.sol";

contract FarmlyEasyReader {
    function getPoolInfo(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            address token0,
            address token1,
            uint24 poolFee,
            uint24 tickSpacing
        )
    {
        token0 = positionManager.token0();
        token1 = positionManager.token1();
        poolFee = positionManager.poolFee();
        tickSpacing = positionManager.tickSpacing();
    }

    function getDataFeeds(
        IFarmlyPositionManager positionManager
    ) public view returns (address token0DataFeed, address token1DataFeed) {
        token0DataFeed = positionManager.token0DataFeed();
        token1DataFeed = positionManager.token1DataFeed();
    }

    function getLatest(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            int256 latestLowerPrice,
            int256 latestUpperPrice,
            uint256 latestTimestamp,
            uint256 latestTokenId
        )
    {
        latestLowerPrice = positionManager.latestLowerPrice();
        latestUpperPrice = positionManager.latestUpperPrice();
        latestTimestamp = positionManager.latestTimestamp();
        latestTokenId = positionManager.latestTokenId();
    }

    function getConfig(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            int256 positionThreshold,
            uint256 performanceFee,
            address feeAddress,
            address forwarderAddress,
            uint8 decimals
        )
    {
        positionThreshold = positionManager.positionThreshold();
        performanceFee = positionManager.performanceFee();
        feeAddress = positionManager.feeAddress();
        forwarderAddress = positionManager.forwarderAddress();
        decimals = positionManager.decimals();
    }

    function getUSDValues(
        IFarmlyPositionManager positionManager
    )
        public
        view
        returns (
            uint256 sharePrice,
            uint256 totalUSDValue,
            uint256 positionFeesUSD,
            uint256 positionAmountsUSD,
            uint256 balancesUSD
        )
    {
        sharePrice = positionManager.sharePrice();
        totalUSDValue = positionManager.totalUSDValue();
        (, , positionFeesUSD) = positionManager.positionFeesUSD();
        (, , positionAmountsUSD) = positionManager.positionAmountsUSD();
        (, , balancesUSD) = positionManager.balancesUSD();
    }

    function getTokenBalances(
        IERC20Metadata[] memory tokens,
        address user
    ) public view returns (uint256[] memory balances) {
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].balanceOf(user);
        }
    }

    function getTokenPrices(
        IFarmlyPositionManager positionManager
    ) public view returns (int256 token0Price, int256 token1Price) {
        (address _token0DataFeed, address _token1DataFeed) = getDataFeeds(
            positionManager
        );

        AggregatorV3Interface token0DataFeed = AggregatorV3Interface(
            _token0DataFeed
        );

        AggregatorV3Interface token1DataFeed = AggregatorV3Interface(
            _token1DataFeed
        );

        (, token0Price, , , ) = token0DataFeed.latestRoundData();
        (, token1Price, , , ) = token1DataFeed.latestRoundData();
    }
}
