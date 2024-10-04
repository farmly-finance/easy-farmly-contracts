pragma solidity ^0.8.13;

import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";

import {FarmlyUniV3Executor} from "./FarmlyUniV3Executor.sol";

import "./interfaces/IFarmlyBollingerBands.sol";

contract FarmlyPositionManager is
    AutomationCompatibleInterface,
    Ownable,
    ERC20,
    FarmlyUniV3Executor
{
    AggregatorV3Interface public token0DataFeed =
        AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

    AggregatorV3Interface public token1DataFeed =
        AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);

    IFarmlyBollingerBands public farmlyBollingerBands =
        IFarmlyBollingerBands(0x26517Fe4bAdA989d7574410E6909431C90ce968E);

    int256 public latestUpperPrice;
    int256 public latestLowerPrice;
    uint256 public latestTimestamp;

    int256 public positonThreshold = 500; // 500, %1 = 1000

    address public forwarderAddress;

    modifier onlyForwarder() {
        require(msg.sender == forwarderAddress, "NOT FORWARDER");
        _;
    }
    constructor() ERC20("Test Token", "TEST") {
        latestLowerPrice = farmlyBollingerBands.latestLowerBand();
        latestUpperPrice = farmlyBollingerBands.latestUpperBand();
        latestTimestamp =
            farmlyBollingerBands.nextPeriodStartTimestamp() -
            farmlyBollingerBands.period();
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        uint256 nextTimestamp = latestTimestamp + farmlyBollingerBands.period();
        if (block.timestamp > nextTimestamp) {
            if (
                nextTimestamp != farmlyBollingerBands.nextPeriodStartTimestamp()
            ) {
                int256 latestUpperBand = farmlyBollingerBands.latestUpperBand();
                int256 latestLowerBand = farmlyBollingerBands.latestLowerBand();
                upkeepNeeded = isUpkeepNeeded(latestUpperBand, latestLowerBand);
            }
        }
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function isUpkeepNeeded(
        int256 upperBand,
        int256 lowerBand
    ) internal view returns (bool) {
        int256 upperThreshold = (latestUpperPrice * positonThreshold) / 1e5;
        int256 lowerThreshold = (latestLowerPrice * positonThreshold) / 1e5;

        bool upperNeeded = (latestUpperPrice - upperThreshold < upperBand) ||
            (latestUpperPrice + upperThreshold > upperBand);

        bool lowerNeeded = (latestLowerPrice - lowerThreshold < lowerBand) ||
            (latestLowerPrice + lowerThreshold > lowerBand);

        return upperNeeded || lowerNeeded;
    }

    function decodeData()
        external
        view
        returns (int256, int256, uint256, bytes memory)
    {
        int256 latestUpperBand = farmlyBollingerBands.latestUpperBand();
        int256 latestLowerBand = farmlyBollingerBands.latestLowerBand();
        uint256 nextTimestamp = latestTimestamp + farmlyBollingerBands.period();

        bytes memory dataa = abi.encode(
            latestUpperBand,
            latestLowerBand,
            nextTimestamp
        );
        (int256 upperBand, int256 lowerBand, uint256 timestamp) = abi.decode(
            dataa,
            (int256, int256, uint256)
        );

        return (upperBand, lowerBand, timestamp, dataa);
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override onlyForwarder {
        int256 upperBand = farmlyBollingerBands.latestUpperBand();
        int256 lowerBand = farmlyBollingerBands.latestLowerBand();
        if (isUpkeepNeeded(upperBand, lowerBand)) {
            uint256 timestamp = latestTimestamp + farmlyBollingerBands.period();

            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint128 liquidity,
                ,
                ,
                ,

            ) = nonfungiblePositionManager.positions(latestTokenId);

            (uint256 amount0, uint256 amount1) = decreasePosition(liquidity);

            PositionInfo memory positionInfo = PositionInfo(
                getTick(lowerBand),
                getTick(upperBand),
                amount0,
                amount1
            );

            (
                SwapInfo memory swapInfo,
                uint256 amount0Add,
                uint256 amount1Add
            ) = getAmountsForAdd(positionInfo);

            swapExactInput(
                swapInfo.tokenIn,
                swapInfo.tokenOut,
                swapInfo.amountIn
            );

            token0.approve(address(nonfungiblePositionManager), amount0Add);
            token1.approve(address(nonfungiblePositionManager), amount1Add);

            (uint256 tokenId, , ) = mintPosition(
                positionInfo,
                amount0Add,
                amount1Add
            );

            latestUpperPrice = upperBand;
            latestLowerPrice = lowerBand;
            latestTimestamp = timestamp;
            latestTokenId = tokenId;
        }
        /*
        
        TODO:: 

        MEVCUT POZİSYONU ÇEK VE YENİ FİYAT ARALIKLARINA GÖRE POZİSYON OLUŞTUR.

        YENİ ARALIK İÇİN SWAP GEREKİYORSA POZİSYONU OLUŞTURMADAN ÖNCE SWAP İŞLEMİNİ YAP.
        
         */
    }

    function deposit(uint256 amount0, uint256 amount1) public {
        uint256 _usdValueBefore = totalUSDValue();

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        PositionInfo memory positionInfo = PositionInfo(
            getTick(latestLowerPrice),
            getTick(latestUpperPrice),
            amount0,
            amount1
        );

        (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        ) = getAmountsForAdd(positionInfo);

        swapExactInput(swapInfo.tokenIn, swapInfo.tokenOut, swapInfo.amountIn);

        token0.approve(address(nonfungiblePositionManager), amount0Add);
        token1.approve(address(nonfungiblePositionManager), amount1Add);

        if (latestTokenId == 0) {
            (uint256 tokenId, , ) = mintPosition(
                positionInfo,
                amount0Add,
                amount1Add
            );
            latestTokenId = tokenId;
        } else {
            increasePosition(amount0Add, amount1Add);
        }

        (int256 token0Price, int256 token1Price) = getLatestPrices();
        int256 userDepositUSD = ((int256(amount0) * token0Price) / 1e18) +
            ((int256(amount1) * token1Price) / 1e6);

        _mint(
            msg.sender,
            totalSupply() == 0
                ? uint256(userDepositUSD)
                : FarmlyFullMath.mulDiv(
                    uint256(userDepositUSD),
                    totalSupply(),
                    _usdValueBefore
                )
        );

        /*
         * PERFORMANCE FEE
         */
    }

    function withdraw(uint256 amount) public {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(latestTokenId);

        uint256 liquidityToWithdraw = (liquidity * amount) / totalSupply();

        _burn(msg.sender, amount);

        (uint256 amount0, uint256 amount1) = decreasePosition(
            uint128(liquidityToWithdraw)
        );

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        /*
         * PERFORMANCE FEE
         */
    }

    function getLatestPrices()
        internal
        view
        returns (int256 token0Price, int256 token1Price)
    {
        (, token0Price, , , ) = token0DataFeed.latestRoundData();
        (, token1Price, , , ) = token1DataFeed.latestRoundData();
    }

    function totalUSDValue() public view returns (uint256 usdValue) {
        if (latestTokenId == 0) {
            usdValue = 0;
        } else {
            (uint256 amount0, uint256 amount1) = positionAmounts();
            (int256 token0Price, int256 token1Price) = getLatestPrices();
            uint256 positionValue = ((amount0 * uint256(token0Price)) / 1e18) +
                ((amount1 * uint256(token1Price)) / 1e6);

            uint256 token0Balance = token0.balanceOf(address(this));
            uint256 token1Balance = token1.balanceOf(address(this));

            uint256 balancesValue = ((token0Balance * uint256(token0Price)) /
                1e18) + ((token1Balance * uint256(token1Price)) / 1e6);

            usdValue = positionValue + balancesValue;
        }
    }

    function sharePrice() public view returns (uint256) {
        return (totalUSDValue() * 1e8) / totalSupply();
    }

    function setLatestBollingers(int256 lower, int256 upper) public onlyOwner {
        latestLowerPrice = lower;
        latestUpperPrice = upper;
    }

    function emergency_withdraw() public onlyOwner {
        /*
        will be removed
         */
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(latestTokenId);

        decreasePosition(liquidity);

        token0.transfer(owner(), token0.balanceOf(address(this)));
        token1.transfer(owner(), token1.balanceOf(address(this)));
    }

    function setForwarder(address _forwarderAddress) public onlyOwner {
        forwarderAddress = _forwarderAddress;
    }

    function setPositionThreshold(int256 _threshold) public onlyOwner {
        positonThreshold = _threshold;
    }
}
