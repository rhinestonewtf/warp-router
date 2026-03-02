# AddressBook
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/AddressBook/AddressBook.sol)

**Inherits:**
[IAddressBook](/Users/ops/work/rhinestone/compact-utils/docs/src/src/common/AddressBook/IAddressBook.sol/interface.IAddressBook.md)

An on-chain registry for storing and retrieving different types of values by ID


## State Variables
### $addresses
Mapping from ID to Address storage struct


```solidity
mapping(AddressBookLib.ID id => AddressBookLib.Address value) private $addresses
```


### $uints
Mapping from ID to Uint256 storage struct


```solidity
mapping(AddressBookLib.ID id => AddressBookLib.Uint256 value) private $uints
```


### $byte32s
Mapping from ID to Bytes32 storage struct


```solidity
mapping(AddressBookLib.ID id => AddressBookLib.Bytes32 value) private $byte32s
```


### $bytess
Mapping from ID to Bytes storage struct


```solidity
mapping(AddressBookLib.ID id => AddressBookLib.Bytes value) private $bytess
```


### initialized

```solidity
bool public initialized
```


### OWNER

```solidity
address public immutable OWNER
```


## Functions
### onlyOwner


```solidity
modifier onlyOwner() ;
```

### constructor

Sets up initial ownership of the contract


```solidity
constructor(address owner) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address that will own this contract|


### initialize


```solidity
function initialize() external;
```

### setAddress

Sets a single address value


```solidity
function setAddress(AddressBookLib.ID id, address value) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the address|
|`value`|`address`|The address value to store|


### setAddresses

Sets multiple address values


```solidity
function setAddresses(SetAddress[] calldata values) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetAddress[]`|Array of SetAddress structs containing id/value pairs|


### setUint

Sets a single uint256 value


```solidity
function setUint(AddressBookLib.ID id, uint256 value) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the uint256|
|`value`|`uint256`|The uint256 value to store|


### setUints

Sets multiple uint256 values


```solidity
function setUints(SetUint[] calldata values) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetUint[]`|Array of SetUint structs containing id/value pairs|


### setBytes32

Sets a single bytes32 value


```solidity
function setBytes32(AddressBookLib.ID id, bytes32 value) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes32|
|`value`|`bytes32`|The bytes32 value to store|


### setBytes32s

Sets multiple bytes32 values


```solidity
function setBytes32s(SetBytes32[] calldata values) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetBytes32[]`|Array of SetBytes32 structs containing id/value pairs|


### setBytes

Sets a single bytes value


```solidity
function setBytes(AddressBookLib.ID id, bytes calldata value) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes|
|`value`|`bytes`|The bytes value to store|


### setBytess

Sets multiple bytes values


```solidity
function setBytess(SetBytess[] calldata values) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`SetBytess[]`|Array of SetBytess structs containing id/value pairs|


### getAddress

Retrieves an address value by ID

Reverts if the ID has not been initialized


```solidity
function getAddress(AddressBookLib.ID id) external view override returns (address value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`address`|The stored address value|


### unsafeGetAddress


```solidity
function unsafeGetAddress(AddressBookLib.ID id) external view returns (address value);
```

### getUint

Retrieves a uint256 value by ID

Reverts if the ID has not been initialized


```solidity
function getUint(AddressBookLib.ID id) external view override returns (uint256 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the uint256|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The stored uint256 value|


### getBytes32

Retrieves a bytes32 value by ID

Reverts if the ID has not been initialized


```solidity
function getBytes32(AddressBookLib.ID id) external view override returns (bytes32 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes32|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`bytes32`|The stored bytes32 value|


### getBytes

Retrieves a bytes value by ID

Reverts if the ID has not been initialized


```solidity
function getBytes(AddressBookLib.ID id) external view override returns (bytes memory value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`AddressBookLib.ID`|The identifier for the bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`bytes`|The stored bytes value|


## Errors
### AlreadyInitialized

```solidity
error AlreadyInitialized()
```

### NotOwner

```solidity
error NotOwner(address sender, address owner)
```

