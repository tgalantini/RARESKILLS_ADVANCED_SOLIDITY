// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author thirdweb

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import  {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./IStaking721.sol";

/// Custom Errors to save gas on reverts
error NotAuthorized();
error TimeUnitUnchanged();
error RewardUnchanged();
error ZeroTokensStaked();
error WithdrawingZeroTokens();
error WithdrawingMoreThanStaked();
error NoRewards();
error TimeUnitZero();
error NotStaker();

abstract contract Staking721 is ReentrancyGuard, IStaking721 {
    /*///////////////////////////////////////////////////////////////
                            State variables / Mappings
    //////////////////////////////////////////////////////////////*/

    /// @dev Address of ERC721 NFT contract -- staked tokens belong to this contract.
    address public immutable stakingToken;

    /// @dev Flag to check direct transfers of staking tokens.
    uint8 internal isStaking = 1;

    /// @dev Next staking condition Id. Tracks number of condition updates so far.
    uint64 private nextConditionId = 1;

    /// @dev List of token-ids ever staked.
    uint256[] public indexedTokens;

    /// @dev List of accounts that have staked their NFTs.
    address[] public stakersArray;

    /// @dev Mapping from token-id to whether it is indexed or not.
    mapping(uint256 => bool) public isIndexed;

    /// @dev Mapping from staker address to Staker struct.
    mapping(address => Staker) public stakers;

    /// @dev Mapping from staked token-id to staker address.
    mapping(uint256 => address) public stakerAddress;

    /// @dev Mapping from condition Id to staking condition.
    mapping(uint256 => StakingCondition) private stakingConditions;

    constructor(address _stakingToken) {
        assembly {
            if iszero(_stakingToken) {
                mstore(0x00, 0x20)
                mstore(0x20, 0x0c)
                mstore(0x40, 0x5a65726f20416464726573730000000000000000000000000000000000000000)
                revert(0x00, 0x60)
            }
        }
        stakingToken = _stakingToken;
    }

    /*///////////////////////////////////////////////////////////////
                        External/Public Functions
    //////////////////////////////////////////////////////////////*/

    function stake(uint256[] calldata _tokenIds) external nonReentrant {
        _stake(_tokenIds);
    }

    function withdraw(uint256[] calldata _tokenIds) external nonReentrant {
        _withdraw(_tokenIds);
    }

    function claimRewards() external nonReentrant {
        _claimRewards();
    }

    function setTimeUnit(uint256 _timeUnit) external virtual {
        if (!_canSetStakeConditions()) revert NotAuthorized();
        StakingCondition storage condition = stakingConditions[nextConditionId - 1];
        if (_timeUnit == condition.timeUnit) revert TimeUnitUnchanged();
        _setStakingCondition(_timeUnit, condition.rewardsPerUnitTime);
        emit UpdatedTimeUnit(condition.timeUnit, _timeUnit);
    }

    function setRewardsPerUnitTime(uint256 _rewardsPerUnitTime) external virtual {
        if (!_canSetStakeConditions()) revert NotAuthorized();
        StakingCondition storage condition = stakingConditions[nextConditionId - 1];
        if (_rewardsPerUnitTime == condition.rewardsPerUnitTime) revert RewardUnchanged();
        _setStakingCondition(condition.timeUnit, _rewardsPerUnitTime);
        emit UpdatedRewardsPerUnitTime(condition.rewardsPerUnitTime, _rewardsPerUnitTime);
    }

    function getStakeInfo(
        address _staker
    ) external view virtual returns (uint256[] memory _tokensStaked, uint256 _rewards) {
        uint256[] memory _indexedTokens = indexedTokens;
        uint256 len = _indexedTokens.length;
        uint256 stakerTokenCount;
        for (uint256 i = 0; i < len; ) {
            if (stakerAddress[_indexedTokens[i]] == _staker) {
                stakerTokenCount++;
            }
            unchecked { ++i; }
        }
        _tokensStaked = new uint256[](stakerTokenCount);
        uint256 count;
        for (uint256 i = 0; i < len; ) {
            if (stakerAddress[_indexedTokens[i]] == _staker) {
                _tokensStaked[count] = _indexedTokens[i];
                count++;
            }
            unchecked { ++i; }
        }
        _rewards = _availableRewards(_staker);
    }

    function getTimeUnit() public view returns (uint256 _timeUnit) {
        _timeUnit = stakingConditions[nextConditionId - 1].timeUnit;
    }

    function getRewardsPerUnitTime() public view returns (uint256 _rewardsPerUnitTime) {
        _rewardsPerUnitTime = stakingConditions[nextConditionId - 1].rewardsPerUnitTime;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _stake(uint256[] calldata _tokenIds) internal virtual {
        uint64 len = uint64(_tokenIds.length);
        if (len == 0) revert ZeroTokensStaked();

        address sender = _stakeMsgSender();
        if (stakers[sender].amountStaked > 0) {
            _updateUnclaimedRewardsForStaker(sender);
        } else {
            stakersArray.push(sender);
            stakers[sender].timeOfLastUpdate = uint128(block.timestamp);
            stakers[sender].conditionIdOflastUpdate = nextConditionId - 1;
        }

        address _stakingToken = stakingToken;
        for (uint256 i = 0; i < len; ) {
            isStaking = 2;
            IERC721(_stakingToken).transferFrom(sender, address(this), _tokenIds[i]);
            isStaking = 1;
            stakerAddress[_tokenIds[i]] = sender;
            if (!isIndexed[_tokenIds[i]]) {
                isIndexed[_tokenIds[i]] = true;
                indexedTokens.push(_tokenIds[i]);
            }
            unchecked { ++i; }
        }
        stakers[sender].amountStaked += len;
        emit TokensStaked(sender, _tokenIds);
    }

    function _withdraw(uint256[] calldata _tokenIds) internal virtual {
        address sender = _stakeMsgSender();
        uint256 amountStaked = stakers[sender].amountStaked;
        uint64 len = uint64(_tokenIds.length);
        if (len == 0) revert WithdrawingZeroTokens();
        if (amountStaked < len) revert WithdrawingMoreThanStaked();


        address _stakingToken = stakingToken;
        _updateUnclaimedRewardsForStaker(sender);

        if (amountStaked == len) {
            uint256 arrLen = stakersArray.length;
            for (uint256 i = 0; i < arrLen; ) {
                if (stakersArray[i] == sender) {
                    stakersArray[i] = stakersArray[arrLen - 1];
                    stakersArray.pop();
                    break;
                }
                unchecked { ++i; }
            }
        }
        stakers[sender].amountStaked -= len;

        for (uint256 i = 0; i < len; ) {
            if (stakerAddress[_tokenIds[i]] != sender) revert NotStaker();
            stakerAddress[_tokenIds[i]] = address(0);
            IERC721(_stakingToken).transferFrom(address(this), sender, _tokenIds[i]);
            unchecked { ++i; }
        }
        emit TokensWithdrawn(sender, _tokenIds);
    }

    function _claimRewards() internal virtual {
        address sender = _stakeMsgSender();
        uint256 rewards = stakers[sender].unclaimedRewards + _calculateRewards(sender);
        if (rewards == 0) revert NoRewards();

        stakers[sender].timeOfLastUpdate = uint128(block.timestamp);
        stakers[sender].unclaimedRewards = 0;
        stakers[sender].conditionIdOflastUpdate = nextConditionId - 1;
        _mintRewards(sender, rewards);
        emit RewardsClaimed(sender, rewards);
    }

    function _availableRewards(address _user) internal view virtual returns (uint256 _rewards) {
        if (stakers[_user].amountStaked == 0) {
            _rewards = stakers[_user].unclaimedRewards;
        } else {
            _rewards = stakers[_user].unclaimedRewards + _calculateRewards(_user);
        }
    }

    function _updateUnclaimedRewardsForStaker(address _staker) internal virtual {
        uint256 rewards = _calculateRewards(_staker);
        stakers[_staker].unclaimedRewards += rewards;
        stakers[_staker].timeOfLastUpdate = uint128(block.timestamp);
        stakers[_staker].conditionIdOflastUpdate = nextConditionId - 1;
    }

    function _setStakingCondition(uint256 _timeUnit, uint256 _rewardsPerUnitTime) internal virtual {
        if (_timeUnit == 0) revert TimeUnitZero();
        uint256 conditionId = nextConditionId;
        nextConditionId += 1;

        stakingConditions[conditionId] = StakingCondition({
            timeUnit: _timeUnit,
            rewardsPerUnitTime: _rewardsPerUnitTime,
            startTimestamp: block.timestamp,
            endTimestamp: 0
        });
        if (conditionId > 0) {
            stakingConditions[conditionId - 1].endTimestamp = block.timestamp;
        }
    }

    /// @dev Calculate rewards for a staker.
    function _calculateRewards(address _staker) internal view virtual returns (uint256 _rewards) {
        Staker memory staker = stakers[_staker];

        uint256 _stakerConditionId = staker.conditionIdOflastUpdate;
        uint256 _nextConditionId = nextConditionId;

        for (uint256 i = _stakerConditionId; i < _nextConditionId; i += 1) {
            StakingCondition memory condition = stakingConditions[i];

            uint256 startTime = i != _stakerConditionId ? condition.startTimestamp : staker.timeOfLastUpdate;
            uint256 endTime = condition.endTimestamp != 0 ? condition.endTimestamp : block.timestamp;

              (bool noOverflowProduct, uint256 rewardsProduct) = Math.tryMul(
                (endTime - startTime) * staker.amountStaked,
                condition.rewardsPerUnitTime
            );
            (bool noOverflowSum, uint256 rewardsSum) = Math.tryAdd(_rewards, rewardsProduct / condition.timeUnit);

            _rewards = rewardsSum;
        }
    }

    /*////////////////////////////////////////////////////////////////////
        Optional hooks that can be implemented in the derived contract
    ///////////////////////////////////////////////////////////////////*/

    function _stakeMsgSender() internal virtual returns (address) {
        return msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
        Virtual functions to be implemented in derived contract
    //////////////////////////////////////////////////////////////*/

    function getRewardTokenBalance() external view virtual returns (uint256 _rewardsAvailableInContract);
    function _mintRewards(address _staker, uint256 _rewards) internal virtual;
    function _canSetStakeConditions() internal view virtual returns (bool);
}
