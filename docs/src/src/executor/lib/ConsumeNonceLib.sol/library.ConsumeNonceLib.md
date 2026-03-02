# ConsumeNonceLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/lib/ConsumeNonceLib.sol)

Library for atomic nonce consumption with replay protection

This library provides gas-optimized nonce management for intent execution systems.
It implements atomic check-and-set operations to prevent replay attacks across
different intent execution mechanisms.
Key features:
- Atomic nonce consumption (check + mark as used in single operation)
- Gas-optimized assembly implementation
- Consistent storage slot computation across all intent executors
- Deterministic slot generation based on base slot, account, and nonce
Storage Layout:
Each executor type uses a different base slot to avoid collisions
Slot computation: keccak256(baseSlot || account || nonce)
Storage value: 0 = unused, 1 = consumed

**Note:**
security: Critical for replay protection - any vulnerability here could allow
replay attacks across the entire intent execution system


## Functions
### consumeNonce

Atomically consumes a nonce for replay protection

Performs an atomic check-and-set operation:
1. Loads the current value from storage
2. If already set (value == 1), reverts with NonceAlreadyUsed
3. If not used (value == 0), marks as used by storing 1
Uses assembly for gas optimization and to perform the operation atomically.
The error selector 0x21f123e1 corresponds to NonceAlreadyUsed().

**Note:**
gas: Assembly implementation saves gas by avoiding Solidity overhead
and performing the check-and-set atomically


```solidity
function consumeNonce(bytes32 slot) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot containing the nonce usage flag|


### _nonceSlot

Computes deterministic storage slot for nonce tracking

Creates a unique storage slot for each (baseSlot, account, nonce) combination.
The computation ensures:
- Different executor types don't interfere (different base slots)
- Each account has isolated nonce spaces
- Each nonce maps to a unique slot
Slot = keccak256(baseSlot || account || nonce)

**Note:**
gas: Pure function with assembly optimization for gas efficiency


```solidity
function _nonceSlot(uint256 baseSlot, uint256 nonce, address account) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseSlot`|`uint256`|The base storage slot specific to each executor type|
|`nonce`|`uint256`|The nonce value to create a slot for|
|`account`|`address`|The account address that owns this nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot for this nonce|


### isConsumed


```solidity
function isConsumed(bytes32 slot) internal view returns (bool consumed);
```

## Errors
### NonceAlreadyUsed
Thrown when attempting to use a nonce that has already been consumed


```solidity
error NonceAlreadyUsed()
```

