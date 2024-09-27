// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @author Tommaso Galantini
/// @title An untrusted escrow with a 3 days waiting time

contract UntrustedEscrow {
    using SafeERC20 for IERC20;

    event DepositMade(address indexed depositor, uint256 indexed depositIndex, address token, uint256 amount, uint256 price);
    event Withdrawal(address indexed buyer, address indexed depositor, uint256 indexed depositIndex, uint256 amount, uint256 price);
    event DepositReclaimed(address indexed depositor, uint256 indexed depositIndex, uint256 amount);

    struct depositInfo {
        address depositor;
        uint256 depositTime;
        address tokenDeposited;
        uint256 amountDeposited;
        uint256 priceOfSale;
    }

    uint256 constant delay = 3 days;
    mapping(address => mapping(uint256 => depositInfo)) public depositsInfoStorage;


    ///@notice creates a deposit of an ERC20 to be sold 3 days later
    ///@dev reverts if balance is not enough
    ///@dev reverts if the contract is not approved by the ERC20
    ///@dev reverts if allowance is not given to contract
    ///@param _tokenDeposited address of the ERC20 token to be deposited
    ///@param _amountDeposited amount to be deposited
    ///@param _priceOfSale price in WEI of the future sale
    ///@param depositIndex an index representing the deposit
    function deposit(address _tokenDeposited, uint256 _amountDeposited, uint256 _priceOfSale, uint256 depositIndex) public {
        IERC20 token = IERC20(_tokenDeposited);
        uint256 balanceBefore = token.balanceOf(address(this));

        require(_amountDeposited <= token.balanceOf(msg.sender), "Not enough balance to deposit");
        require(token.allowance(msg.sender, address(this)) >= _amountDeposited, "Not enough allowance");

        token.safeTransferFrom(msg.sender, address(this), _amountDeposited);

        uint256 actualAmountDeposited = token.balanceOf(address(this)) - balanceBefore;
        depositsInfoStorage[msg.sender][depositIndex] = depositInfo({
            depositor: msg.sender,
            depositTime: block.timestamp,
            tokenDeposited: _tokenDeposited,
            amountDeposited: actualAmountDeposited,
            priceOfSale: _priceOfSale
        });

        emit DepositMade(msg.sender, depositIndex, _tokenDeposited, actualAmountDeposited, _priceOfSale);
    }

    ///@notice gives the user capability to purchase a deposit from another user
    ///@dev reverts if 3 days is not elapsed since the deposit
    ///@dev reverts if not enough ETH is provided for the sale
    ///@param _depositIndex the index of the deposit that user wants to buy
    ///@param _depositor the address of the original depositor of the ERC20 token
    function withdraw(uint256 _depositIndex, address _depositor) external payable {
        depositInfo storage info = depositsInfoStorage[_depositor][_depositIndex];

        require(block.timestamp >= info.depositTime + delay, "3 days have not passed");
        require(msg.value == info.priceOfSale, "Not enough ETH provided for the sale");

        uint256 amountToTransfer = info.amountDeposited;
        address tokenAddress = info.tokenDeposited;

        delete depositsInfoStorage[_depositor][_depositIndex];

        IERC20(tokenAddress).safeTransfer(msg.sender, amountToTransfer);

        emit Withdrawal(msg.sender, _depositor, _depositIndex, amountToTransfer, info.priceOfSale);
    }

    ///@notice give the possibility to a depositor to reclaim his deposit after 3 days if not bought
    ///@param _depositIndex the index of deposit 
    function reclaimDeposit(uint256 _depositIndex) external {
        depositInfo storage info = depositsInfoStorage[msg.sender][_depositIndex];
        require(block.timestamp >= info.depositTime + delay, "3 days have not passed");
        require(msg.sender == info.depositor, "You are not the depositor");
        uint256 amountToTransfer = info.amountDeposited;
        address tokenAddress = info.tokenDeposited;

        delete depositsInfoStorage[msg.sender][_depositIndex];

        IERC20(tokenAddress).safeTransfer(msg.sender, amountToTransfer);

        emit DepositReclaimed(msg.sender, _depositIndex, amountToTransfer);
    }

    function getAmountDue(uint256 _depositIndex) public view returns (uint256) {
        return depositsInfoStorage[msg.sender][_depositIndex].priceOfSale;
    }

    function getDepositInfo(address _depositor, uint256 _depositIndex) public view returns(address depositor, uint256 depositTime, address tokenDeposited, uint256 amountDeposited, uint256 priceOfSale)  {
        return (depositsInfoStorage[_depositor][_depositIndex].depositor, depositsInfoStorage[_depositor][_depositIndex].depositTime, depositsInfoStorage[_depositor][_depositIndex].tokenDeposited, depositsInfoStorage[_depositor][_depositIndex].amountDeposited, depositsInfoStorage[_depositor][_depositIndex].priceOfSale);
    }
}