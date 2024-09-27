// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author Tommaso Galantini
/// @title A Erc20 Token with bonding curve sale strategy

import "@openzeppelin/contracts@5.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable2Step.sol";

contract Erc20SaleBonding is ERC20, Ownable2Step {

    uint256 public totalSold; // Total tokens sold through the bonding curve
    uint256 public constant INITIAL_PRICE = 0.001 ether; // Starting price for the token
    uint256 public constant INCREASE_RATE = 0.00001 ether; // How much the price increases per token
    mapping (address => uint256) private lastUserTransaction; // maps the last user sale or purchase with the block timestamp

    constructor() ERC20("Erc20SaleBonding", "CURV") Ownable(msg.sender) {
    }   

    ////@notice Gives the user possibility to buy tokens from contract sale
    function buyTokens(uint256 amount) external payable {
        require(lastUserTransaction[msg.sender] != block.timestamp, "Cannot perform two sale or buy transactions in same block");
        uint256 cost = getPriceForTokens(amount);
        require(msg.value == cost, "Not enough Ether sent.");
        _mint(msg.sender, amount);
        totalSold += amount;
        lastUserTransaction[msg.sender] = block.timestamp;
    }

    ////@notice Sell tokens back to the bonding curve and burn them
    function sellTokens(uint256 amount) external {
        require(lastUserTransaction[msg.sender] != block.timestamp, "Cannot perform two sale or buy transactions in same block");
        require(balanceOf(msg.sender) >= amount, "Not enough tokens to sell.");
        uint256 paybackAmount = getSellPriceForTokens(amount);
        _burn(msg.sender, amount);
        totalSold -= amount;
        (bool s, ) = msg.sender.call{value: paybackAmount}("");
        require(s, "Sale refund failed.");
        lastUserTransaction[msg.sender] = block.timestamp;
    }

    ////@notice lets the owner withdraw the smart contract balance
    function withdrawEther() external onlyOwner {
        (bool success, ) = address(this).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    ////@notice Calculate the price of the next token based on the current number of tokens sold
    function getCurrentPrice() public view returns (uint256) {
        return INITIAL_PRICE + totalSold * INCREASE_RATE;
    }

     ////@notice Calculate the total sale price for selling `amount` tokens
    function getSellPriceForTokens(uint256 amount) public view returns (uint256) {
        require(totalSold >= amount, "Not enough tokens sold.");
        uint256 _currentPrice = getCurrentPrice();
        return amount * _currentPrice - (amount * (amount - 1)) / 2 * INCREASE_RATE;
    }

    ////@notice Calculate the price to buy the next `amount` tokens
    function getPriceForTokens(uint256 amount) public view returns (uint256) {
        uint256 _currentPrice = getCurrentPrice();
        return amount * _currentPrice + (amount * (amount - 1)) / 2 * INCREASE_RATE;
    }

    receive() external payable {
        revert();
    }

}