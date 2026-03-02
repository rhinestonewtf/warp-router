# RouterManagerStorageLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/lib/RouterStorageLib.sol)

Library for managing adapter storage using deterministic slot calculation

This library provides storage slot calculation and management for fill and claim adapters.
It uses a hash-based slot calculation system that combines base slots, version info,
and function selectors to create unique storage locations for each adapter configuration.


## State Variables
### FILL_SLOT
Base slot identifier for fill adapter storage


```solidity
uint256 internal constant FILL_SLOT = 0x11139132
```


### CLAIM_SLOT
Base slot identifier for claim adapter storage


```solidity
uint256 internal constant CLAIM_SLOT = 0x53724b44
```


## Functions
### __slot

Internal function to calculate deterministic storage slot for adapter configs

Creates a unique storage slot by hashing together baseSlot, version, and selector.
This ensures each adapter version/selector combination has its own storage location.


```solidity
function __slot(uint256 baseSlot, bytes2 protocolVersion, bytes4 selector) private pure returns (AdapterConfig storage _config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseSlot`|`uint256`|The base slot identifier (FILL_SLOT or CLAIM_SLOT)|
|`protocolVersion`|`bytes2`|The semantic version identifier (2 bytes)|
|`selector`|`bytes4`|The function selector (4 bytes) for the adapter|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_config`|`AdapterConfig`|Storage reference to the AdapterConfig at the calculated slot|


### withFillAdapter

Gets storage reference for a fill adapter configuration

Uses the FILL_SLOT base to calculate storage location for fill adapters


```solidity
function withFillAdapter(bytes4 selector, bytes2 protocolVersion) internal pure returns (AdapterConfig storage $config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`protocolVersion`|`bytes2`|The semantic version of the adapter (2 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$config`|`AdapterConfig`|Storage reference to the fill adapter configuration|


### withClaimAdapter

Gets storage reference for a claim adapter configuration

Uses the CLAIM_SLOT base to calculate storage location for claim adapters


```solidity
function withClaimAdapter(bytes4 selector, bytes2 protocolVersion) internal pure returns (AdapterConfig storage $config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`protocolVersion`|`bytes2`|The semantic version of the adapter (2 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$config`|`AdapterConfig`|Storage reference to the claim adapter configuration|


### adapterAddress

Retrieves the adapter address from storage


```solidity
function adapterAddress(AdapterConfig storage _in) internal view returns (address out);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_in`|`AdapterConfig`|Storage reference to the adapter configuration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`out`|`address`|The address of the stored adapter|


### store

Stores an adapter address and tag in the configuration

Updates both the adapter address and its associated tag in a single operation


```solidity
function store(AdapterConfig storage _in, address adapter, bytes12 tag) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_in`|`AdapterConfig`|Storage reference to the adapter configuration|
|`adapter`|`address`|The adapter contract address to store|
|`tag`|`bytes12`|The 12-byte tag to associate with the adapter|


### adapterAddressAndTag

Retrieves both the adapter address and tag from storage


```solidity
function adapterAddressAndTag(AdapterConfig storage _in) internal view returns (address out, bytes12 adapterTag);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_in`|`AdapterConfig`|Storage reference to the adapter configuration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`out`|`address`|The address of the stored adapter|
|`adapterTag`|`bytes12`|The metadata tag associated with the adapter|


## Errors
### AdapterNotFound

```solidity
error AdapterNotFound()
```

