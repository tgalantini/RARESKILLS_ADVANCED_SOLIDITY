// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

contract MultiHop {
    /**
     *  PERFORM A MULTI-HOP SWAP WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 10 MKR.
     *  The challenge is to swap the contract entire MKR balance for ELON token, using WETH as the middleware token.
     *
     */
    address public immutable router;
    address public elonWethPool = 0x7B73644935b8e68019aC6356c40661E1bc315860;
    address public mkrWethPool = 0xC2aDdA861F89bBB333c90c492cB837741916A225;
    constructor(address _router) {
        router = _router;
    }

    function performMultiHopWithRouter(address mkr, address weth, address elon, uint256 deadline) public {
        // your code start here 
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        (uint256 mkrRes, uint256 wethRes, ) = IUniswapV2Pair(mkrWethPool).getReserves();
        uint256 wethOut = getAmountOut(10 * 1e18 , mkrRes, wethRes);
        address[] memory path = new address[](2);
        path[0] = mkr;
        path[1] = weth;
        IERC20(mkr).approve(router, 10* 1e18);
        uniRouter.swapExactTokensForTokens(10 * 1e18, wethOut, path, address(this), block.timestamp + 1 minutes);
        (uint256 elonRes, uint256 newWethRes, ) = IUniswapV2Pair(elonWethPool).getReserves();
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        uint256 elonOut = getAmountOut(wethBal, newWethRes, elonRes);
        path[0] = weth;
        path[1] = elon;
        IERC20(weth).approve(router, wethBal);
        uniRouter.swapExactTokensForTokens(wethBal, elonOut, path, address(this), block.timestamp + 1 minutes);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        uint amountInWithFee = amountIn * (997);
        uint numerator = amountInWithFee * (reserveOut);
        uint denominator = reserveIn * (1000) + (amountInWithFee);
        amountOut = numerator / denominator;
    }
}

interface IUniswapV2Router {
    /**
     *     amountIn: the amount of input tokens to swap.
     *     amountOutMin: the minimum amount of output tokens that must be received for the transaction not to revert.
     *     path: an array of token addresses.
     *     to: recipient address to receive the liquidity tokens.
     *     deadline: timestamp after which the transaction will revert.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
