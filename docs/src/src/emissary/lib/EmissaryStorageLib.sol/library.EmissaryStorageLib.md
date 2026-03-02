# EmissaryStorageLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/emissary/lib/EmissaryStorageLib.sol)

Library for computing storage slots and performing low-level storage operations for Emissary

This library uses assembly for gas-efficient storage slot derivation and direct storage access.
It implements a collision-resistant storage slot scheme by hashing multiple parameters together.
Storage slot calculation uses a base slot combined with sponsor, configId, lockTag, and validator
to ensure unique storage locations across all Emissary configurations.


## State Variables
### EMISSARY_CONFIG_BASE_SLOT
Base slot for Emissary config storage
Derived from: keccak256("Emissary.StorageSlot.Config")
Full hash: 0x86f750d6ba7a384ce70cb2fd5989007de5d38fd9606c07e52f64aeb3eaa2f447
Using 6 most significant bytes (48 bits): 0x86f750d6ba7a
This base slot is combined with sponsor, configId, lockTag, and validator parameters
to create unique storage locations for each configuration, preventing collisions
between different Emissary instances and other protocol storage.


```solidity
uint256 internal constant EMISSARY_CONFIG_BASE_SLOT = 0x86f750d6ba7a
```


### EMISSARY_NONCE_BASE_SLOT
Base slot for Emissary nonce storage
Derived from: keccak256("Emissary.StorageSlot.Nonce")
Full hash: 0x95198fc29028bf37f01b49da35e2a93273ed28197c2094acd14f7de81c3c558f
Using 6 most significant bytes (48 bits): 0x95198fc29028
This base slot is combined with sponsor and lockTag to create unique nonce
storage locations for replay protection, isolated from config storage.


```solidity
uint256 internal constant EMISSARY_NONCE_BASE_SLOT = 0x95198fc29028
```


## Functions
### configSlot

Computes the storage slot for a validator configuration

Storage slot derivation uses keccak256 of base slot combined with parameters:
slot = keccak256(EMISSARY_BASE_SLOT || sponsor || configId || lockTag || validator)
The base slot ensures Emissary storage is isolated from other protocol components.
Each unique combination of parameters gets a unique storage location:
- sponsor account (who owns the config)
- configId (allows multiple configs per validator)
- lockTag (derived from allocator + scope + resetPeriod)
- validator address (ECDSA_VALIDATOR, PASSKEY_VALIDATOR, or custom)

**Note:**
gas: Uses assembly for optimal gas efficiency (avoids ABI encoding overhead)


```solidity
function configSlot(address sponsor, uint8 configId, bytes12 lockTag, address validator) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sponsor`|`address`|The sponsor account address (20 bytes)|
|`configId`|`uint8`|The configuration type identifier (1 byte)|
|`lockTag`|`bytes12`|The lock tag from allocator parameters (12 bytes)|
|`validator`|`address`|The validator address (20 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot (32 bytes)|


### nonceSlot

Computes the storage slot for a nonce value

Nonces are used for replay protection during config updates.
slot = keccak256(EMISSARY_NONCE_BASE_SLOT || sponsor || lockTag)
The base slot ensures nonce storage is isolated from config storage.
Each sponsor+lockTag pair has its own nonce counter that must increase
monotonically with each config update to prevent:
- Replay attacks (reusing old signed config updates)
- Reordering attacks (applying updates out of intended order)

**Note:**
gas: Uses assembly for optimal gas efficiency


```solidity
function nonceSlot(address sponsor, bytes12 lockTag) internal pure returns (bytes32 slot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sponsor`|`address`|The sponsor account address (20 bytes)|
|`lockTag`|`bytes12`|The lock tag from allocator parameters (12 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The computed storage slot for the nonce (32 bytes)|


### loadAddress

Loads an address from storage and reverts if it's not set

Reads the address value from the given storage slot and validates it's non-zero.
Used when we expect a value to exist and want to fail explicitly if it doesn't.

**Note:**
reverts: NotSet if the stored address is address(0)


```solidity
function loadAddress(bytes32 slot) internal view returns (address value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to read from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`address`|The address stored at the slot|


### loadAddressUnchecked

Loads an address from storage without validation

Reads the address value from the given storage slot, allowing address(0).
Used during initialization checks where address(0) indicates uninitialized state.


```solidity
function loadAddressUnchecked(bytes32 slot) internal view returns (address value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to read from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`address`|The address stored at the slot (may be address(0))|


### loadUint256

Loads a uint256 value from storage

Reads a uint256 from the given storage slot. Used for nonce loading.
Returns 0 for uninitialized slots, which is the expected behavior for nonces.


```solidity
function loadUint256(bytes32 slot) internal view returns (uint256 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to read from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The uint256 value stored at the slot|


### loadCompressedBytes

Returns a storage pointer to compressed bytes data

Creates a storage reference to a Compressed.Bytes struct at the given slot.
This is a pure function that only manipulates the storage pointer, not actual storage.
The returned pointer can be used with CompressedStorageLib operations.


```solidity
function loadCompressedBytes(bytes32 slot) internal pure returns (Compressed.Bytes storage config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot where compressed bytes are stored|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`config`|`Compressed.Bytes`|A storage pointer to the Compressed.Bytes at the slot|


### loadPasskeyCredentials

Returns a storage pointer to WebAuthn credentials

Creates a storage reference to a WebAuthnCredential struct at the given slot.
This is a pure function that only manipulates the storage pointer, not actual storage.
The credentials include P256 public key coordinates and validation flags.


```solidity
function loadPasskeyCredentials(bytes32 slot) internal pure returns (WebAuthnCredential storage creds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot where credentials are stored|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`creds`|`WebAuthnCredential`|A storage pointer to the WebAuthnCredential at the slot|


### storeAddress

Stores an address value to the specified storage slot

Directly writes the address to storage using SSTORE.


```solidity
function storeAddress(bytes32 slot, address value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to write to|
|`value`|`address`|The address value to store|


### setUint256

Stores a uint256 value to the specified storage slot

Directly writes the uint256 to storage using SSTORE.
This is an alias for storeUint256 for consistency.


```solidity
function setUint256(bytes32 slot, uint256 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to write to|
|`value`|`uint256`|The uint256 value to store|


### storeUint256

Stores a uint256 value to the specified storage slot

Directly writes the uint256 to storage using SSTORE.
Used primarily for nonce updates.


```solidity
function storeUint256(bytes32 slot, uint256 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The storage slot to write to|
|`value`|`uint256`|The uint256 value to store|


## Errors
### NotSet

```solidity
error NotSet()
```

