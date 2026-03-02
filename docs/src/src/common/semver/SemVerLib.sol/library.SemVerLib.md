# SemVerLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/semver/SemVerLib.sol)

Library for packing and unpacking semantic version data into bytes6


## Functions
### packVersion

Packs version components into bytes6


```solidity
function packVersion(uint256 major, uint256 minor, uint256 patch) internal pure returns (bytes6);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`major`|`uint256`|Major version (must be <= 65535)|
|`minor`|`uint256`|Minor version (must be <= 65535)|
|`patch`|`uint256`|Patch version (must be <= 65535)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes6`|Packed version as bytes6|


### unpackVersion

Unpacks bytes6 version into components


```solidity
function unpackVersion(bytes6 packedVersion) internal pure returns (uint256 major, uint256 minor, uint256 patch);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packedVersion`|`bytes6`|Packed version as bytes6|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`major`|`uint256`|Major version|
|`minor`|`uint256`|Minor version|
|`patch`|`uint256`|Patch version|


## Errors
### MajorVersionTooLarge

```solidity
error MajorVersionTooLarge(uint256 major)
```

### MinorVersionTooLarge

```solidity
error MinorVersionTooLarge(uint256 minor)
```

### PatchVersionTooLarge

```solidity
error PatchVersionTooLarge(uint256 patch)
```

