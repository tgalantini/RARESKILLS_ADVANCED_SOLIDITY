// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract BurnLiquidWithRouter {
    /**
     *  BURN LIQUIDITY WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 0.01 UNI-V2-LP tokens.
     *  Burn a position (remove liquidity) from USDC/ETH pool to this contract.
     *  The challenge is to use Uniswapv2 router to remove all the liquidity from the pool.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function burnLiquidityWithRouter(address pool, address usdc, address weth, uint256 deadline) public {
        IUniswapV2Pair uniPair = IUniswapV2Pair(pool);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();
        uint256 liquidity = uniPair.totalSupply();
        uint256 shareOfPool = (uniPair.balanceOf(address(this)) * 1e18) / liquidity;

        uint256 wantedDeadline = deadline;
        uint256 amountAmin = (usdcReserve * shareOfPool) / 1e18;
        uint256 amountBmin = (wethReserve * shareOfPool) / 1e18;
        uniPair.approve(router, liquidity);
        IUniswapV2Router(router).removeLiquidity(usdc, weth, 0.01 ether, amountAmin, amountBmin, address(this), wantedDeadline);
    }
}

interface IUniswapV2Router {
    /**
     *     tokenA: the address of tokenA, in our case, USDC.
     *     tokenB: the address of tokenB, in our case, WETH.
     *     liquidity: the amount of LP tokens to burn.
     *     amountAMin: the minimum amount of amountA to receive.
     *     amountBMin: the minimum amount of amountB to receive.
     *     to: recipient address to receive tokenA and tokenB.
     *     deadline: timestamp after which the transaction will revert.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}
