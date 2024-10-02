pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {FarmlyFullMath} from "./libraries/FarmlyFullMath.sol";
import {FarmlyZapV3, V3PoolCallee} from "./libraries/FarmlyZapV3.sol";
import {SqrtPriceX96} from "./libraries/SqrtPriceX96.sol";

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

contract FarmlyPositionManager is ERC20, ILogAutomation, IERC721Receiver {
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    IUniswapV3Pool public pool =
        IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);

    AggregatorV3Interface public token0DataFeed =
        AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

    AggregatorV3Interface public token1DataFeed =
        AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);

    IERC20Metadata public token0;
    IERC20Metadata public token1;
    uint24 poolFee = 500;

    int256 public latestUpperPrice;
    int256 public latestLowerPrice;
    uint256 public latestTimestamp;
    uint256 public latestTokenId;

    int256 public positonThreshold = 500; // %1 = 1000

    struct PositionInfo {
        int24 tickLower;
        int24 tickUpper;
        uint amount0Add;
        uint amount1Add;
    }

    struct SwapInfo {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint160 sqrtPriceX96;
    }

    constructor() ERC20("Test Token", "TSTSY") {
        token0 = IERC20Metadata(pool.token0());
        token1 = IERC20Metadata(pool.token1());
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function checkLog(
        Log calldata log,
        bytes memory
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (, int256 upperBand, , int256 lowerBand, uint256 timestamp) = abi
            .decode(log.data, (int256, int256, int256, int256, uint256));

        upkeepNeeded = isUpkeepNeeded(upperBand, lowerBand);
        performData = abi.encode(upperBand, lowerBand, timestamp);
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

    function deposit(uint256 amount0, uint256 amount1) public {
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
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
                    totalUSDValue()
                )
        );

        PositionInfo memory positionInfo = PositionInfo(
            TickMath.getTickAtSqrtRatio(encodeSqrtPriceX96(latestLowerPrice)),
            TickMath.getTickAtSqrtRatio(encodeSqrtPriceX96(latestUpperPrice)),
            amount0,
            amount1
        );

        (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        ) = getAmountsForAdd(positionInfo);

        token0.approve(address(nonfungiblePositionManager), amount0Add);
        token1.approve(address(nonfungiblePositionManager), amount1Add);

        if (latestTokenId == 0) {
            INonfungiblePositionManager.MintParams
                memory params = INonfungiblePositionManager.MintParams({
                    token0: address(token0),
                    token1: address(token1),
                    fee: poolFee,
                    tickLower: 0,
                    tickUpper: 0,
                    amount0Desired: amount0Add,
                    amount1Desired: amount1Add,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                });

            (uint256 tokenId, , , ) = nonfungiblePositionManager.mint(params);

            latestTokenId = tokenId;

            /* SIFIRDAN POZ OLUŞTUR*/
        } else {
            /* VAR OLANA EKLE */
        }

        /* 
        userDepositUSD * totalSupply() / totalUSDValue
        */
        /*
         * KULLANICI DEPOSİT EDER
         * SHARE MINT EDILIR
         * POZİSYONA EKLEME YAPAR
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

    function getLatestPrices()
        internal
        view
        returns (int256 token0Price, int256 token1Price)
    {
        (, token0Price, , , ) = token0DataFeed.latestRoundData();
        (, token1Price, , , ) = token1DataFeed.latestRoundData();
    }

    function getAmountsForAdd(
        PositionInfo memory positionInfo
    )
        public
        view
        returns (
            SwapInfo memory swapInfo,
            uint256 amount0Add,
            uint256 amount1Add
        )
    {
        (
            uint256 amountIn,
            uint256 amountOut,
            bool zeroForOne,
            uint160 sqrtPriceX96
        ) = FarmlyZapV3.getOptimalSwap(
                V3PoolCallee.wrap(address(pool)),
                positionInfo.tickLower,
                positionInfo.tickUpper,
                positionInfo.amount0Add,
                positionInfo.amount1Add
            );

        swapInfo.tokenIn = zeroForOne ? address(token0) : address(token1);

        swapInfo.tokenOut = zeroForOne ? address(token1) : address(token0);

        swapInfo.amountIn = amountIn;

        swapInfo.amountOut = amountOut;

        swapInfo.sqrtPriceX96 = sqrtPriceX96;

        amount0Add = zeroForOne
            ? positionInfo.amount0Add - amountIn
            : positionInfo.amount0Add + amountOut;

        amount1Add = zeroForOne
            ? positionInfo.amount1Add + amountOut
            : positionInfo.amount1Add - amountIn;
    }

    function totalUSDValue() public view returns (uint256) {
        return 0;
    }

    function addLiquidityToUniswap(uint256 amount0, uint256 amount1) internal {}
}
