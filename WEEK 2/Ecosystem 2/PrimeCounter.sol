// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//@author Tommaso Galantini
// Contract to cunt how many prime tokenId of a certain NFT collection an owner owns

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract PrimeNftCounter {
    
    IERC721Enumerable public nftContract;

    constructor (address _nftContract) {
        nftContract = IERC721Enumerable(_nftContract);

    }

    /**
     * @dev Returns the number of prime tokenId NFTs owned by a certain user
     * @param _owner the address of the owner to check
     * @return count The number of prime tokenId found
     */
    function countPrimeOwnedToken(address _owner) public view returns(uint256 count) {
        uint256 userBalance = nftContract.balanceOf(_owner);
        count = 0;

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(_owner, i);
            if (_isPrime(tokenId)) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Optimized prime number checker. Checks if a given number is prime.
     * @param num The number to check.
     * @return isPrime True if the number is prime, false otherwise.
     */
    function _isPrime(uint256 num) internal pure returns (bool isPrime) {
        if (num <= 1) return false; // 0 and 1 are not prime numbers
        if (num == 2 || num == 3) return true; // 2 and 3 are prime
        if (num % 2 == 0 || num % 3 == 0) return false; // eliminate multiples of 2 and 3 early

        // Only check up to the square root of `num`, and skip even numbers
        for (uint256 i = 5; i * i <= num; i += 6) { // skips by 6 to eliminate known future prime numbers
            if (num % i == 0 || num % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }

}