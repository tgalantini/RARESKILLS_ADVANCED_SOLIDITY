pragma solidity ^0.8.20;

import "@solady/tokens/ERC20.sol";
import "@solady/utils/ReentrancyGuard.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakingRewards} from "./IStakingRewards.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is IStakingRewards, ReentrancyGuard, Pausable, Ownable {

        /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

        /* ========== ERRORS ========== */
    error cannotStakeZero();
    error cannotWithdrawZero();
    error rewardTooHigh();
    error previousRewardsPeriodNotComplete();
    error stakingTokenCannotBeRewardsToken();
    error notRewardsDistributor();


    /* ========== STATE VARIABLES ========== */
    address public rewardsDistribution;
    address public rewardsToken;
    address public stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken
    )  {
        rewardsToken = (_rewardsToken);
        stakingToken = (_stakingToken);
        rewardsDistribution = _rewardsDistribution;
        _initializeOwner(_owner);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + 
                lastTimeRewardApplicable() - (lastUpdateTime) * (rewardRate) * (1e18) / (_totalSupply)
            ;
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account] * (rewardPerToken() - (userRewardPerTokenPaid[account])) / (1e18) + (rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * (rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, cannotStakeZero());
        _totalSupply += (amount);
        _balances[msg.sender] +=  (amount);
        SafeTransferLib.safeTransferFrom(stakingToken, msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, cannotWithdrawZero());
        _totalSupply -= (amount);
        _balances[msg.sender] -= (amount);
        SafeTransferLib.safeTransfer(stakingToken, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
             SafeTransferLib.safeTransfer(rewardsToken, msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
        uint256 timestamp = block.timestamp;
        uint256 _periodFinish = periodFinish;
        uint256 _rewardDuration = rewardsDuration;

        if (timestamp >= _periodFinish) {
            rewardRate = reward / (_rewardDuration);
        } else {
            uint256 remaining = _periodFinish - (timestamp);
            uint256 leftover = remaining * (rewardRate);
            rewardRate = reward + (leftover) / (_rewardDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = IERC20(rewardsToken).balanceOf(address(this));
        require(rewardRate <= balance / (_rewardDuration), rewardTooHigh());

        lastUpdateTime = timestamp;
        periodFinish = timestamp + (_rewardDuration);
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), stakingTokenCannotBeRewardsToken());
        SafeTransferLib.safeTransfer(tokenAddress, owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            previousRewardsPeriodNotComplete()
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function setRewardsDistribution(address _rewardsDistribution) external onlyOwner {
        rewardsDistribution = _rewardsDistribution;
    }

    /* ========== MODIFIERS ========== */
    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, notRewardsDistributor());
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }


}