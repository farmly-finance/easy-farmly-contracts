pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {FarmlyTickLib} from "./libraries/FarmlyTickLib.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {FarmlyTransferHelper} from "./libraries/FarmlyTransferHelper.sol";

import {IPositionInfo} from "./interfaces/IPositionInfo.sol";
import {IFarmlyUniV3Executor} from "./interfaces/IFarmlyUniV3Executor.sol";
import {IFarmlyBollingerBands} from "./interfaces/IFarmlyBollingerBands.sol";

contract FarmlyEasyFarm is
    AutomationCompatibleInterface,
    Ownable,
    Pausable,
    ERC20,
    IPositionInfo
{
    uint256 public constant THRESHOLD_DENOMINATOR = 1e5;

    address public farmlyEasyFarmFactory;

    IFarmlyUniV3Executor public farmlyUniV3Executor;

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

    IERC20 public token0;
    IERC20 public token1;

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
        uint256 timestamp
    );

    constructor(
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        uint256 _maximumCapacity,
        address _farmlyBollingerBands,
        address _farmlyUniV3Executor
    ) ERC20(_shareTokenName, _shareTokenSymbol) {
        farmlyEasyFarmFactory = msg.sender;

        farmlyBollingerBands = IFarmlyBollingerBands(_farmlyBollingerBands);

        farmlyUniV3Executor = IFarmlyUniV3Executor(_farmlyUniV3Executor);

        token0 = IERC20(farmlyUniV3Executor.token0());

        token1 = IERC20(farmlyUniV3Executor.token1());

        token0DataFeed = AggregatorV3Interface(
            farmlyBollingerBands.token0DataFeed()
        );
        token1DataFeed = AggregatorV3Interface(
            farmlyBollingerBands.token1DataFeed()
        );

        latestLowerPrice = FarmlyTickLib.nearestPrice(
            farmlyBollingerBands.latestLowerBand(),
            IERC20Metadata(address(token0)).decimals(),
            IERC20Metadata(address(token1)).decimals(),
            farmlyUniV3Executor.tickSpacing()
        );

        latestUpperPrice = FarmlyTickLib.nearestPrice(
            farmlyBollingerBands.latestUpperBand(),
            IERC20Metadata(address(token0)).decimals(),
            IERC20Metadata(address(token1)).decimals(),
            farmlyUniV3Executor.tickSpacing()
        );

        latestTimestamp =
            farmlyBollingerBands.nextPeriodStartTimestamp() -
            farmlyBollingerBands.period();

        feeAddress = msg.sender;

        maximumCapacity = _maximumCapacity;

        emit PerformPosition(
            0,
            0,
            latestUpperPrice,
            latestLowerPrice,
            sharePrice(),
            latestTimestamp
        );
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        uint256 latestUpperBand = farmlyBollingerBands.latestUpperBand();
        uint256 latestLowerBand = farmlyBollingerBands.latestLowerBand();
        upkeepNeeded = isUpkeepNeeded(latestUpperBand, latestLowerBand);
    }

    function isUpkeepNeeded(
        uint256 upperBand,
        uint256 lowerBand
    ) internal view returns (bool) {
        uint256 nextTimestamp = latestTimestamp + farmlyBollingerBands.period();

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

        bool periodPassed = block.timestamp > nextTimestamp &&
            nextTimestamp != farmlyBollingerBands.nextPeriodStartTimestamp();

        bool upperNeeded = (upperBand < latestUpperPrice - upperThreshold) ||
            (upperBand > latestUpperPrice + upperThreshold);

        bool lowerNeeded = (lowerBand < latestLowerPrice - lowerThreshold) ||
            (lowerBand > latestLowerPrice + lowerThreshold);

        return (upperNeeded || lowerNeeded) && periodPassed;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override whenNotPaused {
        uint256 lowerBand = farmlyBollingerBands.latestLowerBand();
        uint256 upperBand = farmlyBollingerBands.latestUpperBand();
        uint256 _usdValueBefore = totalUSDValue();

        if (isUpkeepNeeded(upperBand, lowerBand)) {
            (
                uint256 amount0Collected,
                uint256 amount1Collected,
                uint256 amount0Added,
                uint256 amount1Added
            ) = farmlyUniV3Executor.onPerformUpkeep(lowerBand, upperBand);

            latestUpperPrice = FarmlyTickLib.nearestPrice(
                upperBand,
                IERC20Metadata(address(token0)).decimals(),
                IERC20Metadata(address(token1)).decimals(),
                farmlyUniV3Executor.tickSpacing()
            );

            latestLowerPrice = FarmlyTickLib.nearestPrice(
                lowerBand,
                IERC20Metadata(address(token0)).decimals(),
                IERC20Metadata(address(token1)).decimals(),
                farmlyUniV3Executor.tickSpacing()
            );

            latestTimestamp =
                farmlyBollingerBands.nextPeriodStartTimestamp() -
                farmlyBollingerBands.period();

            _mintPerformanceFee(
                amount0Collected,
                amount1Collected,
                totalSupply(),
                _usdValueBefore
            );

            emit PerformPosition(
                amount0Added,
                amount1Added,
                latestUpperPrice,
                latestLowerPrice,
                sharePrice(),
                latestTimestamp
            );
        }
    }

    function deposit(uint256 amount0, uint256 amount1) public whenNotPaused {
        uint256 _totalSupplyBefore = totalSupply();
        uint256 _usdValueBefore = totalUSDValue();

        (, , uint256 userDepositUSD) = tokensUSD(amount0, amount1);

        require(userDepositUSD + _usdValueBefore <= maximumCapacity);

        if (amount0 > 0)
            FarmlyTransferHelper.safeTransferFrom(
                address(token0),
                msg.sender,
                address(farmlyUniV3Executor),
                amount0
            );

        if (amount1 > 0)
            FarmlyTransferHelper.safeTransferFrom(
                address(token1),
                msg.sender,
                address(farmlyUniV3Executor),
                amount1
            );

        (
            uint256 amount0Collected,
            uint256 amount1Collected
        ) = farmlyUniV3Executor.onDeposit(latestLowerPrice, latestUpperPrice);

        uint256 shareAmount = _totalSupplyBefore == 0
            ? userDepositUSD
            : FarmlyFullMath.mulDiv(
                userDepositUSD,
                _totalSupplyBefore,
                _usdValueBefore
            );

        _mint(msg.sender, shareAmount);
        _mintPerformanceFee(
            amount0Collected,
            amount1Collected,
            _totalSupplyBefore,
            _usdValueBefore
        );

        emit Deposit(amount0, amount1, shareAmount, userDepositUSD);
    }

    function withdraw(
        uint256 amount,
        bool isMinimizeTrading,
        bool zeroForOne
    ) public {
        uint256 _supplyBefore = totalSupply();
        uint256 _usdValueBefore = totalUSDValue();

        _burn(msg.sender, amount);

        (
            uint256 amount0Collected,
            uint256 amount1Collected,
            uint256 amount0,
            uint256 amount1
        ) = farmlyUniV3Executor.onWithdraw(
                amount,
                _supplyBefore,
                msg.sender,
                isMinimizeTrading,
                zeroForOne
            );

        _mintPerformanceFee(
            amount0Collected,
            amount1Collected,
            _supplyBefore,
            _usdValueBefore
        );

        emit Withdraw(amount0, amount1, amount);
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

    function positionFeesUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        (uint256 amount0, uint256 amount1) = farmlyUniV3Executor.positionFees();

        (amount0USD, amount1USD, totalUSD) = tokensUSD(amount0, amount1);
    }

    function positionAmountsUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        (uint256 amount0, uint256 amount1) = farmlyUniV3Executor
            .positionAmounts();

        (amount0USD, amount1USD, totalUSD) = tokensUSD(amount0, amount1);
    }

    function totalUSDValue() public view returns (uint256 usdValue) {
        (, , uint256 positionFeesTotal) = positionFeesUSD();

        (, , uint256 positionAmountsTotal) = positionAmountsUSD();

        usdValue = positionFeesTotal + positionAmountsTotal;
    }

    function sharePrice() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }

        return FarmlyFullMath.mulDiv(totalUSDValue(), 1e18, totalSupply());
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
            10 ** IERC20Metadata(farmlyUniV3Executor.token0()).decimals()
        );

        token1USD = FarmlyFullMath.mulDiv(
            amount1,
            token1Price,
            10 ** IERC20Metadata(farmlyUniV3Executor.token1()).decimals()
        );

        totalUSD = token0USD + token1USD;
    }

    function _mintPerformanceFee(
        uint256 amount0,
        uint256 amount1,
        uint256 _totalSupply,
        uint256 _usdValue
    ) internal {
        (, , uint256 totalUSD) = tokensUSD(
            FarmlyFullMath.mulDiv(
                amount0,
                performanceFee,
                THRESHOLD_DENOMINATOR
            ),
            FarmlyFullMath.mulDiv(
                amount1,
                performanceFee,
                THRESHOLD_DENOMINATOR
            )
        );

        uint256 shareAmount = _totalSupply == 0
            ? totalUSD
            : FarmlyFullMath.mulDiv(totalUSD, _totalSupply, _usdValue);

        if (shareAmount > 0) _mint(feeAddress, shareAmount);
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
