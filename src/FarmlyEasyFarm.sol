pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {FarmlyTransferHelper} from "./libraries/FarmlyTransferHelper.sol";
import {FarmlyUniV3Executor} from "./FarmlyUniV3Executor.sol";

import "./interfaces/IFarmlyBollingerBands.sol";

contract FarmlyEasyFarm is
    AutomationCompatibleInterface,
    Ownable,
    Pausable,
    ERC20,
    FarmlyUniV3Executor
{
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;

    IFarmlyBollingerBands public farmlyBollingerBands;

    AggregatorV3Interface public token0DataFeed;

    AggregatorV3Interface public token1DataFeed;

    uint256 public latestUpperPrice;
    uint256 public latestLowerPrice;
    uint256 public latestTimestamp;

    uint256 public positionThreshold; // %1 = 1000
    uint256 public performanceFee; // %1 = 1000
    address public feeAddress;
    uint256 public maximumCapacity;

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
        uint256 upperPrice,
        uint256 lowerPrice,
        uint256 sharePrice,
        uint256 timestamp,
        uint256 tokenId
    );

    constructor(
        address _token0,
        address _token1,
        uint24 _poolFee,
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        IFarmlyBollingerBands _farmlyBollingerBands,
        uint256 _maximumCapacity
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
        maximumCapacity = _maximumCapacity;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        uint256 nextTimestamp = latestTimestamp + farmlyBollingerBands.period();
        if (block.timestamp > nextTimestamp) {
            if (
                nextTimestamp != farmlyBollingerBands.nextPeriodStartTimestamp()
            ) {
                uint256 latestUpperBand = farmlyBollingerBands
                    .latestUpperBand();
                uint256 latestLowerBand = farmlyBollingerBands
                    .latestLowerBand();
                upkeepNeeded = isUpkeepNeeded(latestUpperBand, latestLowerBand);
            }
        }
    }

    function isUpkeepNeeded(
        uint256 upperBand,
        uint256 lowerBand
    ) internal view returns (bool) {
        uint256 upperThreshold = FarmlyFullMath.mulDiv(
            latestUpperPrice,
            positionThreshold,
            THRESHOLD_DENOMINATOR
        );
        uint256 lowerThreshold = FarmlyFullMath.mulDiv(
            latestLowerPrice,
            positionThreshold,
            THRESHOLD_DENOMINATOR
        );

        bool upperNeeded = (upperBand < latestUpperPrice - upperThreshold) ||
            (upperBand > latestUpperPrice + upperThreshold);

        bool lowerNeeded = (lowerBand < latestLowerPrice - lowerThreshold) ||
            (lowerBand > latestLowerPrice + lowerThreshold);

        return upperNeeded || lowerNeeded;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        uint256 upperBand = farmlyBollingerBands.latestUpperBand();
        uint256 lowerBand = farmlyBollingerBands.latestLowerBand();

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

    function deposit(uint256 amount0, uint256 amount1) public whenNotPaused {
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

        require(userDepositUSD + _usdValueBefore <= maximumCapacity);

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
        _burn(msg.sender, amount);

        collectAndIncrease();

        uint128 liquidity = positionLiquidity();

        uint256 liquidityToWithdraw = FarmlyFullMath.mulDiv(
            liquidity,
            amount,
            totalSupply()
        );

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

            uint256 amount0Fee = FarmlyFullMath.mulDiv(
                amount0,
                performanceFee,
                THRESHOLD_DENOMINATOR
            );

            uint256 amount1Fee = FarmlyFullMath.mulDiv(
                amount1,
                performanceFee,
                THRESHOLD_DENOMINATOR
            );

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

            increasePosition(amount0Add, amount1Add);
        }
    }

    function getLatestPrices()
        internal
        view
        returns (uint256 token0Price, uint256 token1Price)
    {
        (, int256 token0Answer, , , ) = token0DataFeed.latestRoundData();
        (, int256 token1Answer, , , ) = token1DataFeed.latestRoundData();

        token0Price = FarmlyFullMath.mulDiv(
            uint256(token0Answer),
            1e18,
            10 ** token0DataFeed.decimals()
        );
        token1Price = FarmlyFullMath.mulDiv(
            uint256(token1Answer),
            1e18,
            10 ** token1DataFeed.decimals()
        );
    }

    function tokensUSD(
        uint256 amount0,
        uint256 amount1
    )
        internal
        view
        returns (uint256 token0USD, uint256 token1USD, uint256 totalUSD)
    {
        (uint256 token0Price, uint256 token1Price) = getLatestPrices();
        token0USD = FarmlyFullMath.mulDiv(
            amount0,
            token0Price,
            10 ** token0.decimals()
        );
        token1USD = FarmlyFullMath.mulDiv(
            amount1,
            token1Price,
            10 ** token1.decimals()
        );
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

            uint256 positionFeesWithoutPerformanceFee = FarmlyFullMath.mulDiv(
                positionFeesTotal,
                THRESHOLD_DENOMINATOR - performanceFee,
                THRESHOLD_DENOMINATOR
            );

            usdValue = positionFeesWithoutPerformanceFee + positionAmountsTotal;
        }
    }

    function sharePrice() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }

        return FarmlyFullMath.mulDiv(totalUSDValue(), 1e18, totalSupply());
    }

    function setLatestBollingers(
        uint256 lower,
        uint256 upper
    ) public onlyOwner {
        /* 
        will be removed
        */
        latestLowerPrice = lower;
        latestUpperPrice = upper;
    }

    function setPositionThreshold(uint256 _threshold) public onlyOwner {
        positionThreshold = _threshold;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setPerformanceFee(uint256 _fee) public onlyOwner {
        performanceFee = _fee;
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
