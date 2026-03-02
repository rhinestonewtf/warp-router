# AllocatorLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/allocator/lib/AllocatorLib.sol)

Library for allocator-related functions, including qualification hash computation and allocator data encoding.


## State Variables
### QUALIFICATION_TYPEHASH

```solidity
bytes32 internal constant QUALIFICATION_TYPEHASH = 0xa002e4a5708d4424abeaa7aa762b36027c1c7eb8604af120ad2ddda6f419c071
```


## Functions
### qualificationHash

Computes a qualification hash for a claim.


```solidity
function qualificationHash(bytes32 claimHash, bytes32 _qualificationHash) internal pure returns (bytes32 hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The hash of the claim.|
|`_qualificationHash`|`bytes32`|The qualification hash to be included.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|The resulting qualification hash.|


### encodeAllocatorData

Encodes allocator data by combining a qualification hash and a signature.


```solidity
function encodeAllocatorData(bytes calldata signature, bytes32 _qualificationHash) internal pure returns (bytes memory allocatorData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signature`|`bytes`|The signature bytes.|
|`_qualificationHash`|`bytes32`|The qualification hash to be included.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`allocatorData`|`bytes`|The encoded allocator data.|


