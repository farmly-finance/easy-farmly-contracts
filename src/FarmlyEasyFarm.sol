pragma solidity ^0.8.13;

import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {FarmlyTransferHelper} from "./libraries/FarmlyTransferHelper.sol";

import {FarmlyUniV3Executor} from "./FarmlyUniV3Executor.sol";

import "./interfaces/IFarmlyBollingerBands.sol";

contract FarmlyEasyFarm is
    AutomationCompatibleInterface,
    Ownable,
    ERC20,
    FarmlyUniV3Executor
{
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;

    IFarmlyBollingerBands public farmlyBollingerBands;

    AggregatorV3Interface public token0DataFeed;

    AggregatorV3Interface public token1DataFeed;

    int256 public latestUpperPrice;
    int256 public latestLowerPrice;
    uint256 public latestTimestamp;

    int256 public positionThreshold; // %1 = 1000
    uint256 public performanceFee; // %1 = 1000
    address public feeAddress;

    address public forwarderAddress;

    event Deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 shareAmount,
        uint256 depositUSD
    );

    event Withdraw(uint256 amount0, uint256 amount1, uint256 shareAmount);

    event PerformPosition(
        uint256 amount0Added,
        uint256 amount1Added,
        int256 upperPrice,
        int256 lowerPrice,
        uint256 sharePrice,
        uint256 timestamp,
        uint256 tokenId
    );

    modifier onlyForwarder() {
        require(msg.sender == forwarderAddress, "NOT FORWARDER");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        uint24 _poolFee,
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        IFarmlyBollingerBands _farmlyBollingerBands
    )
        ERC20(_shareTokenName, _shareTokenSymbol)
        FarmlyUniV3Executor(_token0, _token1, _poolFee)
    {
        token0DataFeed = AggregatorV3Interface(
            _farmlyBollingerBands.token0DataFeed()
        );
        token1DataFeed = AggregatorV3Interface(
            _farmlyBollingerBands.token1DataFeed()
        );
        farmlyBollingerBands = _farmlyBollingerBands;
        latestLowerPrice = farmlyBollingerBands.latestLowerBand();
        latestUpperPrice = farmlyBollingerBands.latestUpperBand();
        latestTimestamp =
            farmlyBollingerBands.nextPeriodStartTimestamp() -
            farmlyBollingerBands.period();
        feeAddress = msg.sender;
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
    }

    function isUpkeepNeeded(
        int256 upperBand,
        int256 lowerBand
    ) internal view returns (bool) {
        int256 upperThreshold = (latestUpperPrice * positionThreshold) /
            int256(THRESHOLD_DENOMINATOR);
        int256 lowerThreshold = (latestLowerPrice * positionThreshold) /
            int256(THRESHOLD_DENOMINATOR);

        bool upperNeeded = (upperBand < latestUpperPrice - upperThreshold) ||
            (upperBand > latestUpperPrice + upperThreshold);

        bool lowerNeeded = (lowerBand < latestLowerPrice - lowerThreshold) ||
            (lowerBand > latestLowerPrice + lowerThreshold);

        return upperNeeded || lowerNeeded;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override onlyForwarder {
        int256 upperBand = farmlyBollingerBands.latestUpperBand();
        int256 lowerBand = farmlyBollingerBands.latestLowerBand();

        if (isUpkeepNeeded(upperBand, lowerBand)) {
            collectPositionFees();
            uint256 timestamp = latestTimestamp + farmlyBollingerBands.period();

            uint128 liquidity = positionLiquidity();

            decreasePosition(liquidity);

            uint256 amount0 = token0.balanceOf(address(this));
            uint256 amount1 = token1.balanceOf(address(this));

            burnPositionToken();

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

            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                amount0Add
            );
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                amount1Add
            );

            (uint256 tokenId, , ) = mintPosition(
                positionInfo,
                amount0Add,
                amount1Add
            );

            latestUpperPrice = decodeTick(positionInfo.tickUpper);
            latestLowerPrice = decodeTick(positionInfo.tickLower);
            latestTimestamp = timestamp;
            latestTokenId = tokenId;

            emit PerformPosition(
                amount0Add,
                amount1Add,
                latestUpperPrice,
                latestLowerPrice,
                sharePrice(),
                timestamp,
                tokenId
            );
        }
    }

    function deposit(uint256 amount0, uint256 amount1) public {
        collectPositionFees();
        uint256 _usdValueBefore = totalUSDValue();

        if (amount0 > 0)
            FarmlyTransferHelper.safeTransferFrom(
                address(token0),
                msg.sender,
                address(this),
                amount0
            );

        if (amount1 > 0)
            FarmlyTransferHelper.safeTransferFrom(
                address(token1),
                msg.sender,
                address(this),
                amount1
            );

        PositionInfo memory positionInfo = PositionInfo(
            getTick(latestLowerPrice),
            getTick(latestUpperPrice),
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );

        (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        ) = getAmountsForAdd(positionInfo);

        swapExactInput(swapInfo.tokenIn, swapInfo.tokenOut, swapInfo.amountIn);

        FarmlyTransferHelper.safeApprove(
            address(token0),
            address(nonfungiblePositionManager),
            amount0Add
        );
        FarmlyTransferHelper.safeApprove(
            address(token1),
            address(nonfungiblePositionManager),
            amount1Add
        );

        if (latestTokenId == 0) {
            (uint256 tokenId, , ) = mintPosition(
                positionInfo,
                amount0Add,
                amount1Add
            );
            latestTokenId = tokenId;

            emit PerformPosition(
                amount0Add,
                amount1Add,
                latestUpperPrice,
                latestLowerPrice,
                sharePrice(),
                latestTimestamp,
                latestTokenId
            );
        } else {
            increasePosition(amount0Add, amount1Add);
        }

        (, , uint256 userDepositUSD) = tokensUSD(amount0, amount1);

        uint256 shareAmount = totalSupply() == 0
            ? userDepositUSD
            : FarmlyFullMath.mulDiv(
                userDepositUSD,
                totalSupply(),
                _usdValueBefore
            );
        _mint(msg.sender, shareAmount);

        emit Deposit(amount0, amount1, shareAmount, userDepositUSD);
    }

    function withdraw(uint256 amount) public {
        collectAndIncrease();
        uint128 liquidity = positionLiquidity();

        uint256 liquidityToWithdraw = (liquidity * amount) / totalSupply();

        _burn(msg.sender, amount);

        (uint256 amount0, uint256 amount1) = decreasePosition(
            uint128(liquidityToWithdraw)
        );

        uint128 liquidityAfter = positionLiquidity();

        if (liquidityAfter == 0) burnPositionToken();

        if (amount0 > 0)
            FarmlyTransferHelper.safeTransfer(
                address(token0),
                msg.sender,
                amount0
            );

        if (amount1 > 0)
            FarmlyTransferHelper.safeTransfer(
                address(token1),
                msg.sender,
                amount1
            );

        emit Withdraw(amount0, amount1, amount);
    }

    function collectPositionFees() internal {
        if (latestTokenId != 0) {
            (uint256 amount0, uint256 amount1) = collectFees();

            uint256 amount0Fee = (amount0 * performanceFee) /
                THRESHOLD_DENOMINATOR;

            uint256 amount1Fee = (amount1 * performanceFee) /
                THRESHOLD_DENOMINATOR;

            if (amount0Fee > 0)
                FarmlyTransferHelper.safeTransfer(
                    address(token0),
                    feeAddress,
                    amount0Fee
                );

            if (amount1Fee > 0)
                FarmlyTransferHelper.safeTransfer(
                    address(token1),
                    feeAddress,
                    amount1Fee
                );
        }
    }

    function collectAndIncrease() internal {
        if (latestTokenId != 0) {
            collectPositionFees();

            PositionInfo memory positionInfo = PositionInfo(
                getTick(latestLowerPrice),
                getTick(latestUpperPrice),
                token0.balanceOf(address(this)),
                token1.balanceOf(address(this))
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

            FarmlyTransferHelper.safeApprove(
                address(token0),
                address(nonfungiblePositionManager),
                amount0Add
            );
            FarmlyTransferHelper.safeApprove(
                address(token1),
                address(nonfungiblePositionManager),
                amount1Add
            );

            increasePosition(amount0Add, amount1Add);
        }
    }

    function getLatestPrices()
        internal
        view
        returns (int256 token0Price, int256 token1Price)
    {
        (, token0Price, , , ) = token0DataFeed.latestRoundData();
        (, token1Price, , , ) = token1DataFeed.latestRoundData();
    }

    function tokensUSD(
        uint256 amount0,
        uint256 amount1
    )
        internal
        view
        returns (uint256 token0USD, uint256 token1USD, uint256 totalUSD)
    {
        (int256 token0Price, int256 token1Price) = getLatestPrices();
        token0USD =
            (amount0 * uint256(token0Price)) /
            (10 ** token0.decimals());
        token1USD =
            (amount1 * uint256(token1Price)) /
            (10 ** token1.decimals());
        totalUSD = token0USD + token1USD;
    }

    function positionFeesUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        if (latestTokenId != 0) {
            (uint256 amount0, uint256 amount1) = positionFees();
            (amount0USD, amount1USD, totalUSD) = tokensUSD(amount0, amount1);
        }
    }

    function positionAmountsUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        if (latestTokenId != 0) {
            (uint256 amount0, uint256 amount1) = positionAmounts();
            (amount0USD, amount1USD, totalUSD) = tokensUSD(amount0, amount1);
        }
    }

    function balancesUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        uint256 amount0 = token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));
        (amount0USD, amount1USD, totalUSD) = tokensUSD(amount0, amount1);
    }

    function totalUSDValue() public view returns (uint256 usdValue) {
        if (latestTokenId != 0) {
            (, , uint256 positionFeesTotal) = positionFeesUSD();
            (, , uint256 positionAmountsTotal) = positionAmountsUSD();

            uint256 positionFeesWithoutPerformanceFee = (positionFeesTotal *
                (THRESHOLD_DENOMINATOR - performanceFee)) /
                THRESHOLD_DENOMINATOR;

            usdValue = positionFeesWithoutPerformanceFee + positionAmountsTotal;
        }
    }

    function sharePrice() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 1e8;
        }

        return (totalUSDValue() * 1e8) / totalSupply();
    }

    function setLatestBollingers(int256 lower, int256 upper) public onlyOwner {
        latestLowerPrice = lower;
        latestUpperPrice = upper;
    }

    function setForwarder(address _forwarderAddress) public onlyOwner {
        forwarderAddress = _forwarderAddress;
    }

    function setPositionThreshold(int256 _threshold) public onlyOwner {
        positionThreshold = _threshold;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setPerformanceFee(uint256 _fee) public onlyOwner {
        performanceFee = _fee;
    }
}
