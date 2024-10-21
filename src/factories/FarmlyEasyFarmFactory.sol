pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";

import {FarmlyEasyFarm} from "../FarmlyEasyFarm.sol";

import "../interfaces/IFarmlyBollingerBands.sol";

contract FarmlyEasyFarmFactory is Ownable {
    FarmlyEasyFarm[] public farmlyEasyFarms;

    event NewFarmlyEasyFarm(
        address farmAddress,
        string _shareTokenName,
        string _shareTokenSymbol,
        address _farmlyBollingerBands
    );

    function createNewEasyFarm(
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        uint256 _maximumCapacity,
        address _farmlyBollingerBands,
        address _farmlyUniV3Executor
    ) public onlyOwner {
        FarmlyEasyFarm newEasyFarm = new FarmlyEasyFarm(
            _shareTokenName,
            _shareTokenSymbol,
            _maximumCapacity,
            _farmlyBollingerBands,
            _farmlyUniV3Executor
        );

        newEasyFarm.transferOwnership(msg.sender);

        farmlyEasyFarms.push(newEasyFarm);

        emit NewFarmlyEasyFarm(
            address(newEasyFarm),
            _shareTokenName,
            _shareTokenSymbol,
            _farmlyBollingerBands
        );
    }

    function getFarms() public view returns (FarmlyEasyFarm[] memory) {
        return farmlyEasyFarms;
    }

    function farmsLength() public view returns (uint256) {
        return farmlyEasyFarms.length;
    }
}
