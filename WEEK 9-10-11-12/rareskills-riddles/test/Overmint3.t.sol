// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Overmint3.sol";

contract Overmint3Test is Test {
    Overmint3 public overmintContract;
    address public attackerWallet;

    function setUp() public {
        // Deploy the Victim contract
        overmintContract = new Overmint3();

        // Assign an attacker wallet
        attackerWallet = makeAddr("attacker");
    }

    function testExploit() public {
        // Conduct the exploit
        vm.startPrank(attackerWallet);

        AttackerDeployer attacker = new AttackerDeployer(address(overmintContract), address(attackerWallet));

        vm.stopPrank();

        // Validate the exploit
        assertEq(overmintContract.balanceOf(attackerWallet), 5, "Attacker should have 5 tokens");
        assertEq(vm.getNonce(attackerWallet), 1, "Must exploit in one transaction");
    }
}
