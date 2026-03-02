# IntentExecutorNonceLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/lib/IntentExecutorNonceLib.sol)

Library for managing nonces across different intent executor types

This library provides centralized nonce management for intent executors using
distinct storage slots for each executor type to prevent nonce conflicts.
Storage slot calculation follows a deterministic pattern using keccak256 of
descriptive strings, with only the 6 most significant bytes used as base slots
to optimize gas costs while maintaining collision resistance.
Each executor type uses a different base slot:
- Compact: Uses TheCompact protocol for cross-chain intent execution
- Permit2: Uses Uniswap's Permit2 system for gasless token approvals
- Standalone: Direct execution without external protocol dependencies


## State Variables
### COMPACT_NONCE_SLOT
Base slot for Compact intent executor nonces
Derived from: keccak256("IntentExecutor.NonceSlot.Compact")
Full hash: 0x7e285120190b5ee6c0c2f3c033f56e41053c0e5465feb7add16c33106d9931fc
Using 6 most significant bytes (48 bits): 0x7e285120190b
This provides 2^48 possible base values while maintaining collision resistance
and optimizing storage access patterns for gas efficiency.


```solidity
uint256 internal constant COMPACT_NONCE_SLOT = 0x7e285120190b
```


### PERMIT2_NONCE_SLOT
Base slot for Permit2 intent executor nonces
Derived from: keccak256("IntentExecutor.NonceSlot.Permit2")
Full hash: 0xab6374e82b038c2dcc6bdb966d10f8cfbefdc3c6df3ac046488915a3e18895c0
Using 6 most significant bytes (48 bits): 0xab6374e82b03
Permit2 executors handle gasless token approvals using EIP-712 signatures,
requiring isolated nonce management to prevent replay attacks across
different authorization contexts.


```solidity
uint256 internal constant PERMIT2_NONCE_SLOT = 0xab6374e82b03
```


### STANDALONE_NONCE_SLOT
Base slot for Standalone intent executor nonces
Derived from: keccak256("IntentExecutor.NonceSlot.Standalone")
Full hash: 0x1974dd592f369e01eb68ebc04729bc8a1cbfb86115de346f943c591cdc8d0a08
Using 6 most significant bytes (48 bits): 0x1974dd592f36
Standalone executors operate independently without external protocol
integration, using direct account-based authorization and nonce management.


```solidity
uint256 internal constant STANDALONE_NONCE_SLOT = 0x1974dd592f36
```


## Functions
### compactNonceSlot

Computes the storage slot for a Compact intent executor nonce

Uses the Compact-specific base slot combined with nonce and account
to create a unique storage location. This prevents nonce collisions
between different executor types and accounts.


```solidity
function compactNonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce value to create a slot for|
|`account`|`address`|The account address that owns the nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot for this nonce/account pair|


### permit2NonceSlot

Computes the storage slot for a Permit2 intent executor nonce

Uses the Permit2-specific base slot to ensure nonces for Permit2-based
intents are isolated from other executor types. This is critical for
security as Permit2 signatures have specific replay protection requirements.


```solidity
function permit2NonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce value to create a slot for|
|`account`|`address`|The account address that owns the nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot for this nonce/account pair|


### standaloneNonceSlot

Computes the storage slot for a Standalone intent executor nonce

Uses the Standalone-specific base slot for direct execution scenarios
where no external protocols are involved. This provides the cleanest
nonce management for simple multi-chain operations.


```solidity
function standaloneNonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce value to create a slot for|
|`account`|`address`|The account address that owns the nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot for this nonce/account pair|


