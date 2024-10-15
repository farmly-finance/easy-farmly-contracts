pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IFarmlyEasyFarm} from "../src/interfaces/IFarmlyEasyFarm.sol";
import {FarmlyEasyReader} from "../src/FarmlyEasyReader.sol";

contract FarmlyEasyReaderTest is Test {
    FarmlyEasyReader public farmlyEasyReader;
    address public tester = address(this);
    IFarmlyEasyFarm public farmlyEasyFarm =
        IFarmlyEasyFarm(0x6F7c5Ea72D041d843E9671f958233102250fADDC);

    function setUp() public {
        farmlyEasyReader = new FarmlyEasyReader();
    }

    function test_ShareToAmounts() public {
        console.log("ahauuhauha");

        (uint256 amount0, uint256 amount1) = farmlyEasyReader.shareToAmounts(
            farmlyEasyFarm,
            10e8
        );

        console.log(amount0);
        console.log(amount1);
    }
}
