// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//@author Tommaso Galantini
// A simple ERC721Enumerable that can handle up to 100 tokens


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EnumerableNft is ERC721Enumerable, Ownable {

    uint256 public constant MAX_SUPPLY = 100; 
    uint256 public nextTokenId = 1; // The next token ID to be minted

    constructor() ERC721("EnumerableNft", "ENUM") Ownable(msg.sender) {
    }

    /**
     * @dev Mint NFTs to the specified address.
     * Only the owner can mint, and token IDs will range from 1 to 100.
     */
    function mintNFT(address to) external {
        require(nextTokenId <= MAX_SUPPLY, "All tokens have been minted");

        _mint(to, nextTokenId);
        nextTokenId++; 
    }

    /**
     * @dev Batch mint multiple NFTs at once. 
     * Only the owner can batch mint.
     */
    function batchMint(address to, uint256 quantity) external {
        require(nextTokenId + quantity - 1 <= MAX_SUPPLY, "Exceeds max supply");

        for (uint256 i = 0; i < quantity; i++) {
            _mint(to, nextTokenId);
            nextTokenId++;
        }
    }
}
