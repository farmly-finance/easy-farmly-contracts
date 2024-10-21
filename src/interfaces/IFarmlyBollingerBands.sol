pragma solidity ^0.8.13;

interface IFarmlyBollingerBands {
    // Events
    event NewBand(
        uint256 price,
        uint256 upperBand,
        uint256 sma,
        uint256 lowerBand,
        uint256 timestamp
    );

    // Public view functions
    function token0DataFeed() external view returns (address);
    function token1DataFeed() external view returns (address);
    function ma() external view returns (uint16);
    function multiplier() external view returns (uint16);
    function period() external view returns (uint256);
    function pricesLength() external view returns (uint256);
    function nextPeriodStartTimestamp() external view returns (uint256);
    function latestUpperBand() external view returns (uint256);
    function latestSma() external view returns (uint256);
    function latestLowerBand() external view returns (uint256);

    // Chainlink Keepers functions
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}
