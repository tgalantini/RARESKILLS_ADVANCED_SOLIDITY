# Solving Capture The Ether TokenWhale challenge

The contract has a flaw that relies on solidity 0.5 previous versions, which is underflow and overflow.
Also there is a major flaw in the internal _transfer function which assumes always that the "from" parameter is msg.sender, resulting in a bug when called by TransferFrom function.

# Attack Flow
    - Transfer 1000 tokens to address B
    - Address B gives unlimited approval to address A (player)
    - Address A calls TransferFrom(B, C, 1000)
    
    This will lead in underflow in Address A balance, which will bring it's balance to MAX_UINT256
