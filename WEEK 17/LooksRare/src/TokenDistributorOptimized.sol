// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILooksRareToken} from "./ILooksRareToken.sol";

/// @title TokenDistributor
/// @notice Distributes LOOKS tokens by auto-adjusting block rewards over a set number of periods.
contract TokenDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILooksRareToken;

    struct StakingPeriod {
        uint256 rewardPerBlockForStaking;
        uint256 rewardPerBlockForOthers;
        uint256 periodLengthInBlock;
    }

    struct UserInfo {
        uint256 amount;      // Amount of staked tokens provided by user
        uint256 rewardDebt;  // Reward debt
    }

    // Precision factor for calculating rewards.
    uint256 public constant PRECISION_FACTOR = 10**12;

    ILooksRareToken public immutable looksRareToken;
    address public immutable tokenSplitter;
    uint256 public immutable NUMBER_PERIODS;
    uint256 public immutable START_BLOCK;

    // Accumulated tokens per share.
    uint256 public accTokenPerShare;
    uint256 public currentPhase;
    uint256 public endBlock;
    uint256 public lastRewardBlock;
    uint256 public rewardPerBlockForOthers;
    uint256 public rewardPerBlockForStaking;
    uint256 public totalAmountStaked;

    mapping(uint256 => StakingPeriod) public stakingPeriod;
    mapping(address => UserInfo) public userInfo;

    event Compound(address indexed user, uint256 harvestedAmount);
    event Deposit(address indexed user, uint256 amount, uint256 harvestedAmount);
    event NewRewardsPerBlock(
        uint256 indexed currentPhase,
        uint256 startBlock,
        uint256 rewardPerBlockForStaking,
        uint256 rewardPerBlockForOthers
    );
    event Withdraw(address indexed user, uint256 amount, uint256 harvestedAmount);

    /// @notice Custom Errors
    error LengthsMismatch();
    error WrongRewardParameters();
    error DepositZeroAmount();
    error WithdrawInvalidAmount();
    error WithdrawAllZero();

    constructor(
        address _looksRareToken,
        address _tokenSplitter,
        uint256 _startBlock,
        uint256[] memory _rewardsPerBlockForStaking,
        uint256[] memory _rewardsPerBlockForOthers,
        uint256[] memory _periodLengthesInBlocks,
        uint256 _numberPeriods
    ) {
        // Ensure all arrays have length equal to _numberPeriods.
        if (
            _periodLengthesInBlocks.length != _numberPeriods ||
            _rewardsPerBlockForStaking.length != _numberPeriods ||
            _rewardsPerBlockForOthers.length != _numberPeriods
        ) revert LengthsMismatch();

        uint256 nonCirculatingSupply = ILooksRareToken(_looksRareToken).SUPPLY_CAP() -
            ILooksRareToken(_looksRareToken).totalSupply();

        uint256 amountTokensToBeMinted;
        for (uint256 i = 0; i < _numberPeriods;) {
            amountTokensToBeMinted += (_rewardsPerBlockForStaking[i] * _periodLengthesInBlocks[i]) +
                (_rewardsPerBlockForOthers[i] * _periodLengthesInBlocks[i]);
            stakingPeriod[i] = StakingPeriod({
                rewardPerBlockForStaking: _rewardsPerBlockForStaking[i],
                rewardPerBlockForOthers: _rewardsPerBlockForOthers[i],
                periodLengthInBlock: _periodLengthesInBlocks[i]
            });
            unchecked { ++i; }
        }
        if (amountTokensToBeMinted != nonCirculatingSupply) revert WrongRewardParameters();

        looksRareToken = ILooksRareToken(_looksRareToken);
        tokenSplitter = _tokenSplitter;
        rewardPerBlockForStaking = _rewardsPerBlockForStaking[0];
        rewardPerBlockForOthers = _rewardsPerBlockForOthers[0];
        START_BLOCK = _startBlock;
        endBlock = _startBlock + _periodLengthesInBlocks[0];
        NUMBER_PERIODS = _numberPeriods;
        lastRewardBlock = _startBlock;
    }

    /// @notice Deposit staked tokens and compound pending rewards.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert DepositZeroAmount();

        _updatePool();

        // Transfer LOOKS tokens to this contract.
        looksRareToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 pendingRewards;
        // Cache common variables.
        uint256 _accTokenPerShare = accTokenPerShare;
        uint256 _PRECISION_FACTOR = PRECISION_FACTOR;
        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards if user already has staked tokens.
        if (user.amount > 0) {
            pendingRewards = ((user.amount * _accTokenPerShare) / _PRECISION_FACTOR) - user.rewardDebt;
        }

        // Update user's staked amount and reward debt.
        user.amount += (amount + pendingRewards);
        user.rewardDebt = (user.amount * _accTokenPerShare) / _PRECISION_FACTOR;

        totalAmountStaked += (amount + pendingRewards);

        emit Deposit(msg.sender, amount, pendingRewards);
    }

    /// @notice Compound pending rewards.
    function harvestAndCompound() external nonReentrant {
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];
        uint256 pendingRewards = ((user.amount * accTokenPerShare) / PRECISION_FACTOR) - user.rewardDebt;
        if (pendingRewards == 0) return;

        user.amount += pendingRewards;
        totalAmountStaked += pendingRewards;
        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;

        emit Compound(msg.sender, pendingRewards);
    }

    /// @notice External trigger to update pool rewards.
    function updatePool() external nonReentrant {
        _updatePool();
    }

    /// @notice Withdraw staked tokens and compound pending rewards.
    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        if (amount == 0 || user.amount < amount) revert WithdrawInvalidAmount();

        _updatePool();

        uint256 pendingRewards = ((user.amount * accTokenPerShare) / PRECISION_FACTOR) - user.rewardDebt;

        // Update user state.
        user.amount = user.amount + pendingRewards - amount;
        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;
        totalAmountStaked = totalAmountStaked + pendingRewards - amount;

        looksRareToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, pendingRewards);
    }

    /// @notice Withdraw all staked tokens and pending rewards.
    function withdrawAll() external nonReentrant {
        UserInfo memory userSnapshot = userInfo[msg.sender];
        if (userSnapshot.amount == 0) revert WithdrawAllZero();

        _updatePool();

        uint256 pendingRewards = ((userSnapshot.amount * accTokenPerShare) / PRECISION_FACTOR) - userSnapshot.rewardDebt;
        uint256 amountToTransfer = userSnapshot.amount + pendingRewards;

        totalAmountStaked -= userSnapshot.amount;
        // Reset the user's staking info.
        userInfo[msg.sender].amount = 0;
        userInfo[msg.sender].rewardDebt = 0;

        looksRareToken.safeTransfer(msg.sender, amountToTransfer);
        emit Withdraw(msg.sender, amountToTransfer, pendingRewards);
    }

    /// @notice Calculate pending rewards for a user.
    function calculatePendingRewards(address userAddr) external view returns (uint256) {
        UserInfo storage user = userInfo[userAddr];
        if ((block.number > lastRewardBlock) && (totalAmountStaked != 0)) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 tokenRewardForStaking = multiplier * rewardPerBlockForStaking;
            uint256 adjustedEndBlock = endBlock;
            uint256 adjustedCurrentPhase = currentPhase;

            // Adjust multiplier and rewards if beyond current period.
            while ((block.number > adjustedEndBlock) && (adjustedCurrentPhase < (NUMBER_PERIODS - 1))) {
                adjustedCurrentPhase++;
                uint256 adjustedRewardPerBlockForStaking = stakingPeriod[adjustedCurrentPhase].rewardPerBlockForStaking;
                uint256 previousEndBlock = adjustedEndBlock;
                adjustedEndBlock = previousEndBlock + stakingPeriod[adjustedCurrentPhase].periodLengthInBlock;
                uint256 newMultiplier = (block.number <= adjustedEndBlock)
                    ? (block.number - previousEndBlock)
                    : stakingPeriod[adjustedCurrentPhase].periodLengthInBlock;
                tokenRewardForStaking += (newMultiplier * adjustedRewardPerBlockForStaking);
            }

            uint256 adjustedTokenPerShare = accTokenPerShare +
                (tokenRewardForStaking * PRECISION_FACTOR) /
                totalAmountStaked;

            return (user.amount * adjustedTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        } else {
            return (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        }
    }

    /// @notice Internal function to update reward variables of the pool.
    function _updatePool() internal {
        uint256 currentBlock = block.number;
        if (currentBlock <= lastRewardBlock) return;
        if (totalAmountStaked == 0) {
            lastRewardBlock = currentBlock;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, currentBlock);
        uint256 tokenRewardForStaking = multiplier * rewardPerBlockForStaking;
        uint256 tokenRewardForOthers = multiplier * rewardPerBlockForOthers;

        // Adjust rewards if current block exceeds period's end.
        while ((currentBlock > endBlock) && (currentPhase < (NUMBER_PERIODS - 1))) {
            _updateRewardsPerBlock(endBlock);
            uint256 previousEndBlock = endBlock;
            endBlock += stakingPeriod[currentPhase].periodLengthInBlock;
            uint256 newMultiplier = _getMultiplier(previousEndBlock, currentBlock);
            tokenRewardForStaking += (newMultiplier * rewardPerBlockForStaking);
            tokenRewardForOthers += (newMultiplier * rewardPerBlockForOthers);
        }

        if (tokenRewardForStaking > 0) {
            if (looksRareToken.mint(address(this), tokenRewardForStaking)) {
                accTokenPerShare += (tokenRewardForStaking * PRECISION_FACTOR) / totalAmountStaked;
            }
            looksRareToken.mint(tokenSplitter, tokenRewardForOthers);
        }

        if (lastRewardBlock <= endBlock) {
            lastRewardBlock = currentBlock;
        }
    }

    /// @notice Internal function to update rewards per block when a period ends.
    function _updateRewardsPerBlock(uint256 _newStartBlock) internal {
        currentPhase++;
        StakingPeriod storage currentStakingPeriod = stakingPeriod[currentPhase];
        rewardPerBlockForStaking = currentStakingPeriod.rewardPerBlockForStaking;
        rewardPerBlockForOthers = currentStakingPeriod.rewardPerBlockForOthers;
        emit NewRewardsPerBlock(currentPhase, _newStartBlock, rewardPerBlockForStaking, rewardPerBlockForOthers);
    }

    /// @notice Returns the reward multiplier over the given block range.
    function _getMultiplier(uint256 from, uint256 to) internal view returns (uint256) {
        if (to <= endBlock) {
            return to - from;
        } else if (from >= endBlock) {
            return 0;
        } else {
            return endBlock - from;
        }
    }
}
