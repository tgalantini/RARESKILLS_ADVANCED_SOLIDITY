
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./dexflattened.sol";

contract EchidnaTestDex {
    Dex public dex;
    IERC20 public token1;
    IERC20 public token2;

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
    }

    // function echidna_break_dex() public returns (bool) {
    //     // Exploit the Dex by swapping token1 and token2 repeatedly
    //         IERC20(token1).approve(address(this), type(uint256).max);
    //         IERC20(token2).approve(address(this), type(uint256).max);

    //         while(IERC20(token1).balanceOf(address(dex)) > 0 || IERC20(token2).balanceOf(address(dex)) > 0) {

    //             if (IERC20(token1).balanceOf(msg.sender) > 0) {
    //                 dex.swap(address(token1), address(token2), IERC20(token1).balanceOf(msg.sender));
    //             }

    //             // Swap token2 for token1
    //             if (IERC20(token2).balanceOf(msg.sender) > 0) {
    //                 dex.swap(address(token2), address(token1), IERC20(token2).balanceOf(msg.sender));
    //             }
    //     }

    //     // Check if Dex reserves are drained
    //     bool token1Drained = IERC20(token1).balanceOf(address(this)) == 0;
    //     bool token2Drained = IERC20(token2).balanceOf(address(this)) == 0;

    //     return token1Drained || token2Drained;
    // }

    function echidna_test_dex() public returns(bool){
        
        bool token1Drained = IERC20(token1).balanceOf(address(this)) == 0;
        bool token2Drained = IERC20(token2).balanceOf(address(this)) == 0;

        return token1Drained || token2Drained;
    }
}
