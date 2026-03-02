# PreClaimExecution

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/arbiter/lib/PreClaimExecution.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Abstract contract enabling arbiters to execute pre-claim operations on ERC7579 accounts
before TheCompact's claim function is called. This allows using a single user signature
to authorize both pre-claim operations (like topping up locked assets) and the main claim.

CRITICAL DESIGN FEATURE: Pre-claim operations are designed to be failure-tolerant.
This prevents "fill first, claim later" flows from being broken by failed pre-claim executions,
which would void the claim and could lead to double-spend attacks.

SECURITY WARNING: Claims requiring pre-claim executions to top up TheCompact's resource lock
MUST NOT be processed in "fill first, claim later" flows. They must use Just-In-Time (JIT) flows
to prevent double spend and ensure atomic execution.

KEY BENEFITS:

- Single signature workflow: Users sign once to authorize multiple operations
- Flexible execution: Supports arbitrary ERC7579 operations on the origin chain
- Atomic settlement: Pre-claim ops and claims happen in the same transaction (JIT flow)
- Resource management: Enables dynamic topping up of TheCompact's locked assets

## State Variables

### EXECUTOR

The IIntentExecutor instance used for executing pre-claim operations on ERC7579 accounts

This executor handles the actual execution of operations signed over by TheCompact claimHash.
The executor validates signatures and executes operations on ERC7579 modular smart accounts.

```solidity
IIntentExecutor public immutable EXECUTOR
```

### CALLER

Universal caller contract used for executing multicall and direct call operations

This caller is used for non-ERC7579 execution modes (Multicall and CallData modes).
It provides a neutral execution context separate from the arbiter's address.

**Note:**
security: CRITICAL ISOLATION: The Caller contract isolates SameChainArbiter from
multicall/singlecall execution contexts. Without this isolation, malicious
pre-claim operations could potentially call executeWithoutSignature on the
IntentExecutor using the arbiter's trusted status, bypassing signature validation.

```solidity
Caller internal immutable CALLER
```

## Functions

### constructor

Initializes the PreClaimExecution contract with required execution infrastructure

Sets up both ERC7579 and general-purpose execution capabilities by initializing:

1. EXECUTOR: Retrieved from AddressBook for ERC7579 smart account operations
2. CALLER: New instance for multicall and direct call operations

**Notes:**

- security: The AddressBook must be trusted as it provides the IIntentExecutor address

- gas: Creates a new Caller contract instance, consuming ~200k gas during deployment

```solidity
constructor(address addressBook) ;
```

**Parameters**

| Name          | Type      | Description                                            |
| ------------- | --------- | ------------------------------------------------------ |
| `addressBook` | `address` | The AddressBook contract containing protocol addresses |

### \_handlePreClaimOpsCompactERC7579

Executes pre-claim ERC7579 operations on a smart account before TheCompact claim

This function is DESIGNED TO BE FAILURE-TOLERANT. Failed pre-claim operations do not
revert the entire transaction, preventing "fill first, claim later" flows from being
broken by execution failures that could lead to double-spend attacks.

EXECUTION FLOW:

1. Builds EIP-712 compact stub from order nonce, expires, and notarizedChainId
2. Calls IIntentExecutor with gas-limited execution via excessivelySafeCall
3. Uses either dedicated preClaimSig or falls back to notarizedClaimSig
4. Returns success status without reverting on failure

GAS CONSIDERATIONS:

- preClaimGasStipend limits execution gas to prevent griefing
- Gas-limited execution prevents infinite loops or excessive gas consumption
- Failed operations due to gas limits do not affect the main claim process

```solidity
function _handlePreClaimOpsCompactERC7579(
    address account,
    Types.Order calldata order,
    Types.Signatures calldata signature,
    ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
    uint256 notarizedChainId,
    uint256 preClaimGasStipend
)
    internal
    returns (bool success);
```

**Parameters**

| Name                 | Type                                             | Description                                                               |
| -------------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| `account`            | `address`                                        | The ERC7579 smart account to execute operations on                        |
| `order`              | `Types.Order`                                    | The order containing nonce, expires, and preClaimOps                      |
| `signature`          | `Types.Signatures`                               | Container with preClaimSig and notarizedClaimSig                          |
| `elementStub`        | `ICompactIntentExecutor.EIP712ElementStubOrigin` | EIP-712 element stub containing element hashes for cross-chain validation |
| `notarizedChainId`   | `uint256`                                        | The chain ID for the notarized chain (used in compact stub)               |
| `preClaimGasStipend` | `uint256`                                        | Maximum gas allowed for pre-claim execution                               |

**Returns**

| Name      | Type   | Description                                                       |
| --------- | ------ | ----------------------------------------------------------------- |
| `success` | `bool` | True if execution succeeded, false if it failed (does not revert) |

### \_handlePreClaimOpsPermit2ERC7579

Executes pre-claim ERC7579 operations on a smart account before Permit2 claim

This function is DESIGNED TO BE FAILURE-TOLERANT. Failed pre-claim operations do not
revert the entire transaction.

EXECUTION FLOW:

1. Converts preClaimOps to ERC7579 execution format
2. Calls IPermit2IntentExecutor with gas-limited execution via excessivelySafeCall
3. Uses Permit2 EIP-712 signature for authorization
4. Returns success status without reverting on failure

GAS CONSIDERATIONS:

- preClaimGasStipend limits execution gas to prevent griefing
- Gas-limited execution prevents infinite loops or excessive gas consumption
- Failed operations due to gas limits do not affect the main claim process

```solidity
function _handlePreClaimOpsPermit2ERC7579(
    address account,
    IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
    IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub,
    Types.Operation calldata preClaimOps,
    bytes calldata signature,
    uint256 preClaimGasStipend
)
    internal
    returns (bool success);
```

**Parameters**

| Name                 | Type                                              | Description                                              |
| -------------------- | ------------------------------------------------- | -------------------------------------------------------- |
| `account`            | `address`                                         | The ERC7579 smart account to execute operations on       |
| `permit2Stub`        | `IPermit2IntentExecutor.EIP712Permit2Stub`        | The Permit2 EIP-712 stub with nonce and expiration       |
| `mandateStub`        | `IPermit2IntentExecutor.EIP712Permit2MandateStub` | The Permit2 mandate stub with operation and token hashes |
| `preClaimOps`        | `Types.Operation`                                 | The operations to execute (approvals, transfers, etc.)   |
| `signature`          | `bytes`                                           | The Permit2 EIP-712 signature authorizing the operations |
| `preClaimGasStipend` | `uint256`                                         | Maximum gas allowed for pre-claim execution              |

**Returns**

| Name      | Type   | Description                                                       |
| --------- | ------ | ----------------------------------------------------------------- |
| `success` | `bool` | True if execution succeeded, false if it failed (does not revert) |

### \_handlePreClaimOpsMulticall

Executes pre-claim operations using multicall pattern for batch operations

This execution mode is used for non-ERC7579 accounts or when batch operations
need to be executed in a single transaction without smart account infrastructure.

MULTICALL EXECUTION FLOW:

1. Extracts multicall data from preClaimOps.data (skipping first 2 bytes)
2. Prepends MultiCaller.multiCall selector to create valid calldata
3. Executes via CALLER contract with gas limit protection
4. Returns success status without reverting on failure

DATA ENCODING: The preClaimOps.data format is:

- Bytes 0-1: Operation type identifier (skipped with [2:])
- Bytes 2+: Actual multicall data (target addresses, values, calldata)

**Notes:**

- security: EXECUTION ISOLATION: Uses CALLER contract to isolate execution context
  from the arbiter. This prevents malicious operations from exploiting the
  arbiter's trusted status to call executeWithoutSignature on IntentExecutor.

- gas: Gas stipend prevents unbounded execution and griefing attacks

```solidity
function _handlePreClaimOpsMulticall(Types.Operation calldata preClaimOps, uint256 preClaimGasStipend) internal returns (bool success);
```

**Parameters**

| Name                 | Type              | Description                                        |
| -------------------- | ----------------- | -------------------------------------------------- |
| `preClaimOps`        | `Types.Operation` | The operation containing multicall data to execute |
| `preClaimGasStipend` | `uint256`         | Maximum gas allowed for multicall execution        |

**Returns**

| Name      | Type   | Description                                                       |
| --------- | ------ | ----------------------------------------------------------------- |
| `success` | `bool` | True if execution succeeded, false if it failed (does not revert) |

### \_handlePreClaimOpsCallData

Executes a single pre-claim operation using direct calldata execution

This execution mode provides the most direct way to execute arbitrary contract calls
during the pre-claim phase. It's typically used for simple operations like token
approvals, transfers, or single contract interactions.

CALLDATA EXECUTION FLOW:

1. Combines target address with calldata to create executable payload
2. Executes via CALLER contract with gas limit protection
3. Returns success status without reverting on failure
4. Provides maximum flexibility for arbitrary contract interactions

ENCODING FORMAT: The execution payload is constructed as:
abi.encodePacked(target, callData)
Where target is the 20-byte contract address and callData is the function call data

USE CASES:

- Token approvals before claim execution
- Balance transfers to meet claim requirements
- State updates on external contracts
- Simple contract interactions without batch requirements

**Notes:**

- security: EXECUTION ISOLATION: Uses CALLER contract to isolate execution context
  from the arbiter. This prevents malicious operations from exploiting the
  arbiter's trusted status to call executeWithoutSignature on IntentExecutor.

- security: Target contract must be trusted as it receives arbitrary calldata

- gas: Gas stipend prevents runaway execution and ensures bounded gas usage

```solidity
function _handlePreClaimOpsCallData(address target, bytes calldata callData, uint256 preClaimGasStipend)
    internal
    returns (bool success);
```

**Parameters**

| Name                 | Type      | Description                                                        |
| -------------------- | --------- | ------------------------------------------------------------------ |
| `target`             | `address` | The contract address to call during pre-claim execution            |
| `callData`           | `bytes`   | The function selector and encoded parameters for the contract call |
| `preClaimGasStipend` | `uint256` | Maximum gas allowed for the contract call                          |

**Returns**

| Name      | Type   | Description                                                       |
| --------- | ------ | ----------------------------------------------------------------- |
| `success` | `bool` | True if execution succeeded, false if it failed (does not revert) |

## Events

### PreClaimExecutionFailed

Emitted when a pre-claim operation execution fails

This event is logged when pre-claim operations fail but do not revert the transaction.
Failure tolerance is a critical design feature to prevent double-spend attacks in
"fill first, claim later" workflows.

```solidity
event PreClaimExecutionFailed()
```
