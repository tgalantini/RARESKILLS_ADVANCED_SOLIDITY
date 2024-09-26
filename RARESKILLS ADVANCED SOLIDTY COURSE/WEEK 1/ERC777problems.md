# Solutions and problems about ERC777 and ERC1363. Why was ERC1363 introduced, and what issues are there with ERC777?
### @Author Tommaso Galantini
## ERC777 PROBLEMS SOLVED

* Lack of Hooks for Smart Contracts
    - In ERC20, tokens sent to contracts are treated as just data. If a user mistakenly sends tokens to a contract that isn’t designed to accept them, those tokens may be stuck forever like in USDC contract. ERC777 send and receive hooks solve this by allowing contracts to reject or react to token transfers.

* Approve/TransferFrom double transaction
    - ERC20’s two-step process (approve and transferFrom) for delegating transfers results in higher gas costs, especially in dApps that need to perform multiple actions in a single transaction. ERC777 operator system reduces gas costs and enhances user experience. This also solved a potential race attack where bad actors could make unspent approvals malicious.
    
## ERC777 ISSUES

* Complexity
    - ERC777 introduced a completely new way of transferring ERC20 tokens, solving the approve/transfer double transaction problem, however even if providing many exciting updates, the complexity of the standard makes it very difficult to understand it and for developers to make updates on it and create infrastructures relying around it.
* Reentrancy
    - ERC777 when used in a Defi environment like Uniswap, where it is used inside a liquidity pool to trade the token, becomes very dangerous as it's "send" hook leads to reentrancy vulnerabilities. The main difference between a ERC20 transfer and a ERC777 send is that ERC777 makes contract calls both to the receiving and the sending parties of the transaction, and this leads to a potential reentrancy attack. This problem was solved in the openzeppelin's ERC777 version, which makes additional checks before making external contract calls.
* Lack of adoption
    - The complexity of ERC777 mixed with the popularity of ERC20 made the adoption of ERC777 very difficult, adding to that the possibility of reentrancy attacks when misconfigured gave a bad popularity to ERC777.

## ERC1363 PROBLEMS SOLVED

* Transfer hooks
    - ERC1363 enhances ERC20 tokens, allowing receiving contracts to be notified upon the incoming transfer of a token. New functions are introduced like transferAndCall() which transfers tokens and then triggers a function call on the recipient contract, which can make it's own actions upon arrival. This makes it possible for the recipient contract to react to the token transfer or approval. For example, it can automatically stake tokens or execute additional logic without requiring further transactions.

* Backward Compatibility with ERC20
    - ERC1363 is completely backwards compatible with any ERC20 tokens, it's new functions are simple add-ons, it's still an ERC20 token by any means with all the variables and functions, this helps a lot with adoption since all protocols relying on ERC20 tokens can adapt to ERC1363 without making breaking changes.

* ERC777 reentrancy solved
    - ERC1363 unlike ERC777 is completely reentrant safe, because transfer and transferFrom functions are untouched, all it's new transfer hooks have an explicit call-name, so the usage of them does not rely inside normal transfers like ERC777. 
