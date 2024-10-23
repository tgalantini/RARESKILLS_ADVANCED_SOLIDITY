// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract SimpleSwapWithRouter {
    /**
     *  PERFORM A SIMPLE SWAP USING ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1 ETH.
     *  The challenge is to swap any amount of ETH for USDC token using Uniswapv2 router.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function performSwapWithRouter(address[] calldata path, uint256 deadline) public {
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        IUniswapV2Pair uniPair = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();

        uint256 amountIn = 1 ether;

        uint256 denominator = (wethReserve + amountIn) * 1000;

        uint256 numerator = usdcReserve * amountIn * 997;

        uint256 amountOut = (numerator / denominator) * 98 / 100;
        uint256 trueDeadline = deadline;
        address[] calldata newPath = path;


        uniRouter.swapExactETHForTokens{value: 1 ether}(amountOut, newPath, address(this), trueDeadline);
    }

    receive() external payable {}
}

interface IUniswapV2Router {
    /**
     *     amountOutMin: the minimum amount of output tokens that must be received for the transaction not to revert.
     *     path: an array of token addresses. In our case, WETH and USDC.
     *     to: recipient address to receive the liquidity tokens.
     *     deadline: timestamp after which the transaction will revert.
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);
}
