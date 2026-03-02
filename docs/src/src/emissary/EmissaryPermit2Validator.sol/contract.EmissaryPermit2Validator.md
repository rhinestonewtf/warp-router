# EmissaryPermit2Validator
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/emissary/EmissaryPermit2Validator.sol)

**Inherits:**
ERC7579ValidatorBase

A validator that allows Smart Session emissary contracts to be used with
Permit2 signature validation


## State Variables
### EMISSARY

```solidity
IEmissary public immutable EMISSARY
```


### isInitialized

```solidity
mapping(address account => bool isInit) public isInitialized
```


## Functions
### constructor

Constructor to set the Smart Session Emissary address


```solidity
constructor(address emissary) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emissary`|`address`|The address of the Smart Session Emissary contract|


### isValidSignatureWithSender


```solidity
function isValidSignatureWithSender(address, bytes32 hash, bytes calldata data) external view virtual override returns (bytes4);
```

### onInstall


```solidity
function onInstall(bytes calldata) external override;
```

### onUninstall


```solidity
function onUninstall(bytes calldata) external override;
```

### isModuleType


```solidity
function isModuleType(uint256 moduleTypeId) external pure override returns (bool);
```

### validateUserOp

Stub to satisfy the interface, always reverts


```solidity
function validateUserOp(PackedUserOperation calldata, bytes32) external virtual override returns (ValidationData);
```

## Errors
### NotSupported
Thrown when a function is not supported


```solidity
error NotSupported()
```

### OnlyPermit2
Thrown when a function is called by an unauthorized sender


```solidity
error OnlyPermit2()
```

