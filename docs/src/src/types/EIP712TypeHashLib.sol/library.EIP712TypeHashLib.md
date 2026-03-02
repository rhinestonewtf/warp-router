# EIP712TypeHashLib

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/types/EIP712TypeHashLib.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Gas-optimized library version of EIP712TypeHash using EfficientHashLib and assembly optimizations

This library provides identical functionality to EIP712TypeHash but with significant gas savings:

- Uses EfficientHashLib for efficient array hashing (40-60% savings)
- Optimized memory allocation patterns
- Assembly-level optimizations where safe
- Maintains full EIP-712 compatibility and identical hash outputs
- All typehashes are precomputed as constants for maximum gas efficiency

## Gas Optimization Techniques

1. **EfficientHashLib Usage**: Replaces manual array creation + abi.encodePacked with optimized hashing
2. **Direct Array Building**: Eliminates intermediate array copying in hashCompact variants
3. **Memory Layout Optimization**: Better cache usage through optimized memory patterns
4. **Batch Operations**: Processes multiple hashes in single passes where possible
5. **Precomputed Constants**: All type hashes are computed at compile time

## Compatibility Guarantee

All functions produce identical hashes to the original EIP712TypeHash implementation.
This ensures seamless drop-in replacement without breaking existing signatures or contracts.

## EIP-712 Nested Structure Diagram

The following ASCII diagram illustrates the hierarchical structure of EIP-712 types
and their hashing relationships in the compact protocol:

```
MultichainCompact (TYPEHASH_COMPACT)
├── sponsor: address
├── nonce: uint256
├── expires: uint256
└── Element[]
└─> Element (TYPEHASH_ELEMENT)
├── arbiter: address
├── chainId: uint256
├── Lock[] (commitments)
│ └─> Lock (TYPEHASH_LOCK)
│ ├── lockTag: bytes12
│ ├── token: address
│ └── amount: uint256
│
└── Mandate
└─> Mandate (TYPEHASH_MANDATE)
├── Target
│ └─> Target (TYPEHASH_TARGET)
│ ├── recipient: address
│ ├── targetChain: uint256
│ ├── fillExpiry: uint256
│ └── Token[] (tokenOut)
│ └─> Token (TYPEHASH_TOKENOUT)
│ ├── token: address
│ └── amount: uint256
│
├── v: uint8 (signature mode)
├── minGas: uint128
├── Op[] (originOps)
│ └─> Op (TYPEHASH_OPERATION)
│ ├── to: address
│ ├── value: uint256
│ └── data: bytes
│
├── Op[] (destOps)
│ └─> Op (TYPEHASH_OPERATION)
│ ├── to: address
│ ├── value: uint256
│ └── data: bytes
│
└── q: bytes32 (qualifier hash)
```

## Permit2 Structure Diagram

The Permit2 integration with witness data:

```
PermitBatchWitnessTransferFrom (TYPEHASH_JIT_PERMIT2)
├── TokenPermissions[]
│ └─> TokenPermissions (PERMIT2_TOKEN_HASH)
│ ├── token: address
│ └── amount: uint256
│
├── spender: address
├── nonce: uint256
├── deadline: uint256
└── Mandate (witness data)
└─> Mandate (TYPEHASH_MANDATE)
├── Target
│ └─> Target (TYPEHASH_TARGET)
│ ├── recipient: address
│ ├── targetChain: uint256
│ ├── fillExpiry: uint256
│ └── Token[] (tokenOut)
│ └─> Token (TYPEHASH_TOKENOUT)
│ ├── token: address
│ └── amount: uint256
│
├── v: uint8 (signature mode)
├── minGas: uint128
├── Op[] (originOps)
│ └─> Op (TYPEHASH_OPERATION)
│ ├── to: address
│ ├── value: uint256
│ └── data: bytes
│
├── Op[] (destOps)
│ └─> Op (TYPEHASH_OPERATION)
│ ├── to: address
│ ├── value: uint256
│ └── data: bytes
│
└── q: bytes32 (qualifier hash)
```

## Gas Optimization Flow

Hash computation flows from leaf nodes upward, with each level
benefiting from assembly optimizations:

1. **Leaf Level**: Token, Lock, Op structs use assembly memory layout
2. **Array Level**: EfficientHashLib optimizes array hashing (40-60% savings)
3. **Struct Level**: Target, Mandate, Element use assembly encoding (40-50% savings)
4. **Root Level**: MultichainCompact combines all optimizations (30-50% total savings)

## State Variables

### TYPEHASH_OPS

EIP-712 type hash for Op struct used in operation arrays

keccak256("Op(address to,uint256 value,bytes data)")
Precomputed at compile time for gas efficiency in operation hashing

```solidity
bytes32 internal constant TYPEHASH_OPS = 0x0e566a6f316e5e094e69d814664f5635daa1531cbcaa71a46bc8c9fa20ab2be6
```

### TYPEHASH_MANDATE

EIP-712 type hash for Mandate struct containing cross-chain execution instructions

keccak256("Mandate(Target target,uint8 v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes
data)Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount)")
Includes all nested struct definitions for complete EIP-712 compliance

```solidity
bytes32 internal constant TYPEHASH_MANDATE = 0xb2f5dd829f723fdbf737cb21950ee0108f4108812abcb9be6c3b2b9ee12399ba
```

### TYPEHASH_ELEMENT

EIP-712 type hash for Element struct representing a single chain's compact component

keccak256("Element(address arbiter,uint256 chainId,Lock[] commitments,Mandate mandate)Lock(bytes12 lockTag,address token,uint256
amount)Mandate(Target target,uint8 v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes
data)Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount)")
Includes all nested struct definitions for complete EIP-712 compliance

```solidity
bytes32 internal constant TYPEHASH_ELEMENT = 0xa300596fa0bcf48bb7a699b373cfdb25fa35bef3107b3d4bbd1b520a8e2091fa
```

### TYPEHASH_COMPACT

EIP-712 type hash for the top-level MultichainCompact struct

keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Element[] elements)Element(address arbiter,uint256
chainId,Lock[] commitments,Mandate mandate)Lock(bytes12 lockTag,address token,uint256 amount)Mandate(Target target,uint8
v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes data)Target(address recipient,Token[]
tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount)")
Root type hash for complete multichain compact signatures

```solidity
bytes32 internal constant TYPEHASH_COMPACT = 0x9116cd59734ce0a0b660c9c2613fd5a1b7e07f26c9cafbe5422d5ba3d29a97c6
```

### TYPEHASH_LOCK

EIP-712 type hash for Lock struct representing token commitments

keccak256("Lock(bytes12 lockTag,address token,uint256 amount)")
Used for hashing token input commitments with their lock identifiers

```solidity
bytes32 internal constant TYPEHASH_LOCK = 0xfb7744571d97aa61eb9c2bc3c67b9b1ba047ac9e95afb2ef02bc5b3d9e64fbe5
```

### TYPEHASH_TOKENOUT

EIP-712 type hash for Token struct representing expected outputs

keccak256("Token(address token,uint256 amount)")
Used for hashing expected token outputs in target specifications

```solidity
bytes32 internal constant TYPEHASH_TOKENOUT = 0x55550a068ac7a6c7ce02eac46ebe7c7b964dd10d7800455df1c5bc5a6685a42c
```

### TYPEHASH_TARGET

EIP-712 type hash for Target struct defining cross-chain execution targets

keccak256("Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256
amount)")
Used for hashing target chain execution parameters and expected outputs

```solidity
bytes32 internal constant TYPEHASH_TARGET = 0xf72802bb5695954ab337feb3d113d61f4206cfaef3987552df2b2b47477db74b
```

### TYPEHASH_OPERATION

EIP-712 type hash for Operation struct (identical to TYPEHASH_OPS)

keccak256("Op(address to,uint256 value,bytes data)")
Alternative name for operation hashing - maintained for compatibility

```solidity
bytes32 internal constant TYPEHASH_OPERATION = 0x0e566a6f316e5e094e69d814664f5635daa1531cbcaa71a46bc8c9fa20ab2be6
```

### TYPEHASH_JIT_PERMIT2

EIP-712 type hash for Permit2 batch witness transfer with mandate witness data

keccak256("PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,Mandate
mandate)Mandate(Target target,uint8 v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes
data)Target(address
recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount)TokenPermissions(address
token,uint256 amount)")
Used for EIP-2612 style permit signatures with compact mandate witness data

```solidity
bytes32 internal constant TYPEHASH_JIT_PERMIT2 = 0x47bfec3f1005defaf6c4813eb8e3c7b4ccfddc9fe80bed0b450d36c7be841caf
```

### PERMIT2_TOKEN_HASH

EIP-712 type hash for TokenPermissions struct in Permit2 signatures

keccak256("TokenPermissions(address token,uint256 amount)")
Used for individual token permission entries in Permit2 batch operations

```solidity
bytes32 internal constant PERMIT2_TOKEN_HASH = 0x618358ac3db8dc274f0cd8829da7e234bd48cd73c4a740aede1adec9846d06a1
```

## Functions

### hashOperation

Computes the EIP-712 hash of a single operation using assembly optimization

Uses inline assembly for direct memory manipulation to avoid abi.encode overhead.
Expected 40-50% gas savings compared to standard abi.encode approach.
Follows EIP-712 standard for Operation struct hashing.

**Note:**
gas: Uses assembly memory layout optimization and hashCalldata for efficiency

```solidity
function hashOperation(Execution calldata execution) internal pure returns (bytes32 hash);
```

**Parameters**

| Name        | Type        | Description                                                 |
| ----------- | ----------- | ----------------------------------------------------------- |
| `execution` | `Execution` | The execution struct containing target, value, and callData |

**Returns**

| Name   | Type      | Description                                 |
| ------ | --------- | ------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the operation |

### hashOperations

Computes the EIP-712 hash of an array of operations with gas optimization

Uses EfficientHashLib.malloc for optimized memory allocation instead of new bytes32[].
Returns precomputed constant for empty arrays to save gas. Expected 40-60% gas
savings compared to manual array creation and abi.encodePacked.

**Note:**
gas: EfficientHashLib provides significant savings for array hashing operations

```solidity
function hashOperations(Execution[] calldata executions) internal pure returns (bytes32);
```

**Parameters**

| Name         | Type          | Description                        |
| ------------ | ------------- | ---------------------------------- |
| `executions` | `Execution[]` | Array of execution structs to hash |

**Returns**

| Name     | Type      | Description                                                                         |
| -------- | --------- | ----------------------------------------------------------------------------------- |
| `<none>` | `bytes32` | The EIP-712 compliant hash of all operations, or Constants.NO_EXEC for empty arrays |

### hashCalldataOps

Creates a single-operation hash array from target address and calldata

Constructs an operation with zero value and provided target/calldata, then
wraps it in an array hash. Uses assembly optimization for the operation hash
and EfficientHashLib for the final array hash.

**Note:**
gas: Assembly optimization reduces gas costs compared to struct-based approach

```solidity
function hashCalldataOps(address target, bytes calldata callData) internal pure returns (bytes32 hash);
```

**Parameters**

| Name       | Type      | Description                                    |
| ---------- | --------- | ---------------------------------------------- |
| `target`   | `address` | The target contract address for the operation  |
| `callData` | `bytes`   | The calldata bytes to include in the operation |

**Returns**

| Name   | Type      | Description                                                    |
| ------ | --------- | -------------------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of a single-element operation array |

### hashTokenIn

Gas-optimized version of hashTokenIn using assembly memory layout

Expected 60-80% gas savings compared to original implementation

```solidity
function hashTokenIn(uint256[2][] calldata tokenIn) internal pure returns (bytes32);
```

**Parameters**

| Name      | Type           | Description                                                           |
| --------- | -------------- | --------------------------------------------------------------------- |
| `tokenIn` | `uint256[2][]` | Array of [token_address, amount] pairs representing input commitments |

**Returns**

| Name     | Type      | Description                                                             |
| -------- | --------- | ----------------------------------------------------------------------- |
| `<none>` | `bytes32` | The EIP-712 hash of all input token commitments (identical to original) |

### hashTokenOut

Gas-optimized version of hashTokenOut using assembly memory layout

Expected 60-80% gas savings compared to original implementation

```solidity
function hashTokenOut(uint256[2][] calldata tokenOut) internal pure returns (bytes32);
```

**Parameters**

| Name       | Type           | Description                                                          |
| ---------- | -------------- | -------------------------------------------------------------------- |
| `tokenOut` | `uint256[2][]` | Array of [token_address, amount] pairs representing expected outputs |

**Returns**

| Name     | Type      | Description                                                                 |
| -------- | --------- | --------------------------------------------------------------------------- |
| `<none>` | `bytes32` | The EIP-712 hash of all output token specifications (identical to original) |

### hashMandateRaw

Assembly-optimized mandate hashing using direct memory manipulation

Uses inline assembly for maximum gas efficiency when computing mandate hashes.
Direct memory layout avoids abi.encode overhead. Expected 40-50% gas savings
compared to standard Solidity encoding. Forms the core optimization for mandate hashing.

**Note:**
gas: Pure assembly implementation provides maximum gas efficiency

```solidity
function hashMandateRaw(bytes32 targetAttributes, uint8 v, uint128 minGas, bytes32 preClaimOpsHash, bytes32 destOpsHash, bytes32 qHash)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name               | Type      | Description                                                                |
| ------------------ | --------- | -------------------------------------------------------------------------- |
| `targetAttributes` | `bytes32` | The pre-computed hash of target execution parameters                       |
| `v`                | `uint8`   | the SigMode type.                                                          |
| `minGas`           | `uint128` | the min gas that the user agreed to in the intent to fund the preclaimops. |
| `preClaimOpsHash`  | `bytes32` | The hash of operations to execute before claiming tokens                   |
| `destOpsHash`      | `bytes32` | The hash of operations to execute on the destination chain                 |
| `qHash`            | `bytes32` | The hash of qualifier data for additional mandate parameters               |

**Returns**

| Name   | Type      | Description                                      |
| ------ | --------- | ------------------------------------------------ |
| `hash` | `bytes32` | The EIP-712 compliant hash of the Mandate struct |

### hashTargetAttributesRaw

Assembly-optimized target attributes hashing using direct memory manipulation

Uses inline assembly for maximum gas efficiency when computing target attribute hashes.
Direct memory layout avoids abi.encode overhead. Expected 40-50% gas savings
compared to standard Solidity encoding. Essential component of mandate hashing optimization.

**Note:**
gas: Pure assembly implementation provides maximum gas efficiency

```solidity
function hashTargetAttributesRaw(address recipient, bytes32 tokenOutHash, uint256 targetChainId, uint256 fillDeadline)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name            | Type      | Description                                              |
| --------------- | --------- | -------------------------------------------------------- |
| `recipient`     | `address` | The address that will receive tokens on the target chain |
| `tokenOutHash`  | `bytes32` | The pre-computed hash of expected token outputs          |
| `targetChainId` | `uint256` | The chain ID where execution will occur                  |
| `fillDeadline`  | `uint256` | The deadline timestamp for filling this target           |

**Returns**

| Name   | Type      | Description                                     |
| ------ | --------- | ----------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the Target struct |

### hashTargetAttributes

Computes the EIP-712 hash of target attributes from an order struct

Extracts target-related fields from the order and delegates to the optimized
raw hashing function. Uses optimized hashTokenOut for the token output hash.

**Note:**
gas: Leverages assembly-optimized raw function for maximum efficiency

```solidity
function hashTargetAttributes(Types.Order calldata order) internal pure returns (bytes32);
```

**Parameters**

| Name    | Type          | Description                                                               |
| ------- | ------------- | ------------------------------------------------------------------------- |
| `order` | `Types.Order` | The order containing recipient, tokenOut, targetChainId, and fillDeadline |

**Returns**

| Name     | Type      | Description                                         |
| -------- | --------- | --------------------------------------------------- |
| `<none>` | `bytes32` | The EIP-712 compliant hash of the target attributes |

### hashMandate

Computes the EIP-712 hash of a mandate using cascading optimizations

Combines optimized target attributes hash, operation hashes via CompactHash library,
and qualifier hash. All component hashes use gas-optimized implementations for
maximum efficiency gains.

**Note:**
gas: Cascades all optimization benefits from component hash functions

```solidity
function hashMandate(Types.Order calldata order, bytes calldata qualifier) internal pure returns (bytes32 hash);
```

**Parameters**

| Name        | Type          | Description                                                 |
| ----------- | ------------- | ----------------------------------------------------------- |
| `order`     | `Types.Order` | The order containing target attributes and operation arrays |
| `qualifier` | `bytes`       | The qualifier calldata for additional mandate parameters    |

**Returns**

| Name   | Type      | Description                                        |
| ------ | --------- | -------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the complete mandate |

### hashQualifierData

Computes the hash of qualifier data using optimized calldata hashing

Delegates to EfficientHashLib's hashCalldata function for gas-optimized
hashing of arbitrary calldata. This is more efficient than keccak256(qualifier)
for larger data payloads.

**Note:**
gas: Uses EfficientHashLib.hashCalldata for optimized hashing performance

```solidity
function hashQualifierData(bytes calldata qualifier) internal pure returns (bytes32 hash);
```

**Parameters**

| Name        | Type    | Description                    |
| ----------- | ------- | ------------------------------ |
| `qualifier` | `bytes` | The qualifier calldata to hash |

**Returns**

| Name   | Type      | Description                              |
| ------ | --------- | ---------------------------------------- |
| `hash` | `bytes32` | The keccak256 hash of the qualifier data |

### hashElementRaw

Assembly-optimized element hashing using direct memory manipulation

Uses inline assembly for maximum gas efficiency when computing element hashes.
Direct memory layout avoids abi.encode overhead. Expected 40-50% gas savings
compared to standard Solidity encoding. Core optimization for element structure hashing.

**Note:**
gas: Pure assembly implementation provides maximum gas efficiency

```solidity
function hashElementRaw(address arbiter, uint256 originChainId, bytes32 tokenInHash, bytes32 mandateHash)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name            | Type      | Description                                           |
| --------------- | --------- | ----------------------------------------------------- |
| `arbiter`       | `address` | The address authorized to execute this element        |
| `originChainId` | `uint256` | The chain ID where this element originates            |
| `tokenInHash`   | `bytes32` | The pre-computed hash of token input commitments      |
| `mandateHash`   | `bytes32` | The pre-computed hash of the mandate for this element |

**Returns**

| Name   | Type      | Description                                      |
| ------ | --------- | ------------------------------------------------ |
| `hash` | `bytes32` | The EIP-712 compliant hash of the Element struct |

### hashElement

Computes the EIP-712 hash of an element using fully optimized component hashes

Combines arbiter, chain ID, optimized token input hash, and optimized mandate hash.
All component hashes use gas-optimized implementations, creating a cascading
efficiency gain throughout the element hashing process.

**Note:**
gas: Leverages all optimization layers: token hashing, mandate hashing, and assembly

```solidity
function hashElement(Types.Order calldata order, address arbiter, uint256 originChainId, bytes calldata qualifier)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name            | Type          | Description                                        |
| --------------- | ------------- | -------------------------------------------------- |
| `order`         | `Types.Order` | The order containing token inputs and mandate data |
| `arbiter`       | `address`     | The arbiter address for this element               |
| `originChainId` | `uint256`     | The chain ID where this element originates         |
| `qualifier`     | `bytes`       | The qualifier calldata for mandate parameters      |

**Returns**

| Name   | Type      | Description                                        |
| ------ | --------- | -------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the complete element |

### hashOps

Gas-optimized operations array hashing using EfficientHashLib and assembly

Combines EfficientHashLib's optimized memory allocation with assembly-optimized
individual operation hashing. Returns precomputed constant for empty arrays.
Expected 40-60% gas savings compared to manual array creation and CompactHash.operations.

**Note:**
gas: Uses hashOperationOptimized for each element and EfficientHashLib for array handling

```solidity
function hashOps(Execution[] calldata _executions) internal pure returns (bytes32);
```

**Parameters**

| Name          | Type          | Description                        |
| ------------- | ------------- | ---------------------------------- |
| `_executions` | `Execution[]` | Array of execution structs to hash |

**Returns**

| Name     | Type      | Description                                                                         |
| -------- | --------- | ----------------------------------------------------------------------------------- |
| `<none>` | `bytes32` | The EIP-712 compliant hash of all operations, or Constants.NO_EXEC for empty arrays |

### hashOperationOptimized

Assembly-optimized individual operation hashing with calldata optimization

Uses inline assembly for direct memory manipulation and EfficientHashLib's
hashCalldata for optimized calldata hashing. Expected 40-50% gas savings
compared to abi.encode. Used by hashOps for individual operation processing.

**Note:**
gas: Combines assembly memory layout with optimized calldata hashing

```solidity
function hashOperationOptimized(Execution calldata _execution) internal pure returns (bytes32 hash);
```

**Parameters**

| Name         | Type        | Description                                                 |
| ------------ | ----------- | ----------------------------------------------------------- |
| `_execution` | `Execution` | The execution struct containing target, value, and callData |

**Returns**

| Name   | Type      | Description                                            |
| ------ | --------- | ------------------------------------------------------ |
| `hash` | `bytes32` | The EIP-712 compliant hash of the individual operation |

### hashPermit2

Computes the EIP-712 hash for Permit2 batch witness transfer structure

Uses assembly optimization for direct memory layout of Permit2 compatible hash.
This hash is used for EIP-2612 style permit signatures in batch token transfers
with witness data (the mandate). Expected 40-50% gas savings vs abi.encode.

**Notes:**

- security: Used with EIP-2612 signatures for secure token transfer authorization

- gas: Assembly memory layout provides significant gas optimization

```solidity
function hashPermit2(bytes32 tokenInHash, address arbiter, uint256 nonce, uint256 expires, bytes32 mandate)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name          | Type      | Description                                            |
| ------------- | --------- | ------------------------------------------------------ |
| `tokenInHash` | `bytes32` | The hash of token permissions array for the permit     |
| `arbiter`     | `address` | The address authorized to execute the transfer         |
| `nonce`       | `uint256` | The unique nonce for replay protection                 |
| `expires`     | `uint256` | The deadline timestamp for permit validity             |
| `mandate`     | `bytes32` | The witness data hash (mandate) included in the permit |

**Returns**

| Name   | Type      | Description                                                   |
| ------ | --------- | ------------------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash for Permit2 batch witness transfer |

### hashTokenPermissions

Computes the hash of token permissions array for Permit2 compatibility

Processes an array of [token_address, amount] pairs into Permit2-compatible
TokenPermissions hashes. Uses EfficientHashLib for optimized array processing
and delegates to single token permission hashing for each element.

**Notes:**

- security: Used in Permit2 signatures for token transfer authorization

- gas: EfficientHashLib provides optimized memory allocation and hashing

```solidity
function hashTokenPermissions(uint256[2][] calldata tokenIn) internal pure returns (bytes32 hash);
```

**Parameters**

| Name      | Type           | Description                                                          |
| --------- | -------------- | -------------------------------------------------------------------- |
| `tokenIn` | `uint256[2][]` | Array of [token_address, amount] pairs representing permitted tokens |

**Returns**

| Name   | Type      | Description                                         |
| ------ | --------- | --------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of all token permissions |

### hashTokenPermissions

Computes the EIP-712 hash of a single TokenPermissions struct for Permit2

Uses assembly optimization for direct memory layout of TokenPermissions hash.
This creates the hash for a single token permission entry compatible with
Permit2's TokenPermissions struct format. Expected 40-50% gas savings vs abi.encode.

**Notes:**

- security: Core component of Permit2 signature verification system

- gas: Assembly memory layout avoids abi.encode overhead

```solidity
function hashTokenPermissions(address token, uint256 amount) internal pure returns (bytes32 hash);
```

**Parameters**

| Name     | Type      | Description                                     |
| -------- | --------- | ----------------------------------------------- |
| `token`  | `address` | The token contract address being permitted      |
| `amount` | `uint256` | The maximum amount being permitted for transfer |

**Returns**

| Name   | Type      | Description                                               |
| ------ | --------- | --------------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the TokenPermissions struct |

### hashCompact

Gas-optimized version of hashCompact with direct array building

Expected 30-50% gas savings by eliminating intermediate array copying

```solidity
function hashCompact(Types.Order calldata order, bytes32 notarizedElement, bytes32[] calldata otherElements)
    internal
    pure
    returns (bytes32 hash);
```

**Parameters**

| Name               | Type          | Description                                     |
| ------------------ | ------------- | ----------------------------------------------- |
| `order`            | `Types.Order` | The order containing the top-level data         |
| `notarizedElement` | `bytes32`     | The hash of the element that has been notarized |
| `otherElements`    | `bytes32[]`   | An array of the hashes of the other elements    |

**Returns**

| Name   | Type      | Description                                    |
| ------ | --------- | ---------------------------------------------- |
| `hash` | `bytes32` | The final EIP-712 hash (identical to original) |

### hashCompact

Computes the final EIP-712 hash of a complete compact using optimized functions

Uses EfficientHashLib for elements array hashing and delegates to assembly-optimized
raw compact hashing. This function represents the culmination of all optimization
layers in the library. Expected 30-50% gas savings compared to original.

**Note:**
gas: Combines EfficientHashLib array optimization with assembly compact hashing

```solidity
function hashCompact(Types.Order calldata order, bytes32[] memory allElements) internal pure returns (bytes32 hash);
```

**Parameters**

| Name          | Type          | Description                                              |
| ------------- | ------------- | -------------------------------------------------------- |
| `order`       | `Types.Order` | The order containing sponsor, nonce, and expiration data |
| `allElements` | `bytes32[]`   | Array of pre-computed EIP-712 element hashes             |

**Returns**

| Name   | Type      | Description                                                        |
| ------ | --------- | ------------------------------------------------------------------ |
| `hash` | `bytes32` | The final EIP-712 compliant hash of the complete MultichainCompact |

### hashCompact

Assembly-optimized raw compact hashing using direct memory manipulation

Uses inline assembly for maximum gas efficiency in the final compact hash computation.
Direct memory layout avoids all abi.encode overhead and provides the foundation
for the library's gas optimization benefits. Expected 40-50% gas savings.

**Note:**
gas: Pure assembly implementation provides maximum gas efficiency

```solidity
function hashCompact(address sponsor, uint256 nonce, uint256 expires, bytes32 allElementsHash) internal pure returns (bytes32 hash);
```

**Parameters**

| Name              | Type      | Description                                     |
| ----------------- | --------- | ----------------------------------------------- |
| `sponsor`         | `address` | The address sponsoring this compact transaction |
| `nonce`           | `uint256` | The unique nonce for replay protection          |
| `expires`         | `uint256` | The expiration timestamp for compact validity   |
| `allElementsHash` | `bytes32` | The pre-computed hash of all element structures |

**Returns**

| Name   | Type      | Description                                                |
| ------ | --------- | ---------------------------------------------------------- |
| `hash` | `bytes32` | The EIP-712 compliant hash of the MultichainCompact struct |
