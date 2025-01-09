# Naughtcoing has a modifier lockTokens that prevents the ownerr from transferring tokens before lock time expires.
    However, this is poorly made, since it checks for msg.sender and not *from* param.
    Exploit is made by approving a second address and calling TransferFrom to move tokens.