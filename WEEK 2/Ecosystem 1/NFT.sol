// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @author Tommaso Galantini
/// @title A ERC721 Token with a bitmap merkle tree whitelist

import {ERC721A} from "erc721a/contracts/ERC721A.sol";  
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol"; 
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; 
import {BitMaps} from"@openzeppelin/contracts/utils/structs/BitMaps.sol"; 
import "@openzeppelin/contracts@5.0.0/access/Ownable2Step.sol";

contract ERC721AToStake is ERC721A, ERC2981, Ownable2Step {

    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant DISCOUNT_PRICE = 0.05 ether; 
    uint96 public constant ROYALTY_FEE_NUMERATOR = 250;
    uint256 public constant WHITELIST_CAP = 700;

    BitMaps.BitMap private _whitelist;
    bytes32 public merkleRoot; 

    constructor(bytes32 _merkleRoot, address royaltyReceiver) ERC721A("RareNft", "RARE") Ownable(msg.sender) {
        merkleRoot = _merkleRoot;
        _setDefaultRoyalty(royaltyReceiver, ROYALTY_FEE_NUMERATOR); 
    }

    /**
     * @dev Public mint function
     */
    function mint(uint256 amount) external payable {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        require(msg.value == PRICE * amount, "Insufficient payment");
        _mint(msg.sender, amount);
    }

    /**
     * @dev Whitelist mint with discount, using Merkle Proof and OpenZeppelin BitMap
     */
    function mintWithDiscount(bytes32[] calldata merkleProof, uint256 index, uint256 amount) external payable {
        require(totalSupply() + amount <= WHITELIST_CAP, "Max whitelist supply exceeded");
        require(!BitMaps.get(_whitelist, index), "Address already claimed his allocation");
        require(msg.value == DISCOUNT_PRICE * amount, "Insufficient payment for discounted mint");
        _verifyProof(merkleProof, index, amount, msg.sender);
        BitMaps.setTo(_whitelist, index, true);
        _mint(msg.sender, amount);
    }

    /**
     * @dev Private function to verify the proof given
     */
    function _verifyProof(bytes32[] memory proof, uint256 index, uint256 amount, address addr) private view {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, index, amount))));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
    }

    /**
     * @dev Admin function to set a new Merkle root for the whitelist
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev Override supportsInterface to include ERC721, ERC2981 interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Withdraw funds collected from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
