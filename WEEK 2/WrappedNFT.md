# Wrapped NFT
### @author Tommaso Galantini

## Besides the examples listed in the code and the reading, what might the wrapped NFT pattern be used for?
-  Fractioning the NFT: 
    * In case of very high-valued NFTs, protocols might be interested in offering a "fractioned" version of the NFT, this allows multiple small investors to obtain a part of the NFT, without having to own the actual NFT.

- Upgrading the NFT
    * A project might be interested in adding more features to a certain NFT, they can obtain this by wrapping the NFT in a more advanced contract that has the ability to perform more actions that were not planned in advance when the original ERC721 contract was deployed.

- Renting and leasing
    * Wrapping an ERC721 token can create a system for renting or leasing NFTs. The original NFT is locked, and the wrapped version can be transferred or sold for a limited time, representing a "lease" over the original. 