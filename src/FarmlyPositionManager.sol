pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";

struct Log {
    uint256 index; // Index of the log in the block
    uint256 timestamp; // Timestamp of the block containing the log
    bytes32 txHash; // Hash of the transaction containing the log
    uint256 blockNumber; // Number of the block containing the log
    bytes32 blockHash; // Hash of the block containing the log
    address source; // Address of the contract that emitted the log
    bytes32[] topics; // Indexed topics of the log
    bytes data; // Data of the log
}

interface ILogAutomation {
    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

contract FarmlyPositionManager is ILogAutomation {
    int256 public latestUpperPrice;
    int256 public latestLowerPrice;
    uint256 public latestTimestamp;

    int256 public positonThreshold = 500; // %1 = 1000

    function checkLog(
        Log calldata log,
        bytes memory
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (, int256 upperBand, , int256 lowerBand, uint256 timestamp) = abi
            .decode(log.data, (int256, int256, int256, int256, uint256));

        upkeepNeeded = isUpkeepNeeded(upperBand, lowerBand);
        performData = abi.encode(upperBand, lowerBand, timestamp);
    }

    function isUpkeepNeeded(
        int256 upperBand,
        int256 lowerBand
    ) internal view returns (bool) {
        int256 upperThreshold = (latestUpperPrice * positonThreshold) / 1e6;
        int256 lowerThreshold = (latestLowerPrice * positonThreshold) / 1e6;

        bool upperNeeded = (latestUpperPrice - upperThreshold < upperBand) ||
            (latestUpperPrice + upperThreshold > upperBand);

        bool lowerNeeded = (latestLowerPrice - lowerThreshold < lowerBand) ||
            (latestLowerPrice + lowerThreshold > lowerBand);

        return upperNeeded || lowerNeeded;
    }

    function deposit(uint256 amount0, uint256 amount1) public {
        /*
         * KULLANICI DEPOSİT EDER
         * POZİSYONA EKLEME YAPAR
         * SHARE MINT EDILIR
         * KULLANICIYA VERILIR
         * PERFORMANCE FEE ALINIR (KAZANILAN FEEDEN)
         */
    }

    function withdraw() public {
        /*
         * KULLANICI WITHDRAW YAPAR
         * SHARE YAKILIR
         * PAYI UNISWAPTAN ÇEKILIR
         * KULLANICIYA GÖNDERILIR
         * PERFORMANCE FEE ALINIR (KAZANILAN FEEDEN)
         */
    }

    function performUpkeep(bytes calldata performData) external override {
        (int256 upperBand, int256 lowerBand, uint256 timestamp) = abi.decode(
            performData,
            (int256, int256, uint256)
        );

        latestUpperPrice = upperBand;
        latestLowerPrice = lowerBand;
        latestTimestamp = timestamp;

        /*
        
        TODO:: 

        MEVCUT POZİSYONU ÇEK VE YENİ FİYAT ARALIKLARINA GÖRE POZİSYON OLUŞTUR.

        YENİ ARALIK İÇİN SWAP GEREKİYORSA POZİSYONU OLUŞTURMADAN ÖNCE SWAP İŞLEMİNİ YAP.
        
         */
    }
}
