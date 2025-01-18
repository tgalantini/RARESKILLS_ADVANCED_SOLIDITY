// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ReadOnly.sol";


contract ReadOnlyTest is Test {
    ReadOnlyPool public readOnlyPool;
    VulnerableDeFiContract public vulnerableDeFiContract;
    address public attacker;
    AttackerContract attackerContract;

    function setUp() public {
        attacker = makeAddr("attacker");

        // Deploy the ReadOnlyPool contract
        readOnlyPool = new ReadOnlyPool();

        // Deploy the VulnerableDeFiContract and link it to ReadOnlyPool
        vulnerableDeFiContract = new VulnerableDeFiContract((readOnlyPool));

        attackerContract = new AttackerContract(readOnlyPool, vulnerableDeFiContract, address(attacker));

        // Add liquidity and profit to ReadOnlyPool
        readOnlyPool.addLiquidity{value: 100 ether}();
        readOnlyPool.earnProfit{value: 1 ether}();

        // Take a snapshot of the LP token price
        vulnerableDeFiContract.snapshotPrice();

        // Set up the attacker's initial balance
        vm.deal(attacker, 2 ether);
    }

    function testExploit() public {
        vm.startPrank(attacker);
        
        attackerContract.exploit{value: address(attacker).balance}();
        vm.stopPrank();

        // Verify that the exploit succeeded
        assertEq(vulnerableDeFiContract.lpTokenPrice(), 0, "Snapshot price should be zero");
        uint256 transactionCount = vm.getNonce(attacker);
        assertLt(transactionCount, 3, "Attacker must exploit in one transaction");
    }
}
