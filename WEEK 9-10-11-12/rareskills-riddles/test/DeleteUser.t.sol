// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DeleteUser.sol";

contract DeleteUserTest is Test {
    DeleteUser public victimContract;
    address public attackerWallet;

    function setUp() public {
        // Set up attacker wallet
        attackerWallet = makeAddr("attacker");

        // Deploy the victim contract
        victimContract = new DeleteUser();

        // Deposit 1 ether into the victim contract
        vm.deal(address(this), 1 ether); // Ensure this contract has enough ether
        victimContract.deposit{value: 1 ether}();

        // Ensure attacker has sufficient funds for testing (if needed)
        vm.deal(attackerWallet, 1 ether);
    }

    function testExploit() public {
        // Simulate the attacker
        vm.startPrank(attackerWallet);

        Attacker attackerContract = new Attacker{value: 1 ether}(address(victimContract));
        attackerContract.attack();

        // Conduct the exploit here
        // Example:
        // victimContract.exploitFunction();

        vm.stopPrank();

        // Validate that the victim contract's balance is 0
        assertEq(address(victimContract).balance, 0, "Victim contract balance should be 0");

        // Validate that the exploit used only one transaction
        uint256 attackerNonce = vm.getNonce(attackerWallet);
        assertEq(attackerNonce, 1, "Attacker must exploit in one transaction");
    }
}
