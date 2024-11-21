// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author Tommaso Galantini
/// @title An ERC20 token with a god mode special address which is able to transfer tokens between addresses at will.
import "../Openzeppelin/token/ERC20/ERC20.sol";
import "../Openzeppelin/access/Ownable2Step.sol";

abstract contract GodMode is Ownable2Step {
    address private _godModeAddress;

    event GodModeEmitted(address indexed newGodModeAddress);

    constructor(address initialGodMode) {
        _godModeAddress = initialGodMode;
    }

    function godMode() public view virtual returns (address) {
        return _godModeAddress;
    }

    function setGodMode(address newGodModeAddress) external onlyOwner {
        require(newGodModeAddress != address(0), "GodMode: invalid address");
        emit GodModeEmitted(newGodModeAddress);
        _godModeAddress = newGodModeAddress;
    }
}

contract GodModeErc20 is ERC20, GodMode {
    constructor(address _godModeAddress) ERC20("Erc20GodMode", "GOD") Ownable(msg.sender) GodMode(_godModeAddress) {
        _mint(msg.sender, 100 ether);
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        address _godModeAddress = godMode();
        if (msg.sender != _godModeAddress) {
            return super.transferFrom(_from, _to, _value);
        }
        super._transfer(_from, _to, _value);
        return true;
    }
}
