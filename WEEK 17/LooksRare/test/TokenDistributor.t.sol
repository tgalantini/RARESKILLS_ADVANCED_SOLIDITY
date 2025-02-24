// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


// ===== Mock ERC20 Token =====
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// ===== TokenDistributor Test =====
import "forge-std/Test.sol";
import "../src/TokenDistributorOptimized.sol"; // Adjust path to your TokenDistributor contract

contract MockERC20 is ERC20, ILooksRareToken {
    uint256 public immutable override SUPPLY_CAP;

    constructor(uint256 cap) ERC20("MockToken", "MCK") {
        SUPPLY_CAP = cap;
    }

     /// @notice Mint tokens (for testing only). Fails if minting would exceed cap.
    function mint(address to, uint256 amount) external override returns (bool) {
        require(totalSupply() + amount <= SUPPLY_CAP, "MockERC20: Exceeds cap");
        _mint(to, amount);
        return true;
    }
}



contract TokenDistributorTest is Test {
    MockERC20 token;
    TokenDistributor distributor;

    address user;
    address tokenSplitter;

    uint256[] rewardsStaking;
    uint256[] rewardsOthers;
    uint256[] periodLengths;
    uint256 numberPeriods;
    uint256 supplyCap;

    function setUp() public {
        // Setup deterministic addresses using Foundry's makeAddr.
        user = makeAddr("user");
        tokenSplitter = makeAddr("splitter");

        // Set a supply cap for testing. For example, for one period:
        // (rewardStaking + rewardOthers) * periodLength = (1+1)*100 = 200 tokens.
        supplyCap = 200;
        token = new MockERC20(supplyCap);

        // Setup reward parameters for one period.
        rewardsStaking.push(1);
        rewardsOthers.push(1);
        periodLengths.push(100); // 100 blocks duration.
        numberPeriods = 1;

        // Deploy the TokenDistributor.
        // Use block.number + 1 as the start block.
        distributor = new TokenDistributor(
            address(token),
            tokenSplitter,
            block.number + 1,
            rewardsStaking,
            rewardsOthers,
            periodLengths,
            numberPeriods
        );

        // Mint tokens to the user for deposit testing.
        token.mint(user, 50);

        // Have the user approve the distributor to spend tokens.
        vm.prank(user);
        token.approve(address(distributor), 50);
    }

    function testDeposit() public {
        vm.prank(user);
        distributor.deposit(50);

        (uint256 stakedAmount, ) = distributor.userInfo(user);
        // After deposit, the staked amount should equal the deposit.
        assertEq(stakedAmount, 50, "Deposit did not register correct amount");
        distributor.harvestAndCompound();
    }

    function testWithdrawAll() public {
        vm.prank(user);
        distributor.deposit(50);

        // Warp forward a few seconds/blocks to allow rewards to accrue.
        vm.warp(block.timestamp + 10);

        vm.prank(user);
        distributor.withdrawAll();

        (uint256 stakedAmount, ) = distributor.userInfo(user);
        // After withdrawAll, the staked amount should be zero.
        assertEq(stakedAmount, 0, "WithdrawAll did not clear staked amount");
    }

    function testCalculatePendingRewards() public {
        vm.prank(user);
        distributor.deposit(50);

        // Advance time to let rewards accrue.
        vm.warp(block.timestamp + 200);

        uint256 pendingRewards = distributor.calculatePendingRewards(user);
        
    }
}
