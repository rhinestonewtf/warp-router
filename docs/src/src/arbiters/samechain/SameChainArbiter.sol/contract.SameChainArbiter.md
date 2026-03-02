# SameChainArbiter

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/arbiters/samechain/SameChainArbiter.sol)

**Inherits:**
[ArbiterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/arbiter/ArbiterBase.sol/contract.ArbiterBase.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Arbiter contract for validating and executing same-chain order settlements within the Router ecosystem.
This contract handles the core settlement logic for orders where both origin and execution occur
on the same blockchain, providing atomic settlement guarantees while supporting both Compact
and Permit2 protocols with their respective validation and execution patterns.

SAME-CHAIN SETTLEMENT PROCESSING:
The arbiter implements the critical resource unlock and execution phase of same-chain settlement.
It works in coordination with SameChainAdapter, which pre-funds recipients before calling the arbiter.
The arbiter's role is to validate user authorization and execute the final settlement steps:

1. **SIGNATURE VALIDATION**: Verifies user signatures against order data and metadata
2. **PRE-CLAIM EXECUTION**: Handles pre-claim operations (approvals, setup) for Compact protocol
3. **RESOURCE UNLOCKING**: Claims and unlocks user input tokens from the appropriate protocol
4. **TARGET EXECUTION**: Executes user-specified operations (swaps, transfers) on target assets

DUAL PROTOCOL ARCHITECTURE:
Supports both major authorization protocols with protocol-specific handling:
Compact Protocol Flow:\*\*

- Validates complex signatures and metadata (otherElements, allocatorData)
- Executes pre-claim operations with allocated gas stipends
- Handles notarized chain validation and resource unlock
- Supports multi-step operations and complex authorization patterns
  Permit2 Protocol Flow:\*\*
- Streamlined validation with simplified signature requirements
- Direct resource unlock without pre-claim complexity
- Optimized for gas efficiency and simple token operations
- Lower overhead for straightforward token transfers and swaps

SECURITY AND VALIDATION:

- **Access Control**: Only Router can call arbiter functions (onlyRouter modifier)
- **Signature Security**: All user signatures validated before any asset movements
- **Atomic Execution**: Either entire settlement succeeds or reverts completely
- **Protocol Integrity**: Maintains protocol-specific validation rules and constraints
- **Target Operation Safety**: User operations executed in controlled environment

INTEGRATION PATTERNS:

- Extends ArbiterBase for common arbiter functionality and Router integration
- Uses SmartExecutionLib for target operation execution without separate signatures
- Coordinates with SameChainAdapter for complete settlement orchestration
- Provides protocol-specific entry points for different authorization methods

**Notes:**

- security: Arbiter validation occurs after recipient pre-funding to ensure atomicity.
  If validation fails, the entire transaction reverts including pre-funding.

- security: TRUSTED EXECUTOR MODEL: SameChainArbiter is whitelisted as a trusted contract
  in the IntentExecutor. This enables a critical gas optimization where target
  operations can be executed without additional signature validation after
  successful permit2/compact transfers. The signature validation occurs once
  during the pre-claim phase, and subsequent target operation execution uses
  executeOpsWithoutSignature to avoid a costly third signature check.

- security: SIGNATURE VALIDATION FLOW: Pre-claim operations require full signature validation
  against order data and metadata. After successful resource unlock (permit2 or
  compact transfer), the arbiter's trusted status allows target operations to
  execute without re-validating signatures, reducing gas costs while maintaining
  security through the initial validation gate.

- gas: Same-chain arbitration is optimized for lower gas costs compared to cross-chain
  alternatives, with single-transaction settlement and efficient validation.

- architecture: The arbiter pattern separates validation/execution logic from adapter coordination,
  enabling modular settlement flows and protocol-specific optimization.

- limitation: EXOGENOUS CHAIN CLAIMS NOT IMPLEMENTED: This arbiter does not implement compact claims
  for exogenous chains. For simplicity, when a multichain intent requires a same-chain
  transaction, it is always executed as the notarized chain using handleCompact_NotarizedChain.

## Functions

### constructor

Initializes the SameChainArbiter with required protocol contracts.

Sets up the arbiter for same-chain settlement validation and execution.
The arbiter requires access to the Router for access control, the Compact contract
for resource unlocking, and the AddressBook for protocol configuration.

**Note:**
security: All three addresses are stored as immutable to prevent malicious redirection.
The Router address specifically enforces that only authorized adapters can trigger settlement.

```solidity
constructor(address router, address compact, address addressBook) ArbiterBase(router, compact, addressBook);
```

**Parameters**

| Name          | Type      | Description                                                                                                                                           |
| ------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `router`      | `address` | The Router contract address that will call this arbiter. Used for access control to ensure only authorized settlement requests.                       |
| `compact`     | `address` | The Compact protocol contract address for resource unlocking and validation. Handles the core authorization and token claim logic for Compact orders. |
| `addressBook` | `address` | The AddressBook contract containing protocol configuration and addresses. Provides centralized configuration for protocol contracts and parameters.   |

### handleCompact_NotarizedChain

Handles complete Compact protocol same-chain settlement with full feature support.

Orchestrates the comprehensive 3-step Compact settlement process for same-chain orders:
STEP 1: PRE-CLAIM VALIDATION AND EXECUTION\*\*

- Validates order signatures and metadata using \_compactPreClaimOps
- Executes any pre-claim operations (approvals, setup calls) with allocated gas stipend
- Generates mandate hash for subsequent resource unlock validation
- Ensures all prerequisites are met before resource claiming begins
  STEP 2: RESOURCE UNLOCK AND DEPOSITING\*\*
- Calls \_unlockNotarizedChain to validate signatures against mandate hash
- Unlocks user's input tokens from the Compact protocol contracts
- Transfers input tokens to the specified relayer (solver's recipient address)
- Returns claim hash for tracking and potential future reference
  STEP 3: TARGET OPERATION EXECUTION\*\*
- Executes user-specified target operations using SmartExecutionLib
- Operations run without requiring additional signatures (mandate-based execution)
- Typically includes swaps, transfers, or other token operations on user's behalf
- Maintains atomic execution - if target ops fail, entire settlement reverts
- **EXECUTION CONDITION**: Target operations are only executed if recipient equals sponsor
- If condition not met, emits SameChainTargetOpsNotHandled() event and skips execution

**Notes:**

- access: Only callable by Router via SameChainAdapter (enforced by onlyRouter modifier).

- security: All signatures validated before any asset movements or operations occur.

- security: TRUSTED EXECUTION: Target operations execute without signature validation due to
  SameChainArbiter's trusted status in IntentExecutor, saving gas after initial validation.

- atomic: If any step fails, the entire transaction reverts including any partial state changes.

- gas: Pre-claim gas stipend ensures complex setup operations don't run out of gas.

```solidity
function handleCompact_NotarizedChain(
    Types.Order calldata order,
    Types.Signatures calldata sigs,
    bytes32[] calldata otherElements,
    bytes calldata allocatorData,
    address relayer
)
    external
    onlyRouter
    returns (bytes32 claimHash);
```

**Parameters**

| Name            | Type               | Description                                                                                                                                                  |
| --------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `order`         | `Types.Order`      | Complete order specification including tokens, operations, deadlines, and metadata. Contains all information needed for settlement validation and execution. |
| `sigs`          | `Types.Signatures` | Container for required signatures including notarized claim sig and optional pre-claim sig. Used to validate user authorization for the settlement.          |
| `otherElements` | `bytes32[]`        | Array of additional order element hashes for complex multi-element orders. Typically empty for single-element same-chain settlements.                        |
| `allocatorData` | `bytes`            | Protocol-specific data for the Compact allocator contract. Contains parameters needed for resource allocation and validation.                                |
| `relayer`       | `address`          | Address where input tokens will be deposited after successful unlock. Typically the solver's address or a solver-controlled withdrawal contract.             |

**Returns**

| Name        | Type      | Description                                                                                                                                           |
| ----------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claimHash` | `bytes32` | Hash identifying this specific claim for tracking and potential future operations. Can be used for order lifecycle management and dispute resolution. |

### handlePermit2

Handles streamlined Permit2 protocol same-chain settlement with optimized efficiency.

Orchestrates the simplified 3-step Permit2 settlement process for same-chain orders:
STEP 1: PRE-CLAIM VALIDATION\*\*

- Validates order signatures using \_permit2PreClaimOps for Permit2-specific requirements
- Generates mandate hash for subsequent resource unlock without complex pre-claim operations
- Skips gas stipend allocation and complex setup operations for efficiency
  STEP 2: RESOURCE UNLOCK AND DEPOSITING\*\*
- Calls \_unlockPermit2 with simplified signature validation against mandate hash
- Unlocks user's input tokens directly from Permit2 protocol contracts
- Transfers input tokens to the specified relayer address without intermediate steps
- More efficient than Compact due to Permit2's streamlined authorization model
  STEP 3: TARGET OPERATION EXECUTION\*\*
- Executes user-specified target operations using the same SmartExecutionLib as Compact
- Operations typically simpler for Permit2 (direct transfers, basic swaps)
- Maintains atomic execution guarantees despite simplified flow
- Lower gas overhead due to reduced validation complexity
- **EXECUTION CONDITIONS**: Target operations are only executed if:

1. recipient equals sponsor AND
2. target operations are NOT using execution emissary pattern

- If conditions not met, emits SameChainTargetOpsNotHandled() event and skips execution
  The Permit2 flow is optimized for straightforward token operations where the complexity
  of pre-claim operations and gas stipends is unnecessary, providing significant gas savings
  for simple same-chain settlements.

**Notes:**

- access: Only callable by Router via SameChainAdapter (enforced by onlyRouter modifier).

- efficiency: More gas-efficient than Compact due to simplified validation and unlock process.

- security: TRUSTED EXECUTION: Target operations execute without signature validation due to
  SameChainArbiter's trusted status in IntentExecutor, avoiding redundant validation.

- atomic: Maintains same atomic execution guarantees as Compact despite simplified flow.

- scope: Optimized for simple token operations rather than complex multi-step settlements.B

```solidity
function handlePermit2(Types.Order calldata order, Types.Signatures calldata sigs, address relayer) external onlyRouter;
```

**Parameters**

| Name      | Type               | Description                                                                                                                                         |
| --------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `order`   | `Types.Order`      | Complete order specification including tokens, operations, and metadata. Same structure as Compact but typically with simpler target operations.    |
| `sigs`    | `Types.Signatures` | Container for required signatures, primarily the notarized claim signature. Permit2 typically requires fewer signatures than full Compact protocol. |
| `relayer` | `address`          | Address where input tokens will be deposited after successful unlock. Receives tokens directly from Permit2 unlock without intermediate processing. |

## Events

### SameChainTargetOpsNotHandled

Emitted when target operations are not executed due to recipient/sponsor mismatch or emissary pattern

```solidity
event SameChainTargetOpsNotHandled()
```

## Errors

### OrderExpired

Thrown when an order has expired based on its fillDeadline.

```solidity
error OrderExpired()
```
