pragma solidity ^0.8.0;

// Desktop/RARESKILLS ADVANCED SOLIDTY COURSE/WEEK 8/Echidna/Es3/token.sol

/// @notice The issues from exercise 1 and 2 are fixed.

contract Ownable {
    address public owner = msg.sender;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: Caller is not the owner.");
        _;
    }
}

contract Pausable is Ownable {
    bool private _paused;

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner {
        _paused = true;
    }

    function resume() public onlyOwner {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: Contract is paused.");
        _;
    }
}

contract Token is Ownable, Pausable {
    mapping(address => uint256) public balances;

    function transfer(address to, uint256 value) public whenNotPaused {
        balances[msg.sender] -= value;
        balances[to] += value;
    }
}

// Desktop/RARESKILLS ADVANCED SOLIDTY COURSE/WEEK 8/Echidna/Es3/mintable.sol

contract MintableToken is Token {
    uint256 public totalMinted;
    uint256 public totalMintable;

    constructor(uint256 totalMintable_) {
        totalMintable = totalMintable_;
    }

    function mint(uint256 value) public onlyOwner {
        require((value + totalMinted) < totalMintable);
        totalMinted += value;

        balances[msg.sender] += value;
    }
}

