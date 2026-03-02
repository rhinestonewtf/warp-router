# IntentExecutorAdapter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/adapters/IntentExecutorAdapter.sol)

**Inherits:**
[AdapterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/adapter/AdapterBase.sol/abstract.AdapterBase.md)

Gas-optimized adapter contract for forwarding intent execution calls to an intent executor

This adapter implements a transparent forwarding pattern that allows seamless routing of intent
execution requests while minimizing gas overhead. It acts as a proxy between the router and
the actual intent executor, handling three types of intent execution patterns:
- Compact intent execution (ERC-7683 style)
- Permit2 intent execution (with token approvals)
- Standalone multichain intent execution
The adapter uses memory-safe assembly for calldata forwarding to achieve minimal gas overhead,
typically saving 200-500 gas per call compared to high-level Solidity forwarding patterns.

**Notes:**
- relayer: This adapter does not consume any relayerContext data

- security: This contract uses assembly for performance but maintains memory safety through
proper free memory pointer management and bounds checking

- gas: Optimized for minimal forwarding overhead using direct calldata copying and
pre-computed function selectors
Example usage:
1. Router receives intent execution request
2. Router calls appropriate handleFill_* function on this adapter
3. Adapter prepends correct selector and forwards calldata to executor using assembly
4. Executor processes the intent and executes target operations


## State Variables
### EXECUTOR
The immutable address of the intent executor contract that handles actual execution


```solidity
address internal immutable EXECUTOR
```


### PERMIT2_INTENT_SELECTOR
Function selector for Permit2-based intent execution - cached for gas efficiency


```solidity
bytes4 internal constant PERMIT2_INTENT_SELECTOR = IPermit2IntentExecutor.executeTargetOpsWithPermit2Stub.selector
```


### COMPACT_INTENT_SELECTOR
Function selector for Compact-based intent execution - cached for gas efficiency


```solidity
bytes4 internal constant COMPACT_INTENT_SELECTOR = ICompactIntentExecutor.executeTargetOpsWithCompactStub.selector
```


### STANDALONE_INTENT_SELECTOR
Function selector for standalone multichain intent execution - cached for gas efficiency


```solidity
bytes4 internal constant STANDALONE_INTENT_SELECTOR = IStandaloneIntentExecutor.executeMultichainOps.selector
```


## Functions
### constructor

Initializes the IntentExecutorAdapter with router and executor addresses

Sets up the adapter to forward calls from the specified router to the intent executor.
The adapter is initialized with version 0.0 as per SemVer convention.


```solidity
constructor(address router, address executor) AdapterBase(router, address(0)) SemVer(0, 0);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The address of the router contract that will call this adapter|
|`executor`|`address`|The address of the intent executor contract that will handle forwarded calls|


### handleFill_intentExecutor_handleCompactTargetOps

Handles compact intent execution by forwarding to the executor

This function is called by the router to execute compact-style intents. It forwards
the call to the executor's executeTargetOpsWithCompactStub function using optimized
assembly forwarding to minimize gas overhead.
Compact intents follow the ERC-7683 standard for cross-chain intent execution,
typically involving token transfers and arbitrary contract calls.

**Note:**
gas: Optimized forwarding saves gas compared to traditional proxy patterns
Example flow:
1. Router receives compact intent execution request
2. Router calls this function with encoded parameters
3. Function forwards to executor.executeTargetOpsWithCompactStub(parameters)
4. Executor processes compact intent and executes target operations


```solidity
function handleFill_intentExecutor_handleCompactTargetOps(bytes calldata executorCalldata)
    external
    payable
    onlyViaRouter
    returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`executorCalldata`|`bytes`|The ABI-encoded parameters for the compact intent execution, typically containing target operations, token amounts, and execution context|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|bytes4 The function selector of this function to confirm successful handling|


### handleFill_intentExecutor_handlePermit2TargetOps

Handles Permit2-based intent execution by forwarding to the executor

This function is called by the router to execute intents that use Permit2 for token
approvals. It forwards the call to the executor's executeTargetOpsWithPermit2Stub
function, which handles the Permit2 signature verification and token transfers.
Permit2 intents allow gasless token approvals through signed permits, enabling
users to authorize token transfers without prior on-chain approval transactions.

**Notes:**
- security: Permit2 signature validation is handled by the executor, not this adapter

- gas: Optimized forwarding reduces gas overhead for Permit2 workflows
Example flow:
1. User signs Permit2 permit for token transfer
2. Router receives intent execution request with permit signature
3. Router calls this function with encoded permit and parameters
4. Function forwards to executor.executeTargetOpsWithPermit2Stub(parameters)
5. Executor validates permit signature and executes target operations


```solidity
function handleFill_intentExecutor_handlePermit2TargetOps(bytes calldata executorCalldata)
    external
    payable
    onlyViaRouter
    returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`executorCalldata`|`bytes`|The ABI-encoded parameters for the Permit2 intent execution, including permit signatures, token details, and target operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|bytes4 The function selector of this function to confirm successful handling|


### handleFill_intentExecutor_executeMultichainOps

Handles standalone multichain intent execution by forwarding to the executor

This function is called by the router to execute standalone multichain operations
that don't require Compact or Permit2 patterns. It forwards the call to the
executor's executeMultichainOps function for processing cross-chain operations.
Standalone intents typically involve direct cross-chain operations without
the additional abstractions of Compact or Permit2 patterns.

**Note:**
gas: Optimized forwarding maintains performance for multichain operations
Example flow:
1. Router receives multichain operation request
2. Router calls this function with encoded operation parameters
3. Function forwards to executor.executeMultichainOps(parameters)
4. Executor processes multichain operations across target chains


```solidity
function handleFill_intentExecutor_executeMultichainOps(bytes calldata executorCalldata)
    external
    payable
    onlyViaRouter
    returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`executorCalldata`|`bytes`|The ABI-encoded parameters for the multichain operation execution, containing cross-chain operation details and execution parameters|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|bytes4 The function selector of this function to confirm successful handling|


### supportsInterface

Checks if this contract supports a given interface selector

Implements ERC-165 interface detection to declare support for the three intent
execution handlers plus any interfaces supported by the parent AdapterBase.
This allows the router and other contracts to query supported functionality.


```solidity
function supportsInterface(bytes4 selector) public pure override returns (bool supported);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The 4-byte interface selector to check for support|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`supported`|`bool`|True if the selector is supported by this contract, false otherwise Supported selectors: - handleFill_intentExecutor_handleCompactTargetOps: Compact intent execution - handleFill_intentExecutor_handlePermit2TargetOps: Permit2 intent execution - handleFill_intentExecutor_executeMultichainOps: Standalone multichain execution - Any selectors supported by AdapterBase (isAdapter, etc.)|


### ADAPTER_TAG


```solidity
function ADAPTER_TAG() external pure override returns (bytes12);
```

## Errors
### ForwardingToExecutorFailed
Thrown when the forwarding call to the intent executor fails

This error indicates that the underlying executor either reverted or ran out of gas.
The original revert reason from the executor is not preserved to maintain gas efficiency.


```solidity
error ForwardingToExecutorFailed()
```

