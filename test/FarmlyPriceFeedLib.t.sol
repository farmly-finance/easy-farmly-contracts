pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FarmlyPriceFeedLibHelper} from "./helpers/FarmlyPriceFeedLibHelper.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

contract FarmlyPriceFeedLibTest is Test {
    FarmlyPriceFeedLibHelper public farmlyPriceFeedLibHelper;

    function setUp() public {
        MockPriceFeed token0PriceFeed = new MockPriceFeed(1000 * 1e8);
        MockPriceFeed token1PriceFeed = new MockPriceFeed(1 * 1e8);

        farmlyPriceFeedLibHelper = new FarmlyPriceFeedLibHelper(
            address(token0PriceFeed),
            address(token1PriceFeed)
        );
    }

    function test_token0PriceInToken1() public {
        uint256 price = farmlyPriceFeedLibHelper.exposed_token0PriceInToken1();
        assertEq(price, 1000e18);
    }

    function test_token1PriceInToken0() public {
        uint256 price = farmlyPriceFeedLibHelper.exposed_token1PriceInToken0();
        assertEq(price, 1e15);
    }

    function test_token0Price() public {
        uint256 price = farmlyPriceFeedLibHelper.exposed_token0Price();
        assertEq(price, 1000e18);
    }

    function test_token1Price() public {
        uint256 price = farmlyPriceFeedLibHelper.exposed_token1Price();
        assertEq(price, 1e18);
    }

    function test_tokenPrices() public {
        (uint256 token0Price, uint256 token1Price) = farmlyPriceFeedLibHelper
            .exposed_tokenPrices();
        assertEq(token0Price, 1000e18);
        assertEq(token1Price, 1e18);
    }
}
