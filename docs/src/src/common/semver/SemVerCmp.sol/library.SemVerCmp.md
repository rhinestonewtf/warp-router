# SemVerCmp
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/semver/SemVerCmp.sol)

Library for comparing semantic versions using packed bytes6 representation


## Functions
### getSemVer

Retrieves the semantic version from a SemVer contract


```solidity
function getSemVer(address semVerContract) internal view returns (bytes6);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`semVerContract`|`address`|Address of the contract implementing SemVer|


### semVerCmp

Compares two semantic versions


```solidity
function semVerCmp(bytes6 version1, address semVerContract) internal view returns (int8 majorCmp, int8 minorCmp, int8 patchCmp);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version1`|`bytes6`|Packed version to compare|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`majorCmp`|`int8`|-1 if major1 < major2, 0 if equal, 1 if major1 > major2|
|`minorCmp`|`int8`|-1 if minor1 < minor2, 0 if equal, 1 if minor1 > minor2|
|`patchCmp`|`int8`|-1 if patch1 < patch2, 0 if equal, 1 if patch1 > patch2|


### semVerCmp

Compares two semantic versions (alternative with individual components for convenience)


```solidity
function semVerCmp(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract)
    internal
    view
    returns (int8 majorCmp, int8 minorCmp, int8 patchCmp);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`major1`|`uint256`|Major version of first semver|
|`minor1`|`uint256`|Minor version of first semver|
|`patch1`|`uint256`|Patch version of first semver|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`majorCmp`|`int8`|-1 if major1 < major2, 0 if equal, 1 if major1 > major2|
|`minorCmp`|`int8`|-1 if minor1 < minor2, 0 if equal, 1 if minor1 > minor2|
|`patchCmp`|`int8`|-1 if patch1 < patch2, 0 if equal, 1 if patch1 > patch2|


### isOnlyPatch

Checks if version1 is only a patch upgrade (major and minor same, patch higher)


```solidity
function isOnlyPatch(bytes6 version1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version1`|`bytes6`|Packed version to compare|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if major and minor are equal and patch is higher|


### isOnlyPatch

Checks if version1 is only a patch upgrade (convenience function with individual components)


```solidity
function isOnlyPatch(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`major1`|`uint256`|Major version of first semver|
|`minor1`|`uint256`|Minor version of first semver|
|`patch1`|`uint256`|Patch version of first semver|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if major and minor are equal and patch is higher|


### isOnlyMinor

Checks if version1 is only a minor upgrade (major same, minor higher)


```solidity
function isOnlyMinor(bytes6 version1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version1`|`bytes6`|Packed version to compare|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if major is equal and minor is higher|


### isOnlyMinor

Checks if version1 is only a minor upgrade (convenience function with individual components)


```solidity
function isOnlyMinor(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`major1`|`uint256`|Major version of first semver|
|`minor1`|`uint256`|Minor version of first semver|
|`patch1`|`uint256`|Patch version of first semver|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if major is equal and minor is higher|


### isSameMajor

Checks if two versions have the same major version


```solidity
function isSameMajor(bytes6 version1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version1`|`bytes6`|Packed version to compare|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if both versions have the same major version|


### isSameMajor

Checks if two versions have the same major version (convenience function with individual components)


```solidity
function isSameMajor(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`major1`|`uint256`|Major version of first semver|
|`minor1`|`uint256`|Minor version of first semver|
|`patch1`|`uint256`|Patch version of first semver|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if both versions have the same major version|


### isProtocolVersionCompatible

Checks if a protocol version (bytes2) matches the major version of a semver contract

Protocol versions are expected to directly represent the major version


```solidity
function isProtocolVersionCompatible(bytes2 protocolVersion, address semVerContract) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolVersion`|`bytes2`|Protocol version identifier (2 bytes)|
|`semVerContract`|`address`|Address of the contract implementing SemVer to compare against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the protocol version matches the semver contract's major version|


### packVersion

Packs version components into bytes6


```solidity
function packVersion(uint256 major, uint256 minor, uint256 patch) external pure returns (bytes6);
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
function unpackVersion(bytes6 packedVersion) external pure returns (uint256 major, uint256 minor, uint256 patch);
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


### _packVersion

Internal helper function to pack version components


```solidity
function _packVersion(uint256 major, uint256 minor, uint256 patch) internal pure returns (bytes6);
```

### _unpackVersion

Internal helper function to unpack version components


```solidity
function _unpackVersion(bytes6 packedVersion) internal pure returns (uint256 major, uint256 minor, uint256 patch);
```

### _compare

Internal helper function to compare two uint256 values


```solidity
function _compare(uint256 a, uint256 b) private pure returns (int8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|First value|
|`b`|`uint256`|Second value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int8`|-1 if a < b, 0 if a == b, 1 if a > b|


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

