# Why the SafeERC20 program exists and when it should be used?
### @Author Tommaso Galantini

## The SafeERC20 program

## ERC20 Problems
#### SafeERC20 was introduced to mitigate some problems relative to standard ERC20 token implementation such as:

    - Inconsistent return values: some ERC20 tokens, do not comply to the standard, which is to return a bool value on transfers and    approvals, token such as USDT fail to return consistent values and this can lead to possible errors while interacting with such tokens.
    - Not reverting on failures: All ERC20 functions should revert on failures, however some contracts are not following this convention, and this leads to cases where functions do not revert even if they fail, this leads to silent errors.

#### How SafeERC20 solves them
SafeERC20 wraps the ERC20 standard and adds security functionalities to it, featuring low-level calls to make sure that transfers, approvals and all operations return the correct values even on reverts.

    - Inconsistent Return Values: SafeERC20 checks if the token function returns a value and if not, assumes the operation is successful, if a value is returned it checks wether it's true or false and returns it, to make sure all operations are handled properly.
    - Handling Errors: The SafeERC20 standard ensures all failures results in reverts, this is done with the low level call function which allows safe contract interctions and error handling.

    
#### SafeERC20 use cases
    The most common use cases of SafeERC20 should be Defi protocols, AMM, and all contracts that need to interact with other ERC20 tokens.
    In decentralized finance, it's crucial to handle all errors and return values in the clearest possible way, since it could lead to mistakes worth hundred thousands of dollars and mine the safety of the protocol.
