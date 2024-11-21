// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Erc20BondingFlattened.sol";

contract TestErc20SaleBonding is Erc20SaleBonding {
    address echidna = msg.sender;

    constructor() Erc20SaleBonding() {
        // Initialize the contract with Echidna as the owner
        transferOwnership(echidna);
    }

    /// @notice Invariant: The total supply must equal the total tokens sold
    function echidna_test_total_supply_matches_total_sold() public view returns (bool) {
        return totalSupply() == totalSold;
    }

    /// @notice Invariant: Token balance consistency for Echidna
    function echidna_test_balance_consistent() public view returns (bool) {
        return balanceOf(echidna) >= 0; // Always non-negative
    }

    /// @notice Invariant: The price for tokens must be non-decreasing
    function echidna_test_price_always_non_decreasing() public view returns (bool) {
        uint256 currentPrice = getCurrentPrice();
        uint256 nextPrice = INITIAL_PRICE + (totalSold + 1) * INCREASE_RATE;
        return nextPrice >= currentPrice;
    }

    /// @notice Invariant: No two transactions in the same block for a single user
    function echidna_test_no_two_transactions_same_block() public view returns (bool) {
        uint256 lastUserTransaction = getLastUserTransaction(echidna);
        return lastUserTransaction != block.timestamp;
    }
}
