# RouterLogic

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/RouterLogic.sol)

**Inherits:**
[IRouter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/IRouter.sol/interface.IRouter.md), [RouterManager](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/RouterManager.sol/contract.RouterManager.md), [DirectRoutes](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/DirectRoutes.sol/abstract.DirectRoutes.md), ReentrancyGuardTransient, [HandleSafeFillETH](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/HandleNative.sol/contract.HandleSafeFillETH.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Core routing logic contract for the Warp Routerr ecosystem, orchestrating settlement operations
across multiple protocols and adapters with advanced gas optimization and security features.

ARCHITECTURAL OVERVIEW:
The RouterLogic serves as the central coordination hub for all settlement operations within the
Rhinestone ecosystem. It implements a sophisticated adapter pattern where different protocols
(Compact, Permit2, cross-chain bridges) can be plugged in as adapters while maintaining
consistent routing logic and security guarantees.
Core Responsibilities:\*\*

1. **Operation Routing**: Routes fill and claim operations to appropriate protocol adapters
2. **Atomic Execution**: Ensures batched operations execute atomically or revert entirely
3. **Gas Optimization**: Implements advanced caching and optimization techniques for batch operations
4. **Security Enforcement**: Validates signatures and prevents unauthorized operation execution
5. **Context Management**: Manages solver-specific contexts for each operation in a batch

OPERATION TYPES:
Fill Operations**: Settlement operations that fulfill user orders by transferring assets
and executing user-specified target operations. Require atomic signature validation.
Claim Operations**: Resource unlock operations that claim user assets from protocols
like Compact or Permit2. Can be executed independently without atomic signatures.

ADAPTER ARCHITECTURE:
The router uses a selector-based adapter system where each operation type maps to a specific
adapter contract via a 4-byte function selector. This enables:

- **Modular Protocol Support**: New protocols can be added by registering new adapters
- **Version Management**: Protocol upgrades handled through adapter replacement
- **Gas Efficiency**: Direct routing eliminates unnecessary abstraction layers
- **Special Operations**: Built-in selectors bypass adapter layer for common operations

GAS OPTIMIZATION FEATURES:
Adapter Caching**: Consecutive operations with same selector reuse cached adapter addresses
Calldata Encoding**: Optimized encoding reduces calldata costs for batch operations
Assembly Decoding**: Direct calldata access avoids memory copying overhead
Context Indexing**: Efficient solver context consumption tracking
Special Selectors\*\*: Built-in operations bypass adapter lookup entirely

SECURITY MODEL:
Atomic Signatures**: Fill operations require signature from designated atomicFillSigner
Reentrancy Protection**: All external functions protected via ReentrancyGuardTransient
Access Control**: RouterManager provides role-based adapter management
Context Validation**: Ensures solver contexts match operation requirements
Batch Integrity\*\*: All operations in a batch must succeed or entire batch reverts

DEPLOYMENT ARCHITECTURE:
Designed as upgradeable logic contract behind a proxy pattern. The proxy holds state
while RouterLogic contains the execution logic, enabling upgrades without state migration.
Inherits from RouterManager for adapter management and DirectRoutes for special operations.

**Notes:**

- security: All fill operations require valid atomic signatures

- security: Reentrancy protection prevents recursive calls during settlement operations

- gas: Advanced optimization techniques reduce gas costs for batch operations by 20-40%

- upgradeable: Logic contract designed for proxy-based upgrades with state preservation

## Functions

### constructor

Initializes the RouterLogic contract with essential security and management addresses.

Sets up the core security and management infrastructure for the router:
Atomic Fill Security**: The atomicFillSigner is the only address authorized to sign
atomic batch operations. This prevents unauthorized solvers from executing user operations
without proper validation. Setting this to address(0) effectively pauses all fill operations.
Role-Based Management**: The adder and remover addresses receive respective roles for
adapter management through the RouterManager inheritance. This enables controlled
protocol upgrades and adapter management without compromising existing operations.

**Notes:**

- security: The atomicFillSigner address is immutable after deployment and controls all fill security

- access: Adapter management roles can be transferred or revoked through RouterManager functions

- deployment: This constructor runs only once during initial deployment or proxy initialization

```solidity
constructor(address atomicFillSigner, address adder, address remover) RouterManager(adder, remover);
```

**Parameters**

| Name               | Type      | Description                                                                                                                                                                                                    |
| ------------------ | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `atomicFillSigner` | `address` | The address authorized to sign atomic fill batch operations. Must be non-zero for fill operations to function. This address should be carefully managed as it controls all user asset movements through fills. |
| `adder`            | `address` | The address granted ADAPTER_ADDER_ROLE for registering new protocol adapters. Allows controlled addition of new protocol support without contract upgrades.                                                    |
| `remover`          | `address` | The address granted ADAPTER_REMOVER_ROLE for disabling problematic adapters. Provides emergency mechanism to disable compromised or deprecated adapters.                                                       |

### \_isAtomic

Validates atomic execution authorization by verifying a cryptographic signature

This function implements the core security mechanism for atomic batch operations.
It ensures that only the designated atomic signer can authorize the execution of
multiple operations together. This prevents unauthorized solvers from executing
operations without proper validation and maintains protocol security.
The atomic signature system serves two critical purposes:

1. **Authorization Control**: Only the protocol's designated signer can approve batches
2. **Replay Protection**: Each signature is tied to specific calldata via the hash
   Implementation uses ECDSA signature recovery to verify the signer without requiring
   the signer's public key as input, reducing calldata costs.

**Notes:**

- security: This function is critical for protocol security:
- The atomicFillSigner address is stored in contract storage and set during
  construction or initialization. If set to address(0), atomic fills are paused.
- Uses ECDSA signature recovery which is resistant to signature malleability attacks
- The hash parameter prevents signature replay across different operation batches
- Virtual function allows for override in derived contracts (e.g., simulation)

- gas: Optimizes gas usage by:
- Caching $atomicFillSigner from storage to avoid multiple SLOADs
- Using ECDSA.recoverCalldata which operates directly on calldata without copying
- Single storage read (2100 gas for cold slot, 100 gas for warm slot)

```solidity
function _isAtomic(bytes32 hash, bytes calldata atomicSig) internal virtual returns (bool atomic);
```

**Parameters**

| Name        | Type      | Description                                                                                                                                                                                                          |
| ----------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hash`      | `bytes32` | The keccak256 hash of the encoded adapter calldatas being executed atomically. This hash binds the signature to the specific operations being performed, preventing signature reuse across different operation sets. |
| `atomicSig` | `bytes`   | The ECDSA signature generated by the atomic signer over the provided hash. Must be in the format expected by ECDSA.recoverCalldata (65 bytes: r + s + v).                                                            |

**Returns**

| Name     | Type   | Description                                                                                                                                                                       |
| -------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `atomic` | `bool` | True if the signature is valid and came from the authorized atomic signer, false otherwise. A false return will cause the calling function to revert with InvalidAtomicity error. |

### optimized_routeFill921336808

Gas-optimized version of routeFill with enhanced batching and caching mechanisms.

This function implements several gas optimizations over the standard routeFill:

1. **Encoded Calldata Format**: Instead of accepting a bytes[] array directly, it accepts
   an ABI-encoded bytes parameter that contains the array. This reduces calldata costs
   as the array doesn't need to be decoded initially, saving ~200-500 gas per element.
2. **Adapter Caching**: The function caches the last used adapter address and its selector.
   When consecutive calls use the same selector (common in batch operations), it reuses
   the cached adapter instead of performing an SLOAD operation. Each cache hit saves
   ~2100 gas (cold SLOAD cost).
3. **Special Selector Optimization**: Built-in selectors (singleCall, multiCall, fee collection)
   bypass the adapter lookup entirely and are handled directly, saving both SLOAD operations
   and DELEGATECALL overhead (~2600+ gas per special call).
4. **Inline Assembly Decoding**: Uses assembly to decode the encoded calldata array without
   copying to memory, operating directly on calldata pointers. This saves memory expansion
   costs and unnecessary data copying.
5. **Solver Context Management**: Distinguishes between operations that consume solver contexts
   (regular adapter calls) and those that don't (special selectors), preventing unnecessary
   array access and bounds checking for special operations.

```solidity
function optimized_routeFill921336808(
    bytes[] calldata relayerContexts,
    bytes calldata encodedAdapterCalldatas,
    bytes calldata atomicFillSignature
)
    public
    payable
    virtual
    handleNative
    nonReentrant;
```

**Parameters**

| Name                      | Type      | Description                                                                                                                                                   |
| ------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `relayerContexts`         | `bytes[]` | Array of solver-specific contexts, consumed only by regular adapter calls. Special selectors (singleCall, multiCall, fee collection) do not consume contexts. |
| `encodedAdapterCalldatas` | `bytes`   | ABI-encoded bytes containing the array of adapter calldatas. Must be encoded as: abi.encode(bytes[] adapterCalldatas)                                         |
| `atomicFillSignature`     | `bytes`   | Signature from atomicFillSigner authorizing this batch execution. Signed message is keccak256(encodedAdapterCalldatas).                                       |

### routeClaim

Executes multiple claim operations in batch, routing each to its corresponding protocol adapter.

Implements efficient batch claim processing with gas optimization features:
BATCH CLAIM PROCESSING:**
Unlike fill operations, claim operations don't require atomic signatures as they represent
resource unlocking from protocols where users have already authorized the operations through
signatures at the protocol level (Compact mandate signatures, Permit2 permits, etc.).
GAS OPTIMIZATION TECHNIQUES:**

1. **Adapter Caching**: Consecutive operations with the same selector reuse cached adapter
   addresses, avoiding repeated SLOAD operations (saves ~2100 gas per cache hit).
2. **Context Indexing**: Efficient tracking of solver context consumption without array bounds checking.
3. **Special Selector Bypass**: Built-in operations (singleCall, multiCall) handled directly
   without adapter lookup, saving ~2600+ gas per special operation.
   OPERATION FLOW:\*\*
4. Extract 4-byte selector from each calldata to identify the target adapter
5. Check for special selectors that bypass adapter lookup (gas optimization)
6. For regular operations: load adapter (with caching), consume solver context, execute
7. Validate all solver contexts were consumed (prevents misconfiguration)
   ERROR HANDLING:\*\*
   All operations must succeed or the entire batch reverts, ensuring consistent state.
   Length mismatch between solver contexts and regular operations will revert the batch.

**Notes:**

- gas: Optimized for batch processing with caching and special selector handling

- atomic: All operations succeed or entire batch reverts for consistency

- security: No signature validation required - relies on protocol-level authorization

```solidity
function routeClaim(bytes[] calldata relayerContexts, bytes[] calldata adapterCalldatas) external payable;
```

**Parameters**

| Name               | Type      | Description                                                                                                                                                                                                  |
| ------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `relayerContexts`  | `bytes[]` | Array of solver-specific contexts for each non-special operation. Each regular adapter call consumes one context in order. Special selectors (singleCall, multiCall, fee collection) don't consume contexts. |
| `adapterCalldatas` | `bytes[]` | Array of calldata for adapter execution, each prefixed with a 4-byte selector identifying the target adapter or special operation type.                                                                      |

### routeClaim

Executes a single claim operation by routing it to the appropriate protocol adapter.

Simplified single-operation version of the batch routeClaim function. Provides the same
functionality as the batch version but optimized for single operations:
SINGLE OPERATION FLOW:\*\*

1. Extract the 4-byte selector from calldata to identify operation type
2. Check for special selectors (singleCall, multiCall) that bypass adapter lookup
3. For regular operations: load the appropriate claim adapter and execute with context
4. Ensure adapter call succeeds with matching selector validation
   SPECIAL SELECTOR SUPPORT:\*\*
   Built-in selectors for common operations are handled directly without adapter lookup:

- Single calls for direct contract interactions
- Multi calls for batched contract interactions
- Fee collection operations
  This saves ~2600+ gas by avoiding SLOAD and DELEGATECALL overhead.
  PROTOCOL ADAPTER EXECUTION:\*\*
  Regular claim operations are routed to protocol-specific adapters (SameChainAdapter,
  CrossChainAdapter, etc.) that handle the underlying protocol interactions for resource
  unlocking and settlement completion.

**Notes:**

- gas: Single operation version avoids batch processing overhead for simple claims

- security: No atomic signature required - relies on protocol-level authorization

- efficiency: Special selectors bypass adapter lookup for maximum gas efficiency

```solidity
function routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) public payable;
```

**Parameters**

| Name              | Type    | Description                                                                                                                                                                                                     |
| ----------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `relayerContext`  | `bytes` | The solver-specific context data required by the adapter for this claim. Contains parameters like user addresses, amounts, signatures, and other operation-specific data needed for successful claim execution. |
| `adapterCalldata` | `bytes` | The complete calldata for adapter execution, including the 4-byte selector and encoded parameters. The selector determines which adapter to route to, while parameters contain the operation-specific data.     |
