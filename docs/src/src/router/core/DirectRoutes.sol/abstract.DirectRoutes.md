# DirectRoutes
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/DirectRoutes.sol)

**Inherits:**
[FeeCollector](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/utils/FeeCollector.sol/contract.FeeCollector.md)

Abstract contract implementing direct routing functionality for gas optimization

DirectRoutes provides a "direct routing" mechanism where operations can be executed
without delegatecall overhead. This is primarily designed for gas optimizations by
avoiding the costs associated with proxy patterns and delegate calls. The contract
supports both claim and fill operations with specialized routing for fee collection.

**Notes:**
- security: All external calls are made through the immutable CALLER contract to maintain security

- gas: Eliminates delegatecall overhead by using direct calls and inline processing


## State Variables
### CALLER
Immutable Caller contract used for executing external calls

This contract is deployed once during construction and used for all external
call operations. Being immutable ensures the call target cannot be changed
after deployment, maintaining security guarantees.


```solidity
Caller public immutable CALLER
```


## Functions
### constructor

Initializes the DirectRoutes contract with a new Caller instance

Deploys a new Caller contract that will be used for all external call operations.
The Caller contract is immutable to prevent malicious address changes after deployment.


```solidity
constructor() ;
```

### _processDirectClaimRoute

Processes direct claim routes without delegatecall for gas optimization

This function implements direct routing for claim operations, avoiding delegatecall
overhead by making direct calls to the CALLER contract. Supports both single and
multi-call patterns for maximum flexibility.


```solidity
function _processDirectClaimRoute(bytes4 selector, bytes calldata adapterCalldata) internal returns (bool used);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector identifying the type of call to make|
|`adapterCalldata`|`bytes`|The calldata to be forwarded to the appropriate handler|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`used`|`bool`|Boolean indicating whether the selector was recognized and processed|


### _processDirectFillRoute

Processes direct fill routes without delegatecall for gas optimization

This function implements direct routing for fill operations, supporting both external
calls via CALLER contract and internal fee collection. Avoids delegatecall overhead
for improved gas efficiency in fill scenarios.


```solidity
function _processDirectFillRoute(bytes4 selector, bytes calldata adapterCalldata) internal returns (bool used);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector identifying the type of operation to perform|
|`adapterCalldata`|`bytes`|The calldata containing the parameters for the selected operation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`used`|`bool`|Boolean indicating whether the selector was recognized and processed|


### _isDirectFillRoute

Checks if a given function selector corresponds to a direct fill route

Determines whether a function selector can be processed directly without delegatecall
overhead. Direct fill routes include single/multi calls and fee collection functions.

**Note:**
gas: Pure function with minimal gas cost for route determination


```solidity
function _isDirectFillRoute(bytes4 selector) internal pure returns (bool isDirect);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The 4-byte function selector to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isDirect`|`bool`|True if the selector corresponds to a direct fill route, false otherwise|


### _isDirectClaimRoute

Checks if a given function selector corresponds to a direct claim route

Determines whether a function selector can be processed directly for claim operations.
Claim routes are limited to single and multi calls, excluding fee collection.

**Note:**
gas: Pure function with minimal gas cost for route determination


```solidity
function _isDirectClaimRoute(bytes4 selector) internal pure returns (bool isDirect);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The 4-byte function selector to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isDirect`|`bool`|True if the selector corresponds to a direct claim route, false otherwise|


### _onFill_inRouter_collectFee

Processes a single fee collection directly within the router

This function decodes ABI-encoded calldata containing a Fee struct and processes
the fee collection internally. Uses assembly for efficient calldata parsing to
minimize gas overhead compared to standard ABI decoding.

**Notes:**
- gas: Uses assembly for direct calldata access, avoiding ABI decoding overhead

- security: Assembly operations are bounded to prevent buffer overflows


```solidity
function _onFill_inRouter_collectFee(bytes calldata data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Raw calldata containing the ABI-encoded Fee struct (selector already removed)|


### _onFill_inRouter_collectFees

Processes multiple fee collections directly within the router

This function decodes ABI-encoded calldata containing a Fee[] array and processes
each fee collection internally. Uses assembly for efficient array parsing and
iterates through each fee using the inherited _collectFee function.

**Notes:**
- gas: Uses assembly for direct calldata access and caches array length for efficient iteration

- security: Bounded iteration prevents infinite loops, assembly operations are safe


```solidity
function _onFill_inRouter_collectFees(bytes calldata data) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Raw calldata containing the ABI-encoded Fee[] array (selector already removed)|


## Errors
### CallFailed
Thrown when an external call fails


```solidity
error CallFailed()
```

