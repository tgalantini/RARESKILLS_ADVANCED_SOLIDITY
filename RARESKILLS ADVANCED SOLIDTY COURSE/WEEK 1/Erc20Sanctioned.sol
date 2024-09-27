// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author Tommaso Galantini
/// @title A simple Ownable ERC20 token with a sanction on sending and receiving tokens

import "@openzeppelin/contracts@5.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable2Step.sol";

contract SanctionErc20 is ERC20, Ownable2Step {
    event sanction(address indexed user);
    event sanctionRemoval(address indexed user);

    constructor() ERC20("Erc20Sanctioned", "SANC") Ownable(msg.sender) {
        _mint(msg.sender, 100 ether);
    }

    mapping(address => bool) public isBlocked;

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        require(!isBlocked[_from], "Sender is sanctioned");
        require(!isBlocked[_to], "Recipient is sanctioned");
        return super.transferFrom(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        require(!isBlocked[_to], "Recipient is sanctioned");
        require(!isBlocked[msg.sender], "Sender is sanctioned");
        return super.transfer(_to, _value);
    }

    ////@notice Sanctions an address from receiving or sending tokens
    ////@dev emits a sanction event
    function setSanction(address toSanction) public onlyOwner {
        isBlocked[toSanction] = true;
        emit sanction(toSanction);
    }

    ////@notice Removes the sanction from a previosly sanctioned address
    ////@dev emits a sanctionRemoval event
    function unsetSanction(address toUnsanction) public onlyOwner {
        isBlocked[toUnsanction] = false;
        emit sanctionRemoval(toUnsanction);
    }
}
