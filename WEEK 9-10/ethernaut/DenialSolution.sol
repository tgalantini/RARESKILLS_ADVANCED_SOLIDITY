// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
contract AttackerContract {
    
    fallback() payable external {
        while(true){}
    }
    
}