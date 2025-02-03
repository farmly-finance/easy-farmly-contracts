pragma solidity ^0.8.13;

import {FarmlyPriceFeedLib} from "../../src/libraries/FarmlyPriceFeedLib.sol";

contract FarmlyPriceFeedLibHelper is FarmlyPriceFeedLib {
    constructor(address _token0DataFeed, address _token1DataFeed)
        FarmlyPriceFeedLib(_token0DataFeed, _token1DataFeed)
    {}

    function exposed_token0PriceInToken1() external view returns (uint256) {
        return _token0PriceInToken1();
    }

    function exposed_token1PriceInToken0() external view returns (uint256) {
        return _token1PriceInToken0();
    }

    function exposed_token0Price() external view returns (uint256) {
        return _token0Price();
    }

    function exposed_token1Price() external view returns (uint256) {
        return _token1Price();
    }

    function exposed_tokenPrices() external view returns (uint256 token0Price, uint256 token1Price) {
        return _tokenPrices();
    }
}
