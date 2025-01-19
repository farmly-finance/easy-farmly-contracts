pragma solidity ^0.8.13;

import {IFarmlyEasyFarm} from "./interfaces/IFarmlyEasyFarm.sol";
import {IFarmlyBaseStrategy} from "./interfaces/base/IFarmlyBaseStrategy.sol";
import {IFarmlyBaseExecutor} from "./interfaces/base/IFarmlyBaseExecutor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract FarmlyEasyFarm is
    AutomationCompatibleInterface,
    IFarmlyEasyFarm,
    ERC20
{
    /// @notice Maximum capacity reached
    error MaximumCapacityReached();
    /// @notice Not upkeep needed
    error NotUpkeepNeeded();
    /// @notice Price base
    uint256 public constant PRICE_BASE = 10 ** 18;
    /// @inheritdoc IFarmlyEasyFarm
    IFarmlyBaseStrategy public override strategy;
    /// @inheritdoc IFarmlyEasyFarm
    IFarmlyBaseExecutor public override executor;

    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestUpperPrice;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestLowerPrice;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override latestTimestamp;
    /// @inheritdoc IFarmlyEasyFarm
    AggregatorV3Interface public override token0DataFeed;
    /// @inheritdoc IFarmlyEasyFarm
    AggregatorV3Interface public override token1DataFeed;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override positionThreshold;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override performanceFee;
    /// @inheritdoc IFarmlyEasyFarm
    address public override feeAddress;
    /// @inheritdoc IFarmlyEasyFarm
    uint256 public override maximumCapacity;
    /// @inheritdoc IFarmlyEasyFarm
    IERC20 public override token0;
    /// @inheritdoc IFarmlyEasyFarm
    IERC20 public override token1;
    /// @inheritdoc IFarmlyEasyFarm
    uint8 public override token0Decimals;
    /// @inheritdoc IFarmlyEasyFarm
    uint8 public override token1Decimals;

    /// @notice Constructor
    /// @param _shareTokenName Name of the share token
    /// @param _shareTokenSymbol Symbol of the share token
    /// @param _maximumCapacity Maximum capacity of the farm
    /// @param _strategy Strategy of the farm
    /// @param _executor Executor of the farm
    constructor(
        string memory _shareTokenName,
        string memory _shareTokenSymbol,
        uint256 _maximumCapacity,
        IFarmlyBaseStrategy _strategy,
        IFarmlyBaseExecutor _executor
    ) ERC20(_shareTokenName, _shareTokenSymbol) {
        strategy = _strategy;

        executor = _executor;

        maximumCapacity = _maximumCapacity;

        token0Decimals = IERC20Metadata(address(token0)).decimals();

        token1Decimals = IERC20Metadata(address(token1)).decimals();
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = strategy.isRebalanceNeeded(
            latestLowerPrice,
            latestUpperPrice
        );
    }

    function performUpkeep(bytes calldata performData) external override {
        if (!strategy.isRebalanceNeeded(latestLowerPrice, latestUpperPrice)) {
            revert NotUpkeepNeeded();
        }

        latestUpperPrice = strategy.latestUpperPrice();
        latestLowerPrice = strategy.latestLowerPrice();

        executor.onRebalance(latestLowerPrice, latestUpperPrice);
    }

    function deposit(uint256 _amount0, uint256 _amount1) external override {
        uint256 totalSupplyBefore = totalSupply();
        uint256 totalUSDBefore = totalUSDValue();

        (, , uint256 userDepositUSD) = tokensUSDValue(_amount0, _amount1);

        if (totalUSDBefore + userDepositUSD > maximumCapacity) {
            revert MaximumCapacityReached();
        }

        if (_amount0 > 0)
            token0.transferFrom(msg.sender, address(executor), _amount0);
        if (_amount1 > 0)
            token1.transferFrom(msg.sender, address(executor), _amount1);

        executor.onDeposit(latestLowerPrice, latestUpperPrice);

        uint256 shareAmount = totalSupplyBefore == 0
            ? userDepositUSD
            : FarmlyFullMath.mulDiv(
                userDepositUSD,
                totalSupplyBefore,
                totalUSDBefore
            );

        _mint(msg.sender, shareAmount);

        emit Deposit(_amount0, _amount1, shareAmount, userDepositUSD);
    }

    function withdraw(
        uint256 _amount,
        bool _isMinimizeTrading,
        bool _zeroForOne
    ) external override {
        uint256 totalSupplyBefore = totalSupply();
        uint256 totalUSDBefore = totalUSDValue();

        _burn(msg.sender, _amount);

        executor.onWithdraw(_amount);

        emit Withdraw(0, 0, _amount, totalUSDBefore);
    }

    function latestTokenPrices()
        public
        view
        returns (uint256 token0Price, uint256 token1Price)
    {
        (, int256 token0Answer, , , ) = token0DataFeed.latestRoundData();
        (, int256 token1Answer, , , ) = token1DataFeed.latestRoundData();

        token0Price = FarmlyFullMath.mulDiv(
            uint256(token0Answer),
            PRICE_BASE,
            10 ** token0DataFeed.decimals()
        );

        token1Price = FarmlyFullMath.mulDiv(
            uint256(token1Answer),
            PRICE_BASE,
            10 ** token1DataFeed.decimals()
        );
    }

    function totalUSDValue() public view returns (uint256 usdValue) {
        (, , uint256 positionFeesTotal) = positionFeesUSD();
        (, , uint256 positionUSD) = positionAmountsUSD();

        usdValue = positionUSD + positionFeesTotal;
    }

    function positionFeesUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        (uint256 amount0, uint256 amount1) = executor.positionFees();

        (amount0USD, amount1USD, totalUSD) = tokensUSDValue(amount0, amount1);
    }

    function positionAmountsUSD()
        public
        view
        returns (uint256 amount0USD, uint256 amount1USD, uint256 totalUSD)
    {
        (uint256 amount0, uint256 amount1) = executor.positionAmounts();

        (amount0USD, amount1USD, totalUSD) = tokensUSDValue(amount0, amount1);
    }

    function tokensUSDValue(
        uint256 _amount0,
        uint256 _amount1
    )
        internal
        view
        returns (uint256 token0USD, uint256 token1USD, uint256 totalUSD)
    {
        (uint256 token0Price, uint256 token1Price) = latestTokenPrices();

        token0USD = FarmlyFullMath.mulDiv(
            _amount0,
            token0Price,
            10 ** token0Decimals
        );
        token1USD = FarmlyFullMath.mulDiv(
            _amount1,
            token1Price,
            10 ** token1Decimals
        );

        totalUSD = token0USD + token1USD;
    }
}
