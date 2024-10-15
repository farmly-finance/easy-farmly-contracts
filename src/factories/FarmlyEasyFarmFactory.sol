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
        IFarmlyBollingerBands _farmlyBollingerBands
    );

    function createNewEasyFarm(
        address _token0,
        address _token1,
        uint24 _poolFee,
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        IFarmlyBollingerBands _farmlyBollingerBands
    ) public onlyOwner {
        FarmlyEasyFarm newEasyFarm = new FarmlyEasyFarm(
            _token0,
            _token1,
            _poolFee,
            _shareTokenName,
            _shareTokenSymbol,
            _farmlyBollingerBands
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
