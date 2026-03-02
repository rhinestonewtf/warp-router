# SemVer
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/semver/SemVer.sol)


## State Variables
### MAJOR

```solidity
uint256 internal immutable MAJOR
```


### MINOR

```solidity
uint256 internal immutable MINOR
```


### PATCH

```solidity
uint256 internal immutable PATCH
```


### PACKED_VERSION

```solidity
bytes6 internal immutable PACKED_VERSION
```


## Functions
### constructor


```solidity
constructor(uint256 minor, uint256 patch) ;
```

### semVer


```solidity
function semVer() external view returns (bytes6 packedVersion);
```

### semVerUnpacked


```solidity
function semVerUnpacked() external view returns (uint256 major, uint256 minor, uint256 patch);
```

### version


```solidity
function version() external view returns (bytes memory);
```

