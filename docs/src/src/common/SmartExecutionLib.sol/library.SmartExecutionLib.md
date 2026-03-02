# SmartExecutionLib

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/SmartExecutionLib.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

A library for encoding and decoding different types of execution data.
It provides helper functions to handle various execution formats, such as converting
raw calldata to ERC-7579 `Execution` structs. The first byte of an encoded execution
payload indicates its type.

## State Variables

### OFFSET_EXEC_TYPE

```solidity
uint256 private constant OFFSET_EXEC_TYPE = 0
```

### OFFSET_SIG_MODE

```solidity
uint256 private constant OFFSET_SIG_MODE = 1
```

### OFFSET_EXEC_DATA

```solidity
uint256 private constant OFFSET_EXEC_DATA = 2
```

## Functions

### toUint8

```solidity
function toUint8(SigMode _sigMode) internal pure returns (uint8 _out);
```

### toSigMode

```solidity
function toSigMode(uint8 _in) internal pure returns (SigMode _sigMode);
```

### toSigMode

```solidity
function toSigMode(bytes1 _in) internal pure returns (SigMode _sigMode);
```

### extractSigMode

```solidity
function extractSigMode(Types.Operation calldata ops) internal pure returns (SigMode _sigMode);
```

### isExecutionEmissary

```solidity
function isExecutionEmissary(Types.Operation calldata ops) internal pure returns (bool);
```

### isExecutionEmissary

```solidity
function isExecutionEmissary(SigMode sigMode) internal pure returns (bool);
```

### decodeAll

```solidity
function decodeAll(Types.Operation calldata ops) internal pure returns (SigMode _sigMode, Type _type, bytes32 hash);
```

### hashEIP712AndType

```solidity
function hashEIP712AndType(Types.Operation calldata ops) internal pure returns (Type _type, bytes32 hash);
```

### hashEIP712

```solidity
function hashEIP712(Types.Operation calldata ops) internal pure returns (bytes32 hash);
```

### toExecType

Determines the execution type from an encoded execution payload.

It reads the first byte of the `encodedExecution` data.

```solidity
function toExecType(Types.Operation calldata ops) internal pure returns (Type _type);
```

**Parameters**

| Name  | Type              | Description                    |
| ----- | ----------------- | ------------------------------ |
| `ops` | `Types.Operation` | The encoded execution payload. |

**Returns**

| Name    | Type   | Description              |
| ------- | ------ | ------------------------ |
| `_type` | `Type` | The execution type enum. |

### safeToERC7579

Safely decodes an execution payload into an array of ERC-7579 `Execution` structs.

It first checks that the execution type is `Calldata` and then calls `toERC7579`.
It reverts with `IncorrectType` if the type is wrong.

```solidity
function safeToERC7579(Types.Operation calldata ops) internal pure returns (Execution[] calldata executions);
```

**Parameters**

| Name  | Type              | Description                                                  |
| ----- | ----------------- | ------------------------------------------------------------ |
| `ops` | `Types.Operation` | The full encoded execution payload, including the type byte. |

**Returns**

| Name         | Type          | Description                      |
| ------------ | ------------- | -------------------------------- |
| `executions` | `Execution[]` | An array of `Execution` structs. |

### safeToMultiCall

Safely decodes an execution payload into an array of ERC-7579 `Execution` structs.

It first checks that the execution type is `Calldata` and then calls `toERC7579`.
It reverts with `IncorrectType` if the type is wrong.

```solidity
function safeToMultiCall(Types.Operation calldata ops) internal pure returns (Execution[] calldata executions);
```

**Parameters**

| Name  | Type              | Description                                                  |
| ----- | ----------------- | ------------------------------------------------------------ |
| `ops` | `Types.Operation` | The full encoded execution payload, including the type byte. |

**Returns**

| Name         | Type          | Description                      |
| ------------ | ------------- | -------------------------------- |
| `executions` | `Execution[]` | An array of `Execution` structs. |

### onlyExecutionData

```solidity
function onlyExecutionData(Types.Operation calldata ops) internal pure returns (bytes calldata encodedExec);
```

### toERC7579

Decodes a raw calldata payload (without the type byte) into an array of ERC-7579 `Execution` structs.

This function uses `decodeBatch` from `LibERC7579` and then performs a memory-safe cast
of the resulting pointers to the `Execution[]` type using assembly.

```solidity
function toERC7579(bytes calldata encodedExecutionWithoutType) internal pure returns (Execution[] calldata executions);
```

**Parameters**

| Name                          | Type    | Description                                     |
| ----------------------------- | ------- | ----------------------------------------------- |
| `encodedExecutionWithoutType` | `bytes` | The execution payload, excluding the type byte. |

**Returns**

| Name         | Type          | Description                      |
| ------------ | ------------- | -------------------------------- |
| `executions` | `Execution[]` | An array of `Execution` structs. |

### safeToCalldata

Safely decodes an execution payload into a target address and raw calldata.

It first checks that the execution type is `Calldata` and then calls `toCalldata`.
It reverts with `IncorrectType` if the type is wrong.

```solidity
function safeToCalldata(Types.Operation calldata ops) internal pure returns (address target, bytes calldata rawCalldata);
```

**Parameters**

| Name  | Type              | Description                                                  |
| ----- | ----------------- | ------------------------------------------------------------ |
| `ops` | `Types.Operation` | The full encoded execution payload, including the type byte. |

**Returns**

| Name          | Type      | Description                      |
| ------------- | --------- | -------------------------------- |
| `target`      | `address` | The target address for the call. |
| `rawCalldata` | `bytes`   | The raw calldata for the call.   |

### toCalldata

Decodes a raw calldata payload (without the type byte) into a target address and raw calldata.

It assumes the first 20 bytes are the target address and the rest is the calldata.

```solidity
function toCalldata(bytes calldata encodedExecutionWithoutType) internal pure returns (address target, bytes calldata rawCalldata);
```

**Parameters**

| Name                          | Type    | Description                                     |
| ----------------------------- | ------- | ----------------------------------------------- |
| `encodedExecutionWithoutType` | `bytes` | The execution payload, excluding the type byte. |

**Returns**

| Name          | Type      | Description                      |
| ------------- | --------- | -------------------------------- |
| `target`      | `address` | The target address for the call. |
| `rawCalldata` | `bytes`   | The raw calldata for the call.   |

### encode

```solidity
function encode(SigMode sigMode, Execution[] memory exec) internal pure returns (Types.Operation memory ops);
```

### decode

```solidity
function decode(Types.Operation calldata ops) internal pure returns (SigMode sigMode, Execution[] calldata executions);
```

## Errors

### IncorrectType

```solidity
error IncorrectType()
```

## Enums

### Type

Defines the type of execution encoded in a bytes payload.

The type is determined by the first byte of the payload.

- `NONE`: No execution type specified.
- `Eip712Hash`: The payload is an EIP-712 hash (not fully implemented).
- `Calldata`: The payload is raw transaction calldata.

```solidity
enum Type {
    NONE,
    Eip712Hash,
    Calldata,
    ERC7579,
    MultiCall
}
```

### SigMode

```solidity
enum SigMode {
    NONE,
    EMISSARY,
    ERC1271,
    EMISSARY_ERC1271,
    ERC1271_EMISSARY,
    EMISSARY_EXECUTION,
    EMISSARYEXECUTION_ERC1271,
    ERC1271_EMISSARYEXECUTION
}
```
