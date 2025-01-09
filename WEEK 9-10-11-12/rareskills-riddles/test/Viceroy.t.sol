// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Viceroy.sol";


contract ViceroyTest is Test {
    OligarchyNFT public oligarch;
    Governance public governance;
    CommunityWallet public communityWallet;
    GovernanceAttacker public attacker;

    address public attackerWallet;
    address public deployer;

    function setUp() public {
        // Assign wallet addresses
        deployer = address(this); // Foundry test deployer
        attackerWallet = makeAddr("attacker");

        // Deploy GovernanceAttacker contract (minting the NFT to it)
        vm.startPrank(attackerWallet);
        attacker = new GovernanceAttacker();
        vm.stopPrank();

        // Deploy OligarchyNFT contract with the attacker as the initial NFT holder
        oligarch = new OligarchyNFT(address(attacker));

        // Deploy Governance contract with 10 ETH in the CommunityWallet
        vm.deal(deployer, 10 ether); // Fund deployer for contract deployment
        governance = new Governance{value: 10 ether}(oligarch);

        // Retrieve the CommunityWallet address
        communityWallet = CommunityWallet(payable(governance.communityWallet()));

        // Assert that the CommunityWallet was initialized with 10 ETH
        assertEq(address(communityWallet).balance, 10 ether, "CommunityWallet should be funded");
    }

    function testExploit() public {
        // Simulate attacker wallet
        vm.startPrank(attackerWallet);
        console.log(attacker.governance.address);

        // Execute the attack using the attacker contract
        attacker.attack(address(governance));

        vm.stopPrank();

        // Validate that the attack successfully drained the CommunityWallet
        assertEq(address(communityWallet).balance, 0, "CommunityWallet should be empty");

        // Validate the attacker's wallet balance
        uint256 attackerBalance = attackerWallet.balance;
        assertGe(attackerBalance, 10 ether, "Attacker must recover at least 10 ETH");

        // Validate that the attacker performed only two transactions
        uint256 transactionCount = vm.getNonce(attackerWallet);
        assertEq(transactionCount, 1, "Attacker must exploit in one transaction");
    }
}
