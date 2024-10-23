// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract AddLiquidWithRouter {
    /**
     *  ADD LIQUIDITY WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1000 USDC and 1 ETH.
     *  Mint a position (deposit liquidity) in the pool USDC/ETH to `msg.sender`.
     *  The challenge is to use Uniswapv2 router to add liquidity to the pool.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function addLiquidityWithRouter(address usdcAddress, uint256 deadline) public {
        // your code start here
        IERC20 usdc = IERC20(usdcAddress);
        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        (uint256 usdcReserve, uint256 wethReserve,) = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc).getReserves();
        uint256 requiredUsdcForOneWeth = (usdcReserve * 1e18) / wethReserve;
        uint256 ethAmount;
        uint256 usdcAmount;
        if (requiredUsdcForOneWeth > 1000){
            usdcAmount  = usdc.balanceOf(address(this));
            ethAmount = (wethReserve * usdcAmount) / usdcReserve ;
        } else {
            ethAmount = address(this).balance;
            usdcAmount = (usdcReserve * ethAmount) / wethReserve;
        }
        uint256 amountUsdcMin = usdcAmount * 98 / 100;
        uint256 ethAmountMin = ethAmount * 98 / 100;
        uint256 wantedDeadline = deadline + 1 minutes;
        usdc.approve(router, usdcAmount);
        uniRouter.addLiquidityETH{value: ethAmount}(usdcAddress, usdcAmount, amountUsdcMin, ethAmountMin, msg.sender, wantedDeadline);
    
    }

    receive() external payable {}
}

interface IUniswapV2Router {
    /**
     *     token: the usdc address
     *     amountTokenDesired: the amount of USDC to add as liquidity.
     *     amountTokenMin: bounds the extent to which the ETH/USDC price can go up before the transaction reverts. Must be <= amountUSDCDesired.
     *     amountETHMin: bounds the extent to which the USDC/ETH price can go up before the transaction reverts. Must be <= amountETHDesired.
     *     to: recipient address to receive the liquidity tokens.
     *     deadline: timestamp after which the transaction will revert.
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}
