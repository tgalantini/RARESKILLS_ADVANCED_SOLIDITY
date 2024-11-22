
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./dexflattened.sol";

contract EchidnaTestDex {
    Dex public dex;
    IERC20 public token1;
    IERC20 public token2;
    uint256 initialLiquidity;

    constructor() {
        // Deploy Dex contract
        dex = new Dex();

        // Deploy two tokens
        token1 = new SwappableToken("token1", "TKN1", 110);
        token2 = new SwappableToken("token2", "TKN2", 110);
        dex.setTokens(address(token1), address(token2));
        dex.renounceOwnership();
        // Transfer tokens to Dex
        token1.transfer(address(dex), 100);
        token2.transfer(address(dex), 100);

        // Approve Dex for token transfers
        token1.approve(address(dex), type(uint256).max);
        token2.approve(address(dex), type(uint256).max);

        // Provide initial user balances
        token1.transfer(address(this), 10);
        token2.transfer(address(this), 10);

        initialLiquidity = sqrt(
            IERC20(token1).balanceOf(address(dex)) * IERC20(token2).balanceOf(address(dex))
        );
    }

    function testSwap(uint256 amount, uint8 direction) public {
        // Constrain amount to avoid unrealistic scenarios

        if (direction == 0) {
            // Swap token1 for token2
            IERC20(token1).approve(address(dex), type(uint256).max);
            if (IERC20(token1).balanceOf(msg.sender) >= amount) {
                dex.swap(address(token1), address(token2), amount);
            }
        } else {
            // Swap token2 for token1
            IERC20(token2).approve(address(dex), type(uint256).max);
            if (IERC20(token2).balanceOf(msg.sender) >= amount) {
                dex.swap(address(token2), address(token1), amount);
            }
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function echidna_test_liquidity_is_reasonable() public view returns (bool) {
        uint256 currentLiquidity = sqrt(
            IERC20(token1).balanceOf(address(dex)) * IERC20(token2).balanceOf(address(dex))
        );

        // Ensure liquidity has not dropped below 50% of the initial liquidity
        return currentLiquidity >= initialLiquidity;
    }

    function echidna_test_drain() public returns(bool){

         return IERC20(token1).balanceOf(address(this)) == 0 || IERC20(token2).balanceOf(address(this)) == 0;
    }
}
