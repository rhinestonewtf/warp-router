# TokenIdLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/TokenIdLib.sol)

Library for unpacking token ids and amounts


## Functions
### unpackInt

Unpacks a token id and amount from a given index in an array of token ids and amounts


```solidity
function unpackInt(uint256[2][] calldata idsAndAmounts, uint256 index) internal pure returns (uint256 id, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of token ids and amounts|
|`index`|`uint256`|Index of the token id and amount to unpack|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|Token id|
|`amount`|`uint256`|Amount|


### unpack

Unpacks a token address and amount from a given index in an array of token ids and
amounts


```solidity
function unpack(uint256[2][] calldata idsAndAmounts, uint256 index) internal pure returns (address token, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of token ids and amounts|
|`index`|`uint256`|Index of the token id and amount to unpack|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount|


### unpackM

Unpacks a token address and amount from a given index in a memory array of token ids
and amounts


```solidity
function unpackM(uint256[2][] memory idsAndAmounts, uint256 index) internal pure returns (address token, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of token ids and amounts|
|`index`|`uint256`|Index of the token id and amount to unpack|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount|


### unpackLast

Unpacks the last token address and amount in an array of token ids and amounts


```solidity
function unpackLast(uint256[2][] calldata idsAndAmounts) internal pure returns (address token, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of token ids and amounts|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount|


### unpackLastM

Unpacks the last token address and amount in a memory array of token ids and amounts


```solidity
function unpackLastM(uint256[2][] memory idsAndAmounts) internal pure returns (address token, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of token ids and amounts|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount|


### toClaimant


```solidity
function toClaimant(address claimant) internal pure returns (uint256 id);
```

### toComponent


```solidity
function toComponent(address claimant, uint256 amount) internal pure returns (Component memory component);
```

### toComponentArray


```solidity
function toComponentArray(Component memory component) internal pure returns (Component[] memory components);
```

### requireSorted


```solidity
function requireSorted(uint256[2][] calldata token) internal pure;
```

### makeClaimFor


```solidity
function makeClaimFor(uint256[2][] calldata idsAndAmounts, address claimant)
    internal
    pure
    returns (BatchClaimComponent[] memory batch);
```

## Errors
### InvalidToAddress

```solidity
error InvalidToAddress()
```

### TokenNotSorted

```solidity
error TokenNotSorted()
```

