// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract ExactSwapWithRouter {
    /**
     *  PERFORM AN EXACT SWAP WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1 WETH.
     *  The challenge is to swap an exact amount of WETH for 1337 USDC token using UniswapV2 router.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function performExactSwapWithRouter(address weth, address usdc, uint256 deadline) public {
        // your code start here
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        IUniswapV2Pair uniPair = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
        IERC20 wethContract = IERC20(weth);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();
        uint256 amountOut = 1337 * 10 ** 6;
        uint256 denominator = (usdcReserve - amountOut) * 997;
        uint256 numerator = wethReserve * amountOut * 1000;
        uint256 wethAmount = (numerator / denominator) + 1 ;
        uint256 wethAmountAdjusted = wethAmount * 101 / 100;
        uint256 newDeadline = deadline;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        wethContract.approve(router, wethAmountAdjusted);
        uniRouter.swapExactTokensForTokens(wethAmount, amountOut, path, address(this), newDeadline);

    }
}

interface IUniswapV2Router {
    /**
     *     amountIn: the amount of input tokens to swap.
     *     amountOutMin: the minimum amount of output tokens that must be received for the transaction not to revert.
     *     path: an array of token addresses. In our case, WETH and USDC.
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
