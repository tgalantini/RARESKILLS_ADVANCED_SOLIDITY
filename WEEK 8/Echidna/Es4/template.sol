pragma solidity ^0.8.0;

import "./token.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --test-mode assertion
///      ```
///      or by providing a config
///      ```
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --config program-analysis/echidna/exercises/exercise4/config.yaml
///      ```
contract TestToken is Token {
    function transfer(address to, uint256 value) public override {
        uint256 prevBalFrom = balances[msg.sender];
        uint256 prevBalTo = balances[to];
        super.transfer(to, value);
        assert(balances[msg.sender] <= prevBalFrom);
        assert(balances[to] >= prevBalTo);
    }


}