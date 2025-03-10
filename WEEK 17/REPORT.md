# Various Smart Contracts Optimization Change Log With Gas Reports 
**@author Tommaso Galantini**

This document details the optimizations applied to the smart contract I had to optimize. It sums up all the changes I performed in order to make the contracts more optimized both in deployment cost and transaction cost, while keeping a overall high-level of readability, without recurring to assembly too much in order not to complicate the logic too much.

---

## 1. Custom Errors and using if statements instead of require.

### Old Implementations

- Used revert strings with `require` statements, for example:

```solidity
require(_timeUnit != condition.timeUnit, "Time-unit unchanged.");
```

### New Implementation

- Replaced revert strings with custom errors:

```solidity
error NotAuthorized();
error TimeUnitUnchanged();
error RewardUnchanged();
error ZeroTokensStaked();

if (not x) revert NotAuthorized();
```

**Benefit:** Reduces gas costs by removing revert string storage.

---


## 2. Assembly Optimizations

### Old Implementation

- Used standard `require` checks for zero addresses:

```solidity
require(_stakingToken != address(0), "Invalid address");
```

### New Implementation

- Optimized inline assembly check:

```solidity
assembly {
    if iszero(_stakingToken) {
        mstore(0x00, 0x20)
        mstore(0x20, 0x0c)
        mstore(0x40, 0x5a65726f20416464726573730000000000000000000000000000000000000000)
        revert(0x00, 0x60)
    }
}
```

**Benefit:** Reduces gas by optimizing low-level operations without compromising logic or readability.

---

## 3. Immutable Variables

### Old Implementation

- State variables were declared as `public` or `private` without `immutable`:

```solidity
address private _beneficiary;;
```

### New Implementation

- Updated variables to `immutable`:

```solidity
address private immutable _beneficiary;;
```

**Benefit:** Saves gas by preventing storage slot access for values known at construction that don't require future modifications.

---


## 4. Limiting storage access by caching with memory

### Old Implementation


```solidity
 // If not new deposit, calculate pending rewards (for auto-compounding)
        if (userInfo[msg.sender].amount > 0) {
            pendingRewards =
                ((userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR) -
                userInfo[msg.sender].rewardDebt;
        }
```

### New Implementation


```solidity
UserInfo memory user = userInfo[msg.sender];

        if (user.amount > 0) {
            pendingRewards =
                ((user.amount * _accTokenPerShare) / _PRECISION_FACTOR) -
                user.rewardDebt;
        }
```

**Benefit:** Saves gas by reducing repeated storage reads.


---

## 5. Updating to new optimized libraries and reducing redundant checks on operations

**Benefit:** Reduces gas usage by adapting the contracts imports to new more optimzied dependancies which provide advanced logic.

---

## 6. Optimizing for loops

### Old Implementation

- Looped through storage arrays directly:

```solidity
 for (uint256 i = 0; i < indexedTokenCount; i++) {
            _isStakerToken[i] = stakerAddress[_indexedTokens[i]] == _staker;
            if (_isStakerToken[i]) stakerTokenCount += 1;
        }
```

### New Implementation


```solidity
for (uint256 i = 0; i < len; ) {
            if (stakerAddress[_indexedTokens[i]] == _staker) {
                stakerTokenCount++;
            }
            unchecked { ++i; }
        }
```

**Benefit:** For loops have built in upper and lower boundaries so unchecked math is saving some gas here.

---

## 7. Use storage pointers instead of memory where appropriate

### Old Implementation


```solidity
function setTimeUnit(uint256 _timeUnit) external virtual {
        if (!_canSetStakeConditions()) {
            revert("Not authorized");
        }

        StakingCondition memory condition = stakingConditions[nextConditionId - 1];
        require(_timeUnit != condition.timeUnit, "Time-unit unchanged.");

        _setStakingCondition(_timeUnit, condition.rewardsPerUnitTime);

        emit UpdatedTimeUnit(condition.timeUnit, _timeUnit);
    }
```

### New Implementation


```solidity
function setTimeUnit(uint256 _timeUnit) external virtual {
        if (!_canSetStakeConditions()) revert NotAuthorized();
        StakingCondition storage condition = stakingConditions[nextConditionId - 1];
        if (_timeUnit == condition.timeUnit) revert TimeUnitUnchanged();
        _setStakingCondition(_timeUnit, condition.rewardsPerUnitTime);
        emit UpdatedTimeUnit(condition.timeUnit, _timeUnit);
    }
```

**Benefit:** In the first example we are copying all of the struct from storage into memory including variables we don’t need, making a storage pointer is cheaper because storage pointers are lazy, so they only act when called or referenced, in this case it's cheaper to do this instead of copying the whole struct to memory just to access a couple variables.

---

## 8. Updating from Openzeppeling to Solady when possible

**Benefit:** Solady offers a much optimized version of most common contracts, leevraging low level assembly to save gas on every aspect.

---


## 9. Caching storage variables to reduce multiple access.

### Old Implementation


```solidity
function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / (rewardsDuration);
        } else {
            uint256 remaining = periodFinish - (block.timestamp);
            uint256 leftover = remaining * (rewardRate);
            rewardRate = reward + (leftover) / (rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = IERC20(rewardsToken).balanceOf(address(this));
        require(rewardRate <= balance / (rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + (rewardsDuration);
        emit RewardAdded(reward);
    }
```

### New Implementation


```solidity
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
        em
```

**Benefit:** Caching storager variables into a local variable inside a function body makes substancial gas savings as storage access are costly.

---

##  Gas Reports Comparison

*LookRare Distributor*

NON OPTIMIZED:
```
╭----------------------------------------------------+-----------------+--------+--------+--------+---------╮
| src/TokenDistributor.sol:TokenDistributor Contract |                 |        |        |        |         |
+===========================================================================================================+
| Deployment Cost                                    | Deployment Size |        |        |        |         |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| 1956024                                            | 10662           |        |        |        |         |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                    |                 |        |        |        |         |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                      | Min             | Avg    | Median | Max    | # Calls |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| calculatePendingRewards                            | 1953            | 1953   | 1953   | 1953   | 1       |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| deposit                                            | 108787          | 108787 | 108787 | 108787 | 3       |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| harvestAndCompound                                 | 33005           | 33005  | 33005  | 33005  | 1       |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| userInfo                                           | 1116            | 1116   | 1116   | 1116   | 2       |
|----------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdrawAll                                        | 64509           | 64509  | 64509  | 64509  | 1       |
╰----------------------------------------------------+-----------------+--------+--------+--------+---------╯
```
OPTIMIZED:
```
╭-------------------------------------------------------------+-----------------+--------+--------+--------+---------╮
| src/TokenDistributorOptimized.sol:TokenDistributor Contract |                 |        |        |        |         |
+====================================================================================================================+
| Deployment Cost                                             | Deployment Size |        |        |        |         |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| 1594268                                                     | 8691            |        |        |        |         |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                             |                 |        |        |        |         |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                               | Min             | Avg    | Median | Max    | # Calls |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| calculatePendingRewards                                     | 1877            | 1877   | 1877   | 1877   | 1       |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| deposit                                                     | 108582          | 108582 | 108582 | 108582 | 3       |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| harvestAndCompound                                          | 32950           | 32950  | 32950  | 32950  | 1       |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| userInfo                                                    | 1116            | 1116   | 1116   | 1116   | 2       |
|-------------------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdrawAll                                                 | 64096           | 64096  | 64096  | 64096  | 1       |
╰-------------------------------------------------------------+-----------------+--------+--------+--------+---------╯
```


*Traderjoe Vesting*

NON OPTIMIZED:
```
╭--------------------------------------------+-----------------+-------+--------+-------+---------╮
| src/TokenVesting.sol:TokenVesting Contract |                 |       |        |       |         |
+=================================================================================================+
| Deployment Cost                            | Deployment Size |       |        |       |         |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| 1254473                                    | 6812            |       |        |       |         |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
|                                            |                 |       |        |       |         |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                              | Min             | Avg   | Median | Max   | # Calls |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| beneficiary                                | 2582            | 2582  | 2582   | 2582  | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| cliff                                      | 2455            | 2455  | 2455   | 2455  | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| duration                                   | 2433            | 2433  | 2433   | 2433  | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| emergencyRevoke                            | 63771           | 63771 | 63771  | 63771 | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| release                                    | 33307           | 73761 | 93988  | 93988 | 3       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| released                                   | 2851            | 2851  | 2851   | 2851  | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| revocable                                  | 2518            | 2518  | 2518   | 2518  | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| revoke                                     | 75898           | 75898 | 75898  | 75898 | 1       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| revoked                                    | 958             | 1624  | 958    | 2958  | 3       |
|--------------------------------------------+-----------------+-------+--------+-------+---------|
| start                                      | 2476            | 2476  | 2476   | 2476  | 1       |
╰--------------------------------------------+-----------------+-------+--------+-------+---------╯
```
OPTMIZED: 
```
╭-----------------------------------------------------+-----------------+-------+--------+-------+---------╮
| src/TokenVestingOptimized.sol:TokenVesting Contract |                 |       |        |       |         |
+==========================================================================================================+
| Deployment Cost                                     | Deployment Size |       |        |       |         |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| 1055763                                             | 5735            |       |        |       |         |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                     |                 |       |        |       |         |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                       | Min             | Avg   | Median | Max   | # Calls |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| beneficiary                                         | 403             | 403   | 403    | 403   | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| cliff                                               | 378             | 378   | 378    | 378   | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| duration                                            | 356             | 356   | 356    | 356   | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| emergencyRevoke                                     | 60346           | 60346 | 60346  | 60346 | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| release                                             | 30939           | 66439 | 84189  | 84189 | 3       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| released                                            | 2917            | 2917  | 2917   | 2917  | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| revocable                                           | 383             | 383   | 383    | 383   | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| revoke                                              | 65997           | 65997 | 65997  | 65997 | 1       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| revoked                                             | 958             | 1624  | 958    | 2958  | 3       |
|-----------------------------------------------------+-----------------+-------+--------+-------+---------|
| start                                               | 354             | 354   | 354    | 354   | 1       |
╰-----------------------------------------------------+-----------------+-------+--------+-------+---------╯
```


*ThirdWeb Staking*



NON OPTIMIZED:
```
╭-------------------------------------------------+-----------------+--------+--------+--------+---------╮
| test/testStaking721.sol:TestStaking721 Contract |                 |        |        |        |         |
+========================================================================================================+
| Deployment Cost                                 | Deployment Size |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| 2419503                                         | 11352           |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                 |                 |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                   | Min             | Avg    | Median | Max    | # Calls |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| claimRewards                                    | 69625           | 69625  | 69625  | 69625  | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getRewardsPerUnitTime                           | 927             | 1927   | 1927   | 2927   | 2       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getStakeInfo                                    | 7808            | 7808   | 7808   | 7808   | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getTimeUnit                                     | 968             | 2968   | 2968   | 4968   | 2       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| mintedRewards                                   | 891             | 891    | 891    | 891    | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| setRewardsPerUnitTime                           | 127144          | 127144 | 127144 | 127144 | 5       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| setTimeUnit                                     | 107220          | 111200 | 107220 | 127120 | 5       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| stake                                           | 231087          | 285139 | 312166 | 312166 | 3       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdraw                                        | 74581           | 74581  | 74581  | 74581  | 1       |
╰-------------------------------------------------+-----------------+--------+--------+--------+---------╯
```
OPTIMIZED:
```
╭-------------------------------------------------+-----------------+--------+--------+--------+---------╮
| test/testStaking721.sol:TestStaking721 Contract |                 |        |        |        |         |
+========================================================================================================+
| Deployment Cost                                 | Deployment Size |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| 2133001                                         | 9857            |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                 |                 |        |        |        |         |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                   | Min             | Avg    | Median | Max    | # Calls |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| claimRewards                                    | 69439           | 69439  | 69439  | 69439  | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getRewardsPerUnitTime                           | 927             | 1927   | 1927   | 2927   | 2       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getStakeInfo                                    | 7666            | 7666   | 7666   | 7666   | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| getTimeUnit                                     | 968             | 2968   | 2968   | 4968   | 2       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| mintedRewards                                   | 891             | 891    | 891    | 891    | 1       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| setRewardsPerUnitTime                           | 125015          | 125015 | 125015 | 125015 | 5       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| setTimeUnit                                     | 105091          | 109071 | 105091 | 124991 | 5       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| stake                                           | 230868          | 284876 | 311881 | 311881 | 3       |
|-------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdraw                                        | 74428           | 74428  | 74428  | 74428  | 1       |
╰-------------------------------------------------+-----------------+--------+--------+--------+---------╯
```

*Synthetix staking*

NON OPTIMIZED:
```
╭------------------------------------------------+-----------------+--------+--------+--------+---------╮
| src/StakingRewards.sol:StakingRewards Contract |                 |        |        |        |         |
+=======================================================================================================+
| Deployment Cost                                | Deployment Size |        |        |        |         |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| 1906700                                        | 8875            |        |        |        |         |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                |                 |        |        |        |         |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                  | Min             | Avg    | Median | Max    | # Calls |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| balanceOf                                      | 896             | 896    | 896    | 896    | 2       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| earned                                         | 2434            | 2434   | 2434   | 2434   | 1       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| notifyRewardAmount                             | 67634           | 88238  | 88238  | 108843 | 2       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| rewardsDuration                                | 2559            | 2559   | 2559   | 2559   | 1       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| rewardsToken                                   | 2771            | 2771   | 2771   | 2771   | 1       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| setRewardsDuration                             | 29558           | 29558  | 29558  | 29558  | 4       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| stake                                          | 122962          | 122970 | 122974 | 122974 | 3       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| stakingToken                                   | 2793            | 2793   | 2793   | 2793   | 1       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| totalSupply                                    | 500             | 500    | 500    | 500    | 2       |
|------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdraw                                       | 60928           | 60928  | 60928  | 60928  | 1       |
╰------------------------------------------------+-----------------+--------+--------+--------+---------╯
```
OPTIMIZED:
```
╭---------------------------------------------------------+-----------------+--------+--------+--------+---------╮
| src/StakingRewardsOptimized.sol:StakingRewards Contract |                 |        |        |        |         |
+================================================================================================================+
| Deployment Cost                                         | Deployment Size |        |        |        |         |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| 1723196                                                 | 7996            |        |        |        |         |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
|                                                         |                 |        |        |        |         |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                                           | Min             | Avg    | Median | Max    | # Calls |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| balanceOf                                               | 896             | 896    | 896    | 896    | 2       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| earned                                                  | 2742            | 2742   | 2742   | 2742   | 1       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| notifyRewardAmount                                      | 67306           | 87989  | 87989  | 108672 | 2       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| rewardsDuration                                         | 2537            | 2537   | 2537   | 2537   | 1       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| rewardsToken                                            | 2575            | 2575   | 2575   | 2575   | 1       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| setRewardsDuration                                      | 29510           | 29510  | 29510  | 29510  | 4       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| stake                                                   | 122896          | 122896 | 122896 | 122896 | 3       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| stakingToken                                            | 2619            | 2619   | 2619   | 2619   | 1       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| totalSupply                                             | 523             | 523    | 523    | 523    | 2       |
|---------------------------------------------------------+-----------------+--------+--------+--------+---------|
| withdraw                                                | 59941           | 59941  | 59941  | 59941  | 1       |
╰---------------------------------------------------------+-----------------+--------+--------+--------+---------╯
```


