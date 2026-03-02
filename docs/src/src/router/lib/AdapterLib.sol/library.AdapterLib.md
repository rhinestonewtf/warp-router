# AdapterLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/lib/AdapterLib.sol)

Gas-optimized library for calling adapters with or without solver context using pure assembly

Drop-in replacement for _callAdapterWithRelayerContext with 60% gas savings


## Functions
### callAdapter

Executes a delegatecall to an adapter without solver context

Optimized version for adapters that don't require solver context

Appends uint256(0) as context length to maintain protocol compatibility

caller MUST ensure, that adapter != address(0)


```solidity
function callAdapter(address adapter, bytes calldata adapterCalldata) internal returns (bytes4 ret);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The address of the adapter to delegatecall|
|`adapterCalldata`|`bytes`|The original calldata for the adapter function|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ret`|`bytes4`|The function selector returned by the adapter|


### callAdapterWithRelayerContext

Executes a delegatecall to an adapter with solver context appended to calldata

Equivalent to: adapter.delegatecall(abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length)))

caller MUST ensure, that adapter != address(0)


```solidity
function callAdapterWithRelayerContext(address adapter, bytes calldata relayerContext, bytes calldata adapterCalldata)
    internal
    returns (bytes4 ret);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The address of the adapter to delegatecall|
|`relayerContext`|`bytes`|The solver-specific context data to append|
|`adapterCalldata`|`bytes`|The original calldata for the adapter function|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ret`|`bytes4`|The function selector returned by the adapter|


## Errors
### DelegatecallFailed

```solidity
error DelegatecallFailed()
```

