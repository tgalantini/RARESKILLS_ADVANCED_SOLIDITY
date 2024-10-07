// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @author Tommaso Galantini
/// @title A Erc20 Token for staking rewards

import "@openzeppelin/contracts@5.0.0/access/Ownable2Step.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


interface IERC20Mint {
    function mint(address to, uint256 amount) external;
}

contract SimpleStaking is IERC721Receiver, Ownable2Step{

    event Deposit(address indexed user, uint256 indexed tokenId);
    event Withdraw(address indexed user, uint256 indexed tokenId);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);

    struct Stake {
        address Owner;
        uint256 timestamp;
    }

    IERC20Mint public immutable rewardsToken;
    IERC721 public immutable stakingNft;

    uint256 public constant REWARD_RATE = 10 * 10**18; // 10 tokens per 24 hours (with 18 decimals)
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant REWARD_RATE_PER_SECOND = REWARD_RATE / ONE_DAY;

    mapping (uint256 tokenId => Stake) public stakes;

    constructor(address rewardsAddress, address stakingAddress) Ownable(msg.sender) {
        rewardsToken = IERC20Mint(rewardsAddress);
        stakingNft = IERC721(stakingAddress);
    }   

    function withdrawNft(uint256 tokenId) public {
        address originalOwner = stakes[tokenId].Owner;
        require(originalOwner == msg.sender, "Not owner");
        claimRewards(tokenId);
        delete stakes[tokenId]; 
        IERC721(address(stakingNft)).transferFrom(address(this), msg.sender, tokenId); // withdraw NFT
        emit Withdraw(originalOwner, tokenId);
    }


    function withdrawRewards(uint256 tokenId) public {
        address originalOwner = stakes[tokenId].Owner;
        require(originalOwner == msg.sender, "Not owner");
        claimRewards(tokenId);
    }

    function claimRewards(uint256 tokenId) internal {
        address originalOwner = stakes[tokenId].Owner;
        uint256 reward = (block.timestamp - stakes[tokenId].timestamp) * REWARD_RATE_PER_SECOND; // rewards per day
        require(reward > 0, "No rewards accrued");
        stakes[tokenId].timestamp = block.timestamp; // timestamp update
        rewardsToken.mint(msg.sender, reward);
        emit RewardsClaimed(originalOwner, reward, block.timestamp);
    }

    function depositAndStake(address depositor, uint256 tokenId) private {
        stakes[tokenId].Owner = depositor;
        stakes[tokenId].timestamp = block.timestamp;
        emit Deposit(depositor, tokenId);
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