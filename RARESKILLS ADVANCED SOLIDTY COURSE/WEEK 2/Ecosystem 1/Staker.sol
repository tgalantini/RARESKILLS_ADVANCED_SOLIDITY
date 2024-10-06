// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @author Tommaso Galantini
/// @title A ERC721 staking contract with ERC20 rewards

import "@openzeppelin/contracts@5.0.0/access/Ownable2Step.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


interface IERC20Mint {
    function mint(address to, uint256 amount) external;
}

contract SimpleStaking is IERC721Receiver, Ownable2Step{

    event deposited

    struct Stake {
        address Owner;
        uint256 timestamp;
    }

    IERC20Mint public immutable rewardsToken;
    IERC721 public immutable stakingNft;

    uint256 public constant REWARD_RATE = 10 * 10**18; // 10 tokens per 24 hours (with 18 decimals)
    uint256 public constant ONE_DAY = 1 days;

    mapping (uint256 tokenId => Stake) public stakes;

    constructor(address rewardsAddress, address stakingAddress) Ownable(msg.sender) {
        rewardsToken = IERC20Mint(rewardsAddress);
        stakingNft = IERC721(stakingAddress);
    }   

    function withdrawNft(uint256 tokenId) public {
        address originalOwner = stakes[tokenId].Owner;
        require(originalOwner == msg.sender, "Not owner");
        uint256 reward = (block.timestamp - stakes[tokenId].timestamp) % ONE_DAY * REWARD_RATE; // rewards accrued
        delete stakes[tokenId]; 
        rewardsToken.mint(msg.sender, reward);
        IERC721(address(stakingNft)).transferFrom(address(this), msg.sender, tokenId); // withdraw NFT
    }

    function calculateRewards1() public pure returns(uint256){
        uint256 reward = 5 hours / ONE_DAY * REWARD_RATE; 
        return reward;
        }
    
    function calculateRewards2() public pure returns(uint256){
        uint256 reward = 5 hours % ONE_DAY * REWARD_RATE; 
        return reward;
    }

    function withdrawRewards(uint256 tokenId) public {
        address originalOwner = stakes[tokenId].Owner;
        require(originalOwner == msg.sender, "Not owner");
        require(block.timestamp - stakes[tokenId].timestamp >= ONE_DAY, "Not enough time passed since last claim");
        uint256 reward = (block.timestamp - stakes[tokenId].timestamp) % ONE_DAY * REWARD_RATE; // rewards per day
        require(reward > 0, "No rewards accrued");
        stakes[tokenId].timestamp = block.timestamp; // timestamp update
        rewardsToken.mint(msg.sender, reward);
    }

    function depositAndStake(address depositor, uint256 tokenId) private {
        stakes[tokenId].Owner = depositor;
        stakes[tokenId].timestamp = block.timestamp;
    }

    function onERC721Received(address,
        address from,
        uint256 tokenId,
        bytes calldata) external returns (bytes4) {
        require(msg.sender == address(stakingNft), "wrong NFT");
        depositAndStake(from, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

}