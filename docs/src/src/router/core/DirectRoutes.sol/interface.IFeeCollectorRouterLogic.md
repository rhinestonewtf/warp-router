# IDirectRoute
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/DirectRoutes.sol)

Interface defining fee collection functions for direct routing operations

This interface provides standardized fee collection methods that can be called
directly within the router without delegatecall overhead. Designed for gas-optimized
fee processing during fill operations.


## Functions
### onFill_inRouter_collectFee

Collects a single fee directly within the router context

This function provides a direct interface for collecting a single fee without
the overhead of delegatecall. Returns a function selector for consistency
with the router's expected return patterns.

**Note:**
gas: Optimized for single fee collection to minimize gas overhead


```solidity
function onFill_inRouter_collectFee(FeeCollector.Fee calldata fee) external returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`FeeCollector.Fee`|The fee structure containing recipient and token/amount pairs|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|The function selector of this function for validation purposes|


### onFill_inRouter_collectFees

Collects multiple fees directly within the router context

This function provides batch fee collection capability without delegatecall
overhead. Processes an array of fees in a single transaction for efficiency.

**Note:**
gas: Optimized for batch fee collection, amortizing fixed costs across multiple fees


```solidity
function onFill_inRouter_collectFees(FeeCollector.Fee[] calldata fees) external returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fees`|`FeeCollector.Fee[]`|Array of fee structures to be processed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|The function selector of this function for validation purposes|


