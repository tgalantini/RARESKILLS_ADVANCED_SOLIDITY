// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";
import "forge-std/console.sol";


contract AddLiquid {
    /**
     *  ADD LIQUIDITY WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1000 USDC and 1 WETH.
     *  Mint a position (deposit liquidity) in the pool USDC/WETH to msg.sender.
     *  The challenge is to provide the same ratio as the pool then call the mint function in the pool contract.
     *
     */
    function addLiquidity(address usdc, address weth, address pool, uint256 usdcReserve, uint256 wethReserve) public {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);
        IERC20 wethContract = IERC20(weth);
        IERC20 usdcContract = IERC20(usdc);
        uint256 requiredUsdcForOneWeth = (usdcReserve * 1e18) / wethReserve;
        uint256 wethAmount;
        uint256 usdcAmount;
        if (requiredUsdcForOneWeth > 1000){
            usdcAmount  = usdcContract.balanceOf(address(this));
            wethAmount = (wethReserve * usdcAmount) / usdcReserve ;
        } else {
            wethAmount = wethContract.balanceOf(address(this));
            usdcAmount = (usdcReserve * wethAmount) / wethReserve;
        }

        wethContract.transfer(pool, wethAmount);
        usdcContract.transfer(pool, usdcAmount);
        pair.mint(msg.sender);
    }
}
