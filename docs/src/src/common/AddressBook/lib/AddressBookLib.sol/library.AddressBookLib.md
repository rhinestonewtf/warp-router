# AddressBookLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/AddressBook/lib/AddressBookLib.sol)

Library containing core functionality for the AddressBook contract

Provides types, constants, and helper functions for managing stored values


## State Variables
### COMPACTLOCKER
Predefined IDs for common contract references


```solidity
ID public constant COMPACTLOCKER = ID.wrap(keccak256(abi.encodePacked("CompactLocker")))
```


### ORIGINMODULE_ACTUAL

```solidity
ID public constant ORIGINMODULE_ACTUAL = ID.wrap(keccak256(abi.encodePacked("OriginModuleCompactActual")))
```


### ORIGINMODULE_LOCKER

```solidity
ID public constant ORIGINMODULE_LOCKER = ID.wrap(keccak256(abi.encodePacked("OriginModuleCompactLocker")))
```


### PREVALIDATION_HOOK

```solidity
ID public constant PREVALIDATION_HOOK = ID.wrap(keccak256(abi.encodePacked("PreValidationHook")))
```


### SAMECHAINMODULE_ACTUAL

```solidity
ID public constant SAMECHAINMODULE_ACTUAL = ID.wrap(keccak256(abi.encodePacked("SameChainModuleCompactActual")))
```


### SAMECHAINMODULE_LOCKER

```solidity
ID public constant SAMECHAINMODULE_LOCKER = ID.wrap(keccak256(abi.encodePacked("SameChainModuleCompactLocker")))
```


### RHINESTONE_SPOKEPOOL

```solidity
ID public constant RHINESTONE_SPOKEPOOL = ID.wrap(keccak256(abi.encodePacked("RhinestoneSpokePool")))
```


## Functions
### set

Sets an address value and marks it as initialized


```solidity
function set(Address storage self, address value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Address`|The storage struct to update|
|`value`|`address`|The new address value|


### set

Sets a uint256 value and marks it as initialized


```solidity
function set(Uint256 storage self, uint256 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Uint256`|The storage struct to update|
|`value`|`uint256`|The new uint256 value|


### set

Sets a bytes32 value and marks it as initialized


```solidity
function set(Bytes32 storage self, bytes32 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Bytes32`|The storage struct to update|
|`value`|`bytes32`|The new bytes32 value|


### set

Sets a bytes value and marks it as initialized


```solidity
function set(Bytes storage self, bytes calldata value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Bytes`|The storage struct to update|
|`value`|`bytes`|The new bytes value|


### get

Retrieves an address value, reverting if not initialized


```solidity
function get(Address storage self, ID id) internal view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Address`|The storage struct to read from|
|`id`|`ID`|The identifier of the value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The stored address value|


### unsafeGet

Retrieves an address value, reverting if not initialized


```solidity
function unsafeGet(Address storage self) internal view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Address`|The storage struct to read from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The stored address value|


### get

Retrieves a uint256 value, reverting if not initialized


```solidity
function get(Uint256 storage self, ID id) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Uint256`|The storage struct to read from|
|`id`|`ID`|The identifier of the value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The stored uint256 value|


### get

Retrieves a bytes32 value, reverting if not initialized


```solidity
function get(Bytes32 storage self, ID id) internal view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Bytes32`|The storage struct to read from|
|`id`|`ID`|The identifier of the value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The stored bytes32 value|


### get

Retrieves a bytes value, reverting if not initialized


```solidity
function get(Bytes storage self, ID id) internal view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Bytes`|The storage struct to read from|
|`id`|`ID`|The identifier of the value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The stored bytes value|


## Errors
### NotInitialized
Thrown when attempting to access an uninitialized value


```solidity
error NotInitialized(ID id)
```

## Structs
### Address
Storage struct for address values


```solidity
struct Address {
    address value;
    bool initialized;
}
```

### Uint256
Storage struct for uint256 values


```solidity
struct Uint256 {
    uint256 value;
    bool initialized;
}
```

### Bytes32
Storage struct for bytes32 values


```solidity
struct Bytes32 {
    bytes32 value;
    bool initialized;
}
```

### Bytes
Storage struct for bytes values


```solidity
struct Bytes {
    bytes value;
    bool initialized;
}
```

