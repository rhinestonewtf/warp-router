# OwnableValidator

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/OwnableValidator.sol)

**Inherits:**
ERC7579ValidatorBase

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Module that allows users to designate EOA owners that can validate transactions using a
threshold

## State Variables

### MAX_OWNERS

```solidity
uint256 constant MAX_OWNERS = 32
```

### owners

```solidity
SentinelList4337Lib.SentinelList owners
```

### threshold

```solidity
mapping(address account => uint256) public threshold
```

### ownerCount

```solidity
mapping(address => uint256) public ownerCount
```

## Functions

### onInstall

Initializes the module with the threshold and owners

data is encoded as follows: abi.encode(threshold, owners)

```solidity
function onInstall(bytes calldata data) external override;
```

**Parameters**

| Name   | Type    | Description                                      |
| ------ | ------- | ------------------------------------------------ |
| `data` | `bytes` | encoded data containing the threshold and owners |

### onUninstall

Handles the uninstallation of the module and clears the threshold and owners

the data parameter is not used

```solidity
function onUninstall(bytes calldata) external override;
```

### isInitialized

Checks if the module is initialized

```solidity
function isInitialized(address smartAccount) public view returns (bool);
```

**Parameters**

| Name           | Type      | Description                  |
| -------------- | --------- | ---------------------------- |
| `smartAccount` | `address` | address of the smart account |

**Returns**

| Name     | Type   | Description                                        |
| -------- | ------ | -------------------------------------------------- |
| `<none>` | `bool` | true if the module is initialized, false otherwise |

### setThreshold

Sets the threshold for the account

the function will revert if the module is not initialized

```solidity
function setThreshold(uint256 _threshold) external;
```

**Parameters**

| Name         | Type      | Description              |
| ------------ | --------- | ------------------------ |
| `_threshold` | `uint256` | uint256 threshold to set |

### addOwner

Adds an owner to the account

will revert if the owner is already added

```solidity
function addOwner(address owner) external;
```

**Parameters**

| Name    | Type      | Description                 |
| ------- | --------- | --------------------------- |
| `owner` | `address` | address of the owner to add |

### removeOwner

Removes an owner from the account

will revert if the owner is not added or the previous owner is invalid

```solidity
function removeOwner(address prevOwner, address owner) external;
```

**Parameters**

| Name        | Type      | Description                    |
| ----------- | --------- | ------------------------------ |
| `prevOwner` | `address` | address of the previous owner  |
| `owner`     | `address` | address of the owner to remove |

### getOwners

Returns the owners of the account

```solidity
function getOwners(address account) external view returns (address[] memory ownersArray);
```

**Parameters**

| Name      | Type      | Description            |
| --------- | --------- | ---------------------- |
| `account` | `address` | address of the account |

**Returns**

| Name          | Type        | Description     |
| ------------- | ----------- | --------------- |
| `ownersArray` | `address[]` | array of owners |

### validateUserOp

Validates a user operation

```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external view override returns (ValidationData);
```

**Parameters**

| Name         | Type                  | Description                                             |
| ------------ | --------------------- | ------------------------------------------------------- |
| `userOp`     | `PackedUserOperation` | PackedUserOperation struct containing the UserOperation |
| `userOpHash` | `bytes32`             | bytes32 hash of the UserOperation                       |

**Returns**

| Name     | Type             | Description                                        |
| -------- | ---------------- | -------------------------------------------------- |
| `<none>` | `ValidationData` | ValidationData the UserOperation validation result |

### isValidSignatureWithSender

Validates an ERC-1271 signature with the sender

```solidity
function isValidSignatureWithSender(address, bytes32 hash, bytes calldata data) external view override returns (bytes4);
```

**Parameters**

| Name     | Type      | Description                          |
| -------- | --------- | ------------------------------------ |
| `<none>` | `address` |                                      |
| `hash`   | `bytes32` | bytes32 hash of the data             |
| `data`   | `bytes`   | bytes data containing the signatures |

**Returns**

| Name     | Type     | Description                                                                |
| -------- | -------- | -------------------------------------------------------------------------- |
| `<none>` | `bytes4` | bytes4 EIP1271_SUCCESS if the signature is valid, EIP1271_FAILED otherwise |

### validateSignatureWithData

Validates a signature with the data (stateless validation)

```solidity
function validateSignatureWithData(bytes32 hash, bytes calldata signature, bytes calldata data) external view returns (bool);
```

**Parameters**

| Name        | Type      | Description                          |
| ----------- | --------- | ------------------------------------ |
| `hash`      | `bytes32` | bytes32 hash of the data             |
| `signature` | `bytes`   | bytes data containing the signatures |
| `data`      | `bytes`   | bytes data containing the data       |

**Returns**

| Name     | Type   | Description                                          |
| -------- | ------ | ---------------------------------------------------- |
| `<none>` | `bool` | bool true if the signature is valid, false otherwise |

### \_validateSignatureWithConfig

```solidity
function _validateSignatureWithConfig(address account, bytes32 hash, bytes calldata data) internal view returns (bool);
```

### isModuleType

Returns the type of the module

```solidity
function isModuleType(uint256 typeID) external pure override returns (bool);
```

**Parameters**

| Name     | Type      | Description        |
| -------- | --------- | ------------------ |
| `typeID` | `uint256` | type of the module |

**Returns**

| Name     | Type   | Description                                        |
| -------- | ------ | -------------------------------------------------- |
| `<none>` | `bool` | true if the type is a module type, false otherwise |

### name

Returns the name of the module

```solidity
function name() external pure virtual returns (string memory);
```

**Returns**

| Name     | Type     | Description        |
| -------- | -------- | ------------------ |
| `<none>` | `string` | name of the module |

### version

Returns the version of the module

```solidity
function version() external pure virtual returns (string memory);
```

**Returns**

| Name     | Type     | Description           |
| -------- | -------- | --------------------- |
| `<none>` | `string` | version of the module |

## Events

### ModuleInitialized

```solidity
event ModuleInitialized(address indexed account)
```

### ModuleUninitialized

```solidity
event ModuleUninitialized(address indexed account)
```

### ThresholdSet

```solidity
event ThresholdSet(address indexed account, uint256 threshold)
```

### OwnerAdded

```solidity
event OwnerAdded(address indexed account, address owner)
```

### OwnerRemoved

```solidity
event OwnerRemoved(address indexed account, address owner)
```

## Errors

### ThresholdNotSet

```solidity
error ThresholdNotSet()
```

### InvalidThreshold

```solidity
error InvalidThreshold()
```

### NotSortedAndUnique

```solidity
error NotSortedAndUnique()
```

### MaxOwnersReached

```solidity
error MaxOwnersReached()
```

### InvalidOwner

```solidity
error InvalidOwner(address owner)
```

### CannotRemoveOwner

```solidity
error CannotRemoveOwner()
```
