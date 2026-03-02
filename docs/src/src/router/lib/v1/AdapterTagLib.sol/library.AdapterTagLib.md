# AdapterTagLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/lib/v1/AdapterTagLib.sol)

Library for parsing adapter tag flags from a bytes12 value

Adapter tag layout (12 bytes = 96 bits):
Byte Index: 0 1 2 3 4 5 6 7 8 9 10 11
┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
│ │ │ │ │ │ │ │ │ │ │ │ │
└────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
Bit Range: 95 0
(MSB) (LSB)
│
└─ bit 0: skiprelayerContext flag
Bit 0 (LSB): skiprelayerContext flag
Bits 1-95: Reserved for future use


## Functions
### isSkipRelayerContext

Checks if the solver context should be consumed


```solidity
function isSkipRelayerContext(bytes12 adapterTag) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapterTag`|`bytes12`|The 12-byte adapter tag containing flags|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the least significant bit (bit 0) is set, false otherwise|


### setSkipRelayerContext

Sets the skiprelayerContext flag by enabling bit 0


```solidity
function setSkipRelayerContext(bytes12 adapterTag) internal pure returns (bytes12);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapterTag`|`bytes12`|The 12-byte adapter tag to modify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes12`|The modified adapter tag with bit 0 set to 1|


