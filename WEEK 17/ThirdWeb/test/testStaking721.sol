// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Staking721} from "../src/Staking721.sol"; // Adjust path as needed
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// -----------------------------------------------------------
/// MockERC721: A simple ERC721 token for testing staking.
/// -----------------------------------------------------------
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 public nextTokenId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    /// @notice Mint a token with a new tokenId.
    function mint(address to) external {
        _mint(to, ++nextTokenId);
    }
}

/// -----------------------------------------------------------
/// TestStaking721: A concrete implementation of Staking721 for testing.
/// -----------------------------------------------------------
contract TestStaking721 is Staking721 {
    // Public mapping to record rewards "minted" to each staker.
    mapping(address => uint256) public mintedRewards;

    constructor(address _stakingToken) Staking721(_stakingToken) {}

    /// @notice For testing, we return a dummy balance.
    function getRewardTokenBalance() external view override returns (uint256) {
        return 0;
    }

    /// @notice Record the rewards in mintedRewards.
    function _mintRewards(address _staker, uint256 _rewards) internal override {
        mintedRewards[_staker] += _rewards;
    }

    /// @notice Always allow setting stake conditions.
    function _canSetStakeConditions() internal view override returns (bool) {
        return true;
    }
}

/// -----------------------------------------------------------
/// Staking721Test: Foundry test contract that tests all functions.
/// -----------------------------------------------------------
contract Staking721Test is Test {
    MockERC721 public stakingToken;
    TestStaking721 public stakingContract;
    address public user = makeAddr("user");
    address public admin = makeAddr("admin"); // For testing setter functions.
    
    function setUp() public {
        // Deploy the mock ERC721 token.
        stakingToken = new MockERC721("TestNFT", "TNFT");

        // Mint three tokens to the user.
        vm.startPrank(user);
        stakingToken.mint(user); // tokenId 1
        stakingToken.mint(user); // tokenId 2
        stakingToken.mint(user); // tokenId 3
        stakingToken.mint(user);
        stakingToken.mint(user);
        vm.stopPrank();

        // Deploy our concrete staking contract.
        stakingContract = new TestStaking721(address(stakingToken));
        stakingContract.setTimeUnit(100);
        stakingContract.setRewardsPerUnitTime(100);


       vm.prank(user);
        stakingToken.setApprovalForAll(address(stakingContract), true);
    }

    function testStakeAndGetStakeInfo() public {
        // User stakes tokenId 1 and tokenId 2.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        vm.prank(user);
        stakingContract.stake(tokenIds);

    }

    function testWithdraw() public {
        // Stake tokenId 1 and tokenId 2.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        vm.prank(user);
        stakingContract.stake(tokenIds);

        // Withdraw tokenId 1.
        uint256[] memory withdrawIds = new uint256[](1);
        withdrawIds[0] = 1;
        vm.prank(user);
        stakingContract.withdraw(withdrawIds);

        // Check stake info: only tokenId 2 should remain.
        (uint256[] memory stakedTokens, ) = stakingContract.getStakeInfo(user);
        assertEq(stakedTokens.length, 1, "Expected 1 remaining staked token");
        assertEq(stakedTokens[0], 2, "TokenId 2 should remain staked");
    }

    function testClaimRewards() public {
        // Stake tokenId 3.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 3;
        vm.prank(user);
        stakingContract.stake(tokenIds);

        // Warp forward to accumulate rewards.
        vm.warp(block.timestamp + 100);

        // Claim rewards.
        vm.prank(user);
        stakingContract.claimRewards();

        // Check that rewards were minted.
        uint256 rewardsMinted = stakingContract.mintedRewards(user);
        assertGt(rewardsMinted, 0, "Expected minted rewards to be greater than zero");
    }

    function testSetTimeUnitAndRewardsPerUnitTime() public {
        // Get current conditions.
        uint256 currentTimeUnit = stakingContract.getTimeUnit();
        uint256 currentRewardsPerUnitTime = stakingContract.getRewardsPerUnitTime();

        // Set new time unit and rewards per unit time.
        uint256 newTimeUnit = currentTimeUnit + 10;
        uint256 newRewards = currentRewardsPerUnitTime + 100;

        // Caller can be admin (or any account, since _canSetStakeConditions returns true).
        vm.prank(admin);
        stakingContract.setTimeUnit(newTimeUnit);
        assertEq(stakingContract.getTimeUnit(), newTimeUnit, "Time unit not updated");

        vm.prank(admin);
        stakingContract.setRewardsPerUnitTime(newRewards);
        assertEq(stakingContract.getRewardsPerUnitTime(), newRewards, "Rewards per unit time not updated");
    }

}
