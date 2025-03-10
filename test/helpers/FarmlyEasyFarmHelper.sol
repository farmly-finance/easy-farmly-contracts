pragma solidity ^0.8.13;

import {FarmlyEasyFarm} from "../../src/FarmlyEasyFarm.sol";

contract FarmlyEasyFarmHelper is FarmlyEasyFarm {
    constructor(
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        address _strategy,
        address _executor,
        address _token0,
        address _token1,
        address _token0DataFeed,
        address _token1DataFeed
    )
        FarmlyEasyFarm(
            _shareTokenName,
            _shareTokenSymbol,
            _strategy,
            _executor,
            _token0,
            _token1,
            _token0DataFeed,
            _token1DataFeed
        )
    {}

    function exposed_tokensUSDValue(
        uint256 _amount0,
        uint256 _amount1
    )
        external
        view
        returns (uint256 token0USD, uint256 token1USD, uint256 totalUSD)
    {
        return tokensUSDValue(_amount0, _amount1);
    }
}
