# AdapterCalldataPassthroughLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/adapter/AdapterCalldataPassthroughLib.sol)

Library for efficiently forwarding calldata to target contracts without additional encoding overhead

This library provides gas-optimized calldata forwarding functionality using inline assembly.
It constructs function calls by combining a function selector with pre-encoded parameters,
avoiding the need for additional ABI encoding operations that would consume extra gas.
The assembly implementation directly manipulates memory and calldata to achieve maximum
efficiency when acting as a proxy or adapter contract that needs to forward calls.
Key optimizations:
- Zero-copy calldata forwarding using calldatacopy
- Minimal memory allocation
- Direct assembly call without high-level Solidity overhead
- Proper error propagation maintaining original revert data

**Notes:**
- security: Uses memory-safe assembly and properly manages the free memory pointer

- gas: Optimized for minimal gas consumption in adapter/proxy patterns


## Functions
### passthroughCalldata

Forwards a function call to a target contract by constructing calldata from a selector and parameters

This function uses assembly to efficiently construct and forward calls without additional memory allocation.
The implementation directly copies calldata to minimize gas costs and avoid redundant encoding operations.
The function preserves the exact revert data from the target contract, ensuring that error messages
and custom errors are properly propagated to the caller. This is crucial for debugging and maintaining
the same error semantics as a direct call.
Memory safety: This function is marked as memory-safe and properly manages the free memory pointer
to ensure compatibility with Solidity's memory model.

Reverts with the original revert data if the target call fails, preserving error context.
The assembly block is marked as memory-safe for optimization compatibility.

**Notes:**
- security: The function makes an external call with all available gas. Ensure proper access controls
are in place before calling this function to prevent unauthorized contract interactions.

- gas: Uses calldatacopy for zero-copy parameter forwarding, avoiding expensive memory operations.
Gas cost is approximately: 21000 (base call) + calldata costs + target execution costs.


```solidity
function passthroughCalldata(address target, bytes4 selector, bytes calldata abiEncodedParams) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The address of the contract to call - must be a valid contract address|
|`selector`|`bytes4`|The 4-byte function selector to call on the target contract|
|`abiEncodedParams`|`bytes`|The ABI-encoded parameters for the function call (without the selector). This should be the exact calldata that would follow the selector in a normal call.|


### passthroughCalldataGetReturn

Forwards a function call to a target contract and returns the result

Similar to passthroughCalldata but captures and returns the call result.
Uses assembly for efficient calldata forwarding with return data capture.

Reverts with the original revert data if the target call fails, preserving error context.

**Notes:**
- security: The function makes an external call with all available gas. Ensure proper access controls
are in place before calling this function to prevent unauthorized contract interactions.

- gas: Slightly more expensive than passthroughCalldata due to return data copying.


```solidity
function passthroughCalldataGetReturn(address target, bytes4 selector, bytes calldata abiEncodedParams)
    internal
    returns (bytes memory returnData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The address of the contract to call - must be a valid contract address|
|`selector`|`bytes4`|The 4-byte function selector to call on the target contract|
|`abiEncodedParams`|`bytes`|The ABI-encoded parameters for the function call (without the selector)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`returnData`|`bytes`|The bytes returned by the target contract call|


