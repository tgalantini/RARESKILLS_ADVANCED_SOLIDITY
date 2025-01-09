// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/RetirementFund.sol";

contract RetirementFundTest is Test {
    RetirementFund public retirementFund;
    ExploitContract public exploitContract;
    address player = makeAddr("player");

    function setUp() public {
        // Deploy contracts
        retirementFund = (new RetirementFund){value: 1 ether}(player);
        exploitContract = new ExploitContract(retirementFund);
    }

    function testIncrement() public {
        vm.deal(address(exploitContract), 1 ether);
        // Test your Exploit Contract below
        // Use the instance retirementFund and exploitContract
        vm.deal(player, 1 ether);
        vm.startPrank(player);
        exploitContract.exploit{value : 1 ether}();
        retirementFund.collectPenalty();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(retirementFund.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
