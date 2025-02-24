// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingRewards.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public rewardsToken;
    MockERC20 public stakingToken;
    
    address public owner = makeAddr("owner");
    address public rewardsDistribution = makeAddr("rewards");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        // Deploy mock tokens
        rewardsToken = new MockERC20("Rewards Token", "RWT");
        stakingToken = new MockERC20("Staking Token", "STK");

        // Mint initial supply
        rewardsToken.mint(rewardsDistribution, INITIAL_SUPPLY);
        stakingToken.mint(user1, INITIAL_SUPPLY);
        stakingToken.mint(user2, INITIAL_SUPPLY);

        // Deploy StakingRewards contract
        vm.startPrank(owner);
        stakingRewards = new StakingRewards(
            owner,
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );
        stakingRewards.setRewardsDuration(1 weeks);
        vm.stopPrank();
    }

    function testInitialSetup() public {
        assertEq(address(stakingRewards.rewardsToken()), address(rewardsToken));
        assertEq(address(stakingRewards.stakingToken()), address(stakingToken));
        assertEq(stakingRewards.rewardsDuration(), 7 days);
    }

    function testStakeAndWithdraw() public {
        uint256 stakeAmount = 100 ether;

        // Approve and stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewards), stakeAmount);
        stakingRewards.stake(stakeAmount);
        vm.stopPrank();

        // Check balances
        assertEq(stakingRewards.balanceOf(user1), stakeAmount);
        assertEq(stakingRewards.totalSupply(), stakeAmount);
        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakeAmount);

        // Withdraw
        vm.prank(user1);
        stakingRewards.withdraw(stakeAmount);

        // Check balances after withdrawal
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingRewards.totalSupply(), 0);
        assertEq(stakingToken.balanceOf(user1), INITIAL_SUPPLY);
    }

    function testRewardsDistribution() public {
        uint256 stakeAmount = 10 ether;
        uint256 rewardAmount = 10 ether;

        // Stake tokens
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewards), stakeAmount);
        stakingRewards.stake(stakeAmount);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(rewardsDistribution);
        rewardsToken.transfer(address(stakingRewards), rewardAmount);
        stakingRewards.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        uint256 timestamp = block.timestamp;
        vm.warp(timestamp + 1 weeks);

        // Claim rewards
        vm.prank(user1);
        uint256 earned = stakingRewards.earned(user1);
        stakingRewards.getReward();
    }

    function testExit() public {
        uint256 stakeAmount = 100 ether;
        uint256 rewardAmount = 1000 ether;

        // Stake tokens and distribute rewards
        vm.startPrank(user1);
        stakingToken.approve(address(stakingRewards), stakeAmount);
        stakingRewards.stake(stakeAmount);
        vm.stopPrank();

        vm.startPrank(rewardsDistribution);
        rewardsToken.approve(address(stakingRewards), rewardAmount);
        stakingRewards.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        // Exit
        vm.prank(user1);
        stakingRewards.exit();

        // Check balances
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingToken.balanceOf(user1), INITIAL_SUPPLY);
        assertGt(rewardsToken.balanceOf(user1), 0);
    }
}