pragma solidity ^0.8.13;

contract MockPriceFeed {
    int256 public price;

    constructor(int256 _price) {
        price = _price;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = price;
        startedAt = 1;
        updatedAt = 1;
        answeredInRound = 1;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
}
