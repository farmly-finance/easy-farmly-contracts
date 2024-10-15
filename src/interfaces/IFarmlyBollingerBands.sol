// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IFarmlyBollingerBands {
    function token0DataFeed() external view returns (address);
    function token1DataFeed() external view returns (address);
    function ma() external view returns (uint16);
    function multiplier() external view returns (uint16);
    function period() external view returns (uint256);
    function prices(uint256) external view returns (uint256);
    function pricesLength() external view returns (uint256);
    function nextPeriodStartTimestamp() external view returns (uint256);
    function latestUpperBand() external view returns (uint256);
    function latestSma() external view returns (uint256);
    function latestLowerBand() external view returns (uint256);
    function forwarderAddress() external view returns (address);
    function setForwarder(address _forwarderAddress) external;

    event NewBand(
        uint256 price,
        uint256 upperBand,
        uint256 sma,
        uint256 lowerBand,
        uint256 timestamp
    );
}
