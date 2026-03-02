# LibERC7579
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/LibERC7579.sol)


## State Variables
### BATCH_MODE
Batch execution mode (0x01 << 248)


```solidity
bytes32 internal constant BATCH_MODE = 0x0100000000000000000000000000000000000000000000000000000000000000
```


## Functions
### decodeBatchUnchecked

Decodes a batch.
Reverts if `executionData` is not correctly encoded.

Decodes a batch without bounds checks.
This function can be used in `execute`, if the validation phase has already
decoded the `executionData` with checks via `decodeBatch`.


```solidity
function decodeBatchUnchecked(bytes calldata executionData) internal pure returns (bytes32[] calldata pointers);
```

### executeOps

This function extracts execution data from ops.data[2:] (skipping the first 2 bytes)
and delegates to executeEncoded for gas-optimized execution. The first 2 bytes are typically
used for operation metadata/flags and are stripped before passing to executeFromExecutor.

Executes a Types.Operation on an ERC7579 account by extracting pre-encoded execution data

This is part of the gas optimization strategy - instead of decoding the entire
Types.Operation struct and re-encoding it, we directly extract the relevant execution
data portion and use it with executeEncoded.


```solidity
function executeOps(address account, Types.Operation calldata ops) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The ERC7579 account to execute on|
|`ops`|`Types.Operation`|The operation containing pre-encoded execution data in ops.data|


### executeEncoded

This is a gas optimization that avoids decoding/re-encoding Types.Operation
Instead of decoding a Types.Operation struct and re-encoding it for executeFromExecutor,
this function directly uses pre-encoded data, saving significant gas costs by eliminating
the decode/encode round-trip that would otherwise be required.
The function constructs the call to executeFromExecutor(mode, executionData) where:
- mode: BATCH_MODE (0x01 << 248) constant for batch execution
- executionData: The pre-encoded execution data passed as encodedExec

Executes pre-encoded execution data on an ERC7579 account via executeFromExecutor

Uses inline assembly for maximum gas efficiency when constructing the call


```solidity
function executeEncoded(address account, bytes calldata encodedExec) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The ERC7579 account to execute on|
|`encodedExec`|`bytes`|Pre-encoded execution data (already in correct format for executeFromExecutor)|


