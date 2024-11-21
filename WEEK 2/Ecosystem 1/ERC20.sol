// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @author Tommaso Galantini
/// @title A Erc20 Token for staking rewards

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {

    address public stakingContract;
    // Initial supply is zero, and tokens will be minted as rewards.
    constructor(address _stakingContract) ERC20("RewardToken", "RTK") Ownable(msg.sender) {
        stakingContract = _stakingContract;
    }

    function setNewStakingContract(address _stakingContract) external onlyOwner{
        stakingContract = _stakingContract;
    }

    /**
     * @dev Mints new tokens to the specified address.
     * Can only be called by the owner (staking contract or admin).
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == stakingContract, "Unauthorized");
        _mint(to, amount);
    }
}
