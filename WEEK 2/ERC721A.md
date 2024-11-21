# ERC721A
### @author Tommaso Galantini

## How does ERC721A save gas?
    ERC721A is an innovative wrap around the ERC721 standard that allows minters to save significant gas on multiple mints. To do so, it updates the user state after a batch mint instead of updating the ownership and the balance after every mint, this is a significant update in terms of gas savings when minting more than 1 NFT. In addiction to that, the ERC721A standard does not write the ownership of all batch NFTs into storage, but only the first one, then assumes all others are owned by the same address. 

## Where does it add cost?
    The cost is added in transfers, because when transferring tokens for the first time, the ERC721A has to write into storage the new owner of the NFT, to do so it has to write a variable for the first time, making the gas cost on transfers higher.

