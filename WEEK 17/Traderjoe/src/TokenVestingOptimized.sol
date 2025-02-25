// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@solady/auth/Ownable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom Errors
error ZeroAddressBeneficiary();
error CliffLongerThanDuration();
error DurationIsZero();
error FinalTimeBeforeCurrentTime();
error NoTokensDue();
error CannotRevoke();
error TokenAlreadyRevoked();

contract TokenVesting is Ownable {

    event TokensReleased(address token, uint256 amount);
    event TokenVestingRevoked(address token);

    // Immutable parameters: stored in code and gas efficient.
    address private immutable _beneficiary;
    uint256 private immutable _cliff;
    uint256 private immutable _start;
    uint256 private immutable _duration;
    bool private immutable _revocable;

    mapping(address => uint256) private _released;
    mapping(address => bool) private _revoked;

    /// @dev Internal helper to revert using inline assembly with a custom error selector.
    function _cheapRevert(bytes4 errorSelector) internal pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary gradually in a linear fashion until start + duration.
     * @param beneficiary_ address of the beneficiary to whom vested tokens are transferred
     * @param start_ the time (as Unix time) at which vesting starts
     * @param cliffDuration_ duration in seconds of the cliff in which tokens will begin to vest
     * @param duration_ duration in seconds of the period in which the tokens will vest
     * @param revocable_ whether the vesting is revocable or not
     */
    constructor(
        address beneficiary_,
        uint256 start_,
        uint256 cliffDuration_,
        uint256 duration_,
        bool revocable_
    ){
        _initializeOwner(msg.sender);
        if (beneficiary_ == address(0)) _cheapRevert(ZeroAddressBeneficiary.selector);
        if (cliffDuration_ > duration_) _cheapRevert(CliffLongerThanDuration.selector);
        if (duration_ == 0) _cheapRevert(DurationIsZero.selector);
        if (start_ + duration_ <= block.timestamp) _cheapRevert(FinalTimeBeforeCurrentTime.selector);

        _beneficiary = beneficiary_;
        _start = start_;
        _duration = duration_;
        _cliff = start_ + cliffDuration_;
        _revocable = revocable_;
    }

    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    function cliff() public view returns (uint256) {
        return _cliff;
    }

    function start() public view returns (uint256) {
        return _start;
    }

    function duration() public view returns (uint256) {
        return _duration;
    }

    function revocable() public view returns (bool) {
        return _revocable;
    }

    function released(address token) public view returns (uint256) {
        return _released[token];
    }

    function revoked(address token) public view returns (bool) {
        return _revoked[token];
    }

    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param token ERC20 token which is being vested
     */
    function release(address token) public {
        uint256 unreleased = _releasableAmount(IERC20(token));
        if (unreleased == 0) _cheapRevert(NoTokensDue.selector);

        address tokenAddress = address(token);
        _released[tokenAddress] += unreleased;
        SafeTransferLib.safeTransfer(token, _beneficiary, unreleased);

        emit TokensReleased(tokenAddress, unreleased);
    }

    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested remain in the contract,
     * and the remainder is returned to the owner.
     * @param token ERC20 token which is being vested
     */
    function revoke(address token) public onlyOwner {
        address tokenAddress = address(token);
        if (!_revocable) _cheapRevert(CannotRevoke.selector);
        if (_revoked[tokenAddress]) _cheapRevert(TokenAlreadyRevoked.selector);

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 unreleased = _releasableAmount(IERC20(token));
        uint256 refund = balance - unreleased;

        _revoked[tokenAddress] = true;
        SafeTransferLib.safeTransfer(token, owner(), refund);
        emit TokenVestingRevoked(tokenAddress);
    }

    /**
     * @notice Allows the owner to emergency revoke and refund the entire balance,
     * including the vested amount. To be used when the beneficiary can no longer claim tokens.
     * @param token ERC20 token which is being vested
     */
    function emergencyRevoke(address token) public onlyOwner {
        address tokenAddress = address(token);
        if (!_revocable) _cheapRevert(CannotRevoke.selector);
        if (_revoked[tokenAddress]) _cheapRevert(TokenAlreadyRevoked.selector);

        uint256 balance = IERC20(token).balanceOf(address(this));
        _revoked[tokenAddress] = true;
        SafeTransferLib.safeTransfer(token, owner(), balance);
        emit TokenVestingRevoked(tokenAddress);
    }

    /// @dev Calculates the amount that has already vested but hasn't been released.
    function _releasableAmount(IERC20 token) private view returns (uint256) {
        return _vestedAmount(token) - _released[address(token)];
    }

    /// @dev Calculates the total amount that has already vested.
    function _vestedAmount(IERC20 token) private view returns (uint256) {
        address tokenAddress = address(token);
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 totalBalance = currentBalance + _released[tokenAddress];

        if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp >= _start + _duration || _revoked[tokenAddress]) {
            return totalBalance;
        } else {
            return (totalBalance * (block.timestamp - _start)) / _duration;
        }
    }
}
