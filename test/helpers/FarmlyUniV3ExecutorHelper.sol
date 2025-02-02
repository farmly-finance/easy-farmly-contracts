pragma solidity ^0.8.13;

import {FarmlyUniV3Executor} from "../../src/executors/FarmlyUniV3Executor.sol";

contract FarmlyUniV3ExecutorHelper is FarmlyUniV3Executor {
    constructor(
        address _factory,
        address _nonfungiblePositionManager,
        address _swapRouter,
        address _token0,
        address _token1,
        uint24 _poolFee
    )
        FarmlyUniV3Executor(
            _factory,
            _nonfungiblePositionManager,
            _swapRouter,
            _token0,
            _token1,
            _poolFee
        )
    {}

    function exposed_addBalanceLiquidity(
        uint256 _lowerPrice,
        uint256 _upperPrice
    ) external {
        addBalanceLiquidity(_lowerPrice, _upperPrice);
    }

    function exposed_increasePosition(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        increasePosition(_amount0, _amount1);
    }

    function exposed_decreasePosition(uint128 _liquidity) external {
        decreasePosition(_liquidity);
    }

    function exposed_mintPosition(
        Position memory _position,
        uint256 _amount0,
        uint256 _amount1
    ) external {
        mintPosition(_position, _amount0, _amount1);
    }

    function exposed_swapExactInput(
        Swap memory _swap
    ) external returns (uint256 amountOut) {
        amountOut = swapExactInput(_swap);
    }

    function exposed_collectFees()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = collectFees();
    }

    function exposed_burnPositionToken() external {
        burnPositionToken();
    }

    function exposed_positionInfo()
        external
        view
        returns (int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        (tickLower, tickUpper, liquidity) = positionInfo();
    }

    function exposed_tokenBalances()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = tokenBalances();
    }

    function exposed_feeGrowthInside(
        int24 _tickLower,
        int24 _tickUpper
    )
        external
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (feeGrowthInside0X128, feeGrowthInside1X128) = feeGrowthInside(
            _tickLower,
            _tickUpper
        );
    }
}
