pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import {FarmlyBollingerBands} from "../FarmlyBollingerBands.sol";

contract FarmlyBollingerBandsFactory is Ownable {
    FarmlyBollingerBands[] public farmlyBollingerBands;

    event NewFarmlyBollingerBands(
        address bandAddress,
        uint16 ma,
        uint16 multiplier,
        uint256 period,
        uint256 startTimestamp
    );

    function createNewBand(
        uint16 _ma,
        uint16 _multiplier,
        uint256 _period,
        uint256 _startTimestamp,
        address _token0DataFeed,
        address _token1DataFeed
    ) public onlyOwner {
        require(_startTimestamp > block.timestamp, "TIME");

        FarmlyBollingerBands newBand = new FarmlyBollingerBands(
            _ma,
            _multiplier,
            _period,
            _startTimestamp,
            _token0DataFeed,
            _token1DataFeed
        );

        newBand.transferOwnership(msg.sender);

        farmlyBollingerBands.push(newBand);

        emit NewFarmlyBollingerBands(
            address(newBand),
            _ma,
            _multiplier,
            _period,
            _startTimestamp
        );
    }

    function getBands() public view returns (FarmlyBollingerBands[] memory) {
        return farmlyBollingerBands;
    }

    function bandsLength() public view returns (uint256) {
        return farmlyBollingerBands.length;
    }
}
