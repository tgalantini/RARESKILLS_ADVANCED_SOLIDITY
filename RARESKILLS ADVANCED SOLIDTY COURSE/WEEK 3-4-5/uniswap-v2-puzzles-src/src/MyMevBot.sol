// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

/**
 *
 *  ARBITRAGE A POOL
 *
 * Given two pools where the token pair represents the same underlying; WETH/USDC and WETH/USDT (the formal has the corect price, while the latter doesnt).
 * The challenge is to flash borrowing some USDC (>1000) from `flashLenderPool` to arbitrage the pool(s), then make profit by ensuring MyMevBot contract's USDC balance
 * is more than 0.
 *
 */
contract MyMevBot {
    address public immutable flashLenderPool;
    address public immutable weth;
    address public immutable usdc;
    address public immutable usdt;
    address public immutable router;
    bool public flashLoaned;

    constructor(address _flashLenderPool, address _weth, address _usdc, address _usdt, address _router) {
        flashLenderPool = _flashLenderPool;
        weth = _weth;
        usdc = _usdc;
        usdt = _usdt;
        router = _router;
    }

    function performArbitrage() public {
        IUniswapV3Pool(flashLenderPool).flash(address(this), 10000 * 1e6, 0, "");
    }

    function usdcToWeth() private{
        (uint256 usdcRes, uint256 wethRes ,) = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc).getReserves();
        uint256 amountOut = getAmountOut(10000 * 1e6, usdcRes, wethRes);
        IERC20(usdc).approve(router, 10000 * 1e6);
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;
        IUniswapV2Router(router).swapExactTokensForTokens(10000 * 1e6, amountOut, path, address(this), block.timestamp + 1 minutes);
    }

    function wethToUsdt() private{
        (uint256 wethRes, uint256 usdtRes ,) = IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852).getReserves();
        uint256 amountOut = getAmountOut(IERC20(weth).balanceOf(address(this)), wethRes, usdtRes);
        IERC20(weth).approve(router, IERC20(weth).balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdt;
        IUniswapV2Router(router).swapExactTokensForTokens(IERC20(weth).balanceOf(address(this)), amountOut, path, address(this), block.timestamp + 1 minutes);
    }

    function UsdtToUsdc() private{
         (uint256 usdcRes, uint256 usdtRes ,) = IUniswapV2Pair(0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f).getReserves();
        uint256 amountOut = getAmountOut(IERC20(usdt).balanceOf(address(this)), usdtRes, usdcRes);
        IERC20(usdt).approve(router, IERC20(usdt).balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = usdt;
        path[1] = usdc;
        IUniswapV2Router(router).swapExactTokensForTokens(IERC20(usdt).balanceOf(address(this)), amountOut, path, address(this), block.timestamp + 1 minutes);

    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        uint amountInWithFee = amountIn * (997);
        uint numerator = amountInWithFee * (reserveOut);
        uint denominator = reserveIn * (1000) + (amountInWithFee);
        amountOut = numerator / denominator;
    }

    function uniswapV3FlashCallback(uint256 _fee0, uint256, bytes calldata data) external {
        callMeCallMe();
        usdcToWeth();
        wethToUsdt();
        UsdtToUsdc();
        require(IERC20(usdc).balanceOf(address(this)) > 10000 * 1e6, "Not enough usdc received");
        IERC20(usdc).transfer(flashLenderPool, 10000 * 1e6 + _fee0);
        IERC20(usdc).balanceOf(address(this));
    }

    function callMeCallMe() private {
        uint256 usdcBal = IERC20(usdc).balanceOf(address(this));
        require(msg.sender == address(flashLenderPool), "not callback");
        require(flashLoaned = usdcBal >= 1000 * 1e6, "FlashLoan less than 1,000 USDC.");
    }
}

interface IUniswapV3Pool {
    /**
     * recipient: the address which will receive the token0 and/or token1 amounts.
     * amount0: the amount of token0 to send.
     * amount1: the amount of token1 to send.
     * data: any data to be passed through to the callback.
     */
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
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
