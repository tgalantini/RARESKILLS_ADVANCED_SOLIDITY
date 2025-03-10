// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract ExactSwap {
    /**
     *  PERFORM AN SIMPLE SWAP WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1 WETH.
     *  The challenge is to swap an exact amount of WETH for 1337 USDC token using the `swap` function
     *  from USDC/WETH pool.
     *
     */
    function performExactSwap(address pool, address weth, address usdc) public {
        /**
         *     swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data);
         *
         *     amount0Out: the amount of USDC to receive from swap.
         *     amount1Out: the amount of WETH to receive from swap.
         *     to: recipient address to receive the USDC tokens.
         *     data: leave it empty.
         */

        IUniswapV2Pair uniPair = IUniswapV2Pair(pool);
        IERC20 wethContract = IERC20(weth);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();
        
        uint256 amountOut = 1337 * 10 ** 6;

        uint256 denominator = (usdcReserve - amountOut) * 997;

        uint256 numerator = wethReserve * amountOut * 1000;

        uint256 wethAmount = (numerator / denominator) + 1 ;
        wethContract.transfer(pool, wethAmount);

        uniPair.swap(1337 * 10 ** 6, 0, address(this), "");

    }
}
