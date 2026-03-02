# IAddressBook
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/AddressBook/IAddressBook.sol)

Interface for the AddressBook contract

Defines the external interface for setting and retrieving stored values


## Functions
### setAddress

Sets a single address value


```solidity
function setAddress(AddressBookLib.ID id, address value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the address|
|`value`|`address`|The address value to store|


### setAddresses

Sets multiple address values


```solidity
function setAddresses(SetAddress[] calldata values) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetAddress[]`|Array of SetAddress structs containing id/value pairs|


### setUint

Sets a single uint256 value


```solidity
function setUint(AddressBookLib.ID id, uint256 value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the uint256|
|`value`|`uint256`|The uint256 value to store|


### setUints

Sets multiple uint256 values


```solidity
function setUints(SetUint[] calldata values) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetUint[]`|Array of SetUint structs containing id/value pairs|


### setBytes32

Sets a single bytes32 value


```solidity
function setBytes32(AddressBookLib.ID id, bytes32 value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes32|
|`value`|`bytes32`|The bytes32 value to store|


### setBytes32s

Sets multiple bytes32 values


```solidity
function setBytes32s(SetBytes32[] calldata values) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetBytes32[]`|Array of SetBytes32 structs containing id/value pairs|


### setBytes

Sets a single bytes value


```solidity
function setBytes(AddressBookLib.ID id, bytes calldata value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes|
|`value`|`bytes`|The bytes value to store|


### setBytess

Sets multiple bytes values


```solidity
function setBytess(SetBytess[] calldata values) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetBytess[]`|Array of SetBytess structs containing id/value pairs|


### getAddress

Retrieves an address value by ID

Reverts if the ID has not been initialized


```solidity
function getAddress(AddressBookLib.ID id) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The stored address value|


### unsafeGetAddress


```solidity
function unsafeGetAddress(AddressBookLib.ID id) external view returns (address);
```

### getUint

Retrieves a uint256 value by ID

Reverts if the ID has not been initialized


```solidity
function getUint(AddressBookLib.ID id) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the uint256|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The stored uint256 value|


### getBytes32

Retrieves a bytes32 value by ID

Reverts if the ID has not been initialized


```solidity
function getBytes32(AddressBookLib.ID id) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes32|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The stored bytes32 value|


### getBytes

Retrieves a bytes value by ID

Reverts if the ID has not been initialized


```solidity
function getBytes(AddressBookLib.ID id) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The stored bytes value|


## Events
### AddressSet
Emitted when an address value is set


```solidity
event AddressSet(AddressBookLib.ID id, address value)
```

### UintSet
Emitted when a uint256 value is set


```solidity
event UintSet(AddressBookLib.ID id, uint256 value)
```

### Bytes32Set
Emitted when a bytes32 value is set


```solidity
event Bytes32Set(AddressBookLib.ID id, bytes32 value)
```

### BytesSet
Emitted when a bytes value is set


```solidity
event BytesSet(AddressBookLib.ID id, bytes value)
```

## Structs
### SetAddress
Struct for setting an address value


```solidity
struct SetAddress {
    AddressBookLib.ID id;
    address value;
}
```

### SetUint
Struct for setting a uint256 value


```solidity
struct SetUint {
    AddressBookLib.ID id;
    uint256 value;
}
```

### SetBytes32
Struct for setting a bytes32 value


```solidity
struct SetBytes32 {
    AddressBookLib.ID id;
    bytes32 value;
}
```

### SetBytess
Struct for setting a bytes value


```solidity
struct SetBytess {
    AddressBookLib.ID id;
    bytes value;
}
```

