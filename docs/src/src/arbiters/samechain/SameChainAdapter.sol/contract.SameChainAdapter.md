# SameChainAdapter

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/arbiters/samechain/SameChainAdapter.sol)

**Inherits:**
[AdapterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/adapter/AdapterBase.sol/abstract.AdapterBase.md), [SameChainArbiter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/arbiters/samechain/SameChainArbiter.sol/contract.SameChainArbiter.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Adapter for handling same-chain order settlement within the Warp Routerr ecosystem.
This contract orchestrates the complete same-chain settlement flow where both order origin
and execution occur on the same blockchain, eliminating cross-chain complexity while maintaining
proper settlement guarantees through pre-funding and coordinated arbiter execution.

SAME-CHAIN SETTLEMENT ARCHITECTURE:
Same-chain orders provide efficiency benefits by avoiding cross-chain coordination overhead.
However, they still require proper settlement to ensure atomic execution and prevent MEV attacks.
The settlement follows this critical 3-step process:

1. **PRE-FUNDING**: Solver pre-funds the recipient with output tokens before claiming input tokens
2. **RESOURCE UNLOCK**: Arbiter validates signatures and unlocks user's input resources
3. **TARGET EXECUTION**: Final operations (swaps, transfers) are executed on behalf of the user

DUAL PROTOCOL SUPPORT:
This adapter supports both Compact and Permit2 protocols with different data requirements:

- **Compact Protocol**: Full featured with pre-claim operations, gas stipends, and allocator data
- **Permit2 Protocol**: Streamlined flow with simplified signature requirements
  Both protocols follow the same core settlement pattern but with protocol-specific validation.

SECURITY MODEL:

- **Access Control**: Only Router can call fill functions (onlyViaRouter modifier)
- **Pre-funding Safety**: Recipients receive output tokens before input tokens are unlocked
- **Atomic Settlement**: If any step fails, the entire transaction reverts
- **Signature Validation**: All user signatures validated by the arbiter before execution
- **Nonce Protection**: Each order has unique nonce to prevent replay attacks

INTEGRATION PATTERNS:

- Inherits from AdapterBase for Router integration and security patterns
- Works exclusively with SameChainArbiter for settlement logic
- Returns function selectors for Router's IERC165 interface detection
- Emits Filled events for off-chain tracking and indexing

**Notes:**

- relayer: The relayer data must be encoded as abi.encodePacked(address(recipient))
  where recipient is the address that should receive the tokenIn payment.
  This address will be passed to the arbiter as the depositor for input tokens.

- security: Pre-funding mechanism prevents order manipulation attacks where malicious actors
  could front-run settlements to claim input tokens without providing outputs.

- gas: Same-chain operations are optimized for lower gas costs compared to cross-chain
  alternatives, with efficient pre-funding and single-transaction settlement.

## Functions

### \_tokenInRecipient

Decodes the tokenIn recipient address from the solver context.

Extracts the solver's designated recipient for input tokens from the Router's solver context.
The solver context is passed through the Router and contains solver-specific configuration
for how input tokens should be handled after settlement. This address will receive the
user's input tokens once the arbiter validates and unlocks them.

**Note:**
security: The solver context is validated by the Router before reaching this adapter,
ensuring the decoded address is from an authorized solver.

```solidity
function _tokenInRecipient() internal pure returns (address tokenInRecipient);
```

**Returns**

| Name               | Type      | Description                                                                                                                                     |
| ------------------ | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `tokenInRecipient` | `address` | The address where input tokens should be sent after arbiter processing. This is typically the solver's address or a solver-controlled contract. |

### constructor

Initializes the SameChainAdapter with Router and Arbiter integration.

Sets up the adapter for same-chain settlement operations within the Router ecosystem.
The adapter works exclusively through delegatecall from the Router and coordinates
with the specified arbiter for settlement validation and execution.

**Note:**
security: The Router address is stored as immutable to prevent malicious redirection.
Only the specified Router can execute adapter functions via delegatecall.

```solidity
constructor(address router, address compact, address arbiter, address addressBook)
    AdapterBase(router, arbiter)
    SemVer(Version.SAMECHAIN_VERSION_MINOR, Version.SAMECHAIN_VERSION_PATCH)
    SameChainArbiter(router, compact, addressBook);
```

**Parameters**

| Name          | Type      | Description                                                                                                                                       |
| ------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `router`      | `address` | The Router contract address that will delegatecall this adapter. Must be a valid Router deployment with same-chain adapter support.               |
| `compact`     | `address` | The Compact protocol contract address for handling Compact-based orders. Used for full-featured same-chain settlements with pre-claim operations. |
| `arbiter`     | `address` | The SameChainArbiter contract address that processes settlement logic.                                                                            |
| `addressBook` | `address` | The address book contract containing protocol addresses and configurations.                                                                       |

### samechain_compact_handleFill

Handles a same-chain order fill using the Compact protocol.

Entry point for Compact-based same-chain settlements called exclusively by the Router.
Implements the complete same-chain settlement flow: pre-funding recipients, then
coordinating with the arbiter to unlock resources and execute target operations.
The Compact protocol provides full-featured order execution including:

- Pre-claim operations (approvals, setup calls)
- Gas stipend allocation for complex operations
- Allocator data for protocol-specific validation
- Multi-signature support for complex authorization flows

**Notes:**

- access: Only callable by Router via delegatecall (enforced by onlyViaRouter modifier).

- flow: Pre-funds recipient → calls arbiter → emits Filled event → returns selector.

- security: All user signatures validated by arbiter before any token movements occur.

```solidity
function samechain_compact_handleFill(FillDataCompact calldata fillData) external payable onlyViaRouter returns (bytes4 selector);
```

**Parameters**

| Name       | Type              | Description                                                                                                                                      |
| ---------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fillData` | `FillDataCompact` | Complete Compact protocol order data including signatures and metadata. Contains all information needed for settlement validation and execution. |

**Returns**

| Name       | Type     | Description                                                                                                                       |
| ---------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `selector` | `bytes4` | This function's selector for Router IERC165 interface compliance. Enables Router to verify adapter capabilities before execution. |

### samechain_permit2_handleFill

Handles a same-chain order fill using the Permit2 protocol.

Entry point for Permit2-based same-chain settlements called exclusively by the Router.
Implements a streamlined settlement flow optimized for simple token operations.
Permit2 protocol provides gas-efficient settlement for straightforward token transfers
and swaps without the overhead of pre-claim operations or complex allocator interactions.
The Permit2 protocol focuses on:

- Simplified signature requirements
- Lower gas costs for basic operations
- Direct token authorization via Permit2 contract
- Streamlined validation and execution flow

**Notes:**

- access: Only callable by Router via delegatecall (enforced by onlyViaRouter modifier).

- flow: Pre-funds recipient → calls arbiter → emits Filled event → returns selector.

- gas: More gas-efficient than Compact protocol for simple token operations.

```solidity
function samechain_permit2_handleFill(FillDataPermit2 calldata fillData) external payable onlyViaRouter returns (bytes4 selector);
```

**Parameters**

| Name       | Type              | Description                                                                                                                                     |
| ---------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `fillData` | `FillDataPermit2` | Permit2 protocol order data with essential signatures and order details. Contains simplified data structure optimized for efficient processing. |

**Returns**

| Name       | Type     | Description                                                                                                                       |
| ---------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `selector` | `bytes4` | This function's selector for Router IERC165 interface compliance. Enables Router to verify adapter capabilities before execution. |

### \_handleCompactFill

Internal implementation of Compact protocol same-chain settlement.

Orchestrates the critical 3-step same-chain settlement process for Compact orders:

1. **PRE-FUNDING PHASE**: Transfers output tokens from solver to recipient before any
   input token claims occur. This prevents manipulation attacks where malicious actors
   could claim input tokens without providing the promised outputs.
2. **ARBITER COORDINATION**: Calls SameChainArbiter with all necessary order data,
   signatures, and metadata. The arbiter validates user signatures, executes pre-claim
   operations, unlocks input resources, and coordinates final target operation execution.
3. **EVENT EMISSION**: Emits Filled event for off-chain tracking and order lifecycle management.

**Notes:**

- security: Pre-funding occurs before any signature validation to ensure atomicity.
  If arbiter validation fails, the entire transaction reverts including pre-funding.

- flow: \_prefundRecipient → SameChainArbiter.handleCompact_NotarizedChain → emit Filled.

```solidity
function _handleCompactFill(FillDataCompact calldata fillData, address tokenInRecipient) internal;
```

**Parameters**

| Name               | Type              | Description                                                                                                                                            |
| ------------------ | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fillData`         | `FillDataCompact` | Complete Compact order data including signatures, allocator data, and gas stipend.                                                                     |
| `tokenInRecipient` | `address`         | Address where input tokens will be sent after arbiter processes the unlock. Typically the solver's address or a solver-controlled withdrawal contract. |

### \_handlePermit2Fill

Internal implementation of Permit2 protocol same-chain settlement.

Orchestrates the streamlined 3-step same-chain settlement process for Permit2 orders:

1. **PRE-FUNDING PHASE**: Transfers output tokens from solver to recipient using the same
   security model as Compact but with simplified token handling for Permit2 efficiency.
2. **ARBITER COORDINATION**: Calls SameChainArbiter.handlePermit2 with essential order data
   and signatures. The arbiter handles Permit2-specific validation, resource unlocking,
   and target operation execution without pre-claim complexity.
3. **EVENT EMISSION**: Emits Filled event for consistent off-chain tracking across protocols.

**Notes:**

- gas: More efficient than Compact due to simplified arbiter interaction and fewer validations.

- flow: \_prefundRecipient → SameChainArbiter.handlePermit2 → emit Filled.

```solidity
function _handlePermit2Fill(FillDataPermit2 calldata fillData, address tokenInRecipient) internal;
```

**Parameters**

| Name               | Type              | Description                                                                                                                                        |
| ------------------ | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fillData`         | `FillDataPermit2` | Permit2 order data with simplified structure focused on essential settlement info.                                                                 |
| `tokenInRecipient` | `address`         | Address where input tokens will be deposited after successful validation. Receives tokens directly from Permit2 unlock without intermediate steps. |

### supportsInterface

Checks if this adapter supports a specific function selector.

Implements IERC165 interface detection for Router compatibility.
The Router uses this function to verify adapter capabilities before
delegating fill operations. This ensures only supported operations
are attempted and provides clear capability discovery for off-chain systems.

**Note:**
interface: Part of IERC165 standard for interface detection and capability discovery.

```solidity
function supportsInterface(bytes4 selector) public pure override(AdapterBase, ArbiterBase) returns (bool supported);
```

**Parameters**

| Name       | Type     | Description                                 |
| ---------- | -------- | ------------------------------------------- |
| `selector` | `bytes4` | The function selector to check for support. |

**Returns**

| Name        | Type   | Description                                                                                                                                                                              |
| ----------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `supported` | `bool` | True if the selector is supported by this adapter. Returns true for both Compact and Permit2 same-chain fill functions, plus any selectors supported by the parent AdapterBase contract. |

## Structs

### FillDataCompact

Data structure for Compact protocol same-chain order fills.

Contains all necessary data for processing a Compact-based same-chain settlement.
The Compact protocol provides full-featured order execution with pre-claim operations,
gas stipends, and complex allocator interactions.

```solidity
struct FillDataCompact {
    Types.Order order;
    Types.Signatures userSigs;
    bytes32[] otherElements;
    bytes allocatorData;
}
```

**Properties**

| Name            | Type               | Description                                                                                                                                                                  |
| --------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `order`         | `Types.Order`      | The complete order specification including tokens, operations, and metadata. Contains sponsor, recipient, nonce, deadlines, token amounts, and target operations.            |
| `userSigs`      | `Types.Signatures` | Container for all required signatures (notarized claim sig and optional pre-claim sig). Signatures are validated by the arbiter to ensure user authorization.                |
| `otherElements` | `bytes32[]`        | Array of hashes for multi-element orders (empty for single-element same-chain orders). Used in complex multi-chain scenarios but typically empty for same-chain settlements. |
| `allocatorData` | `bytes`            | Protocol-specific data for the Compact allocator contract. Contains parameters needed for resource allocation and validation.                                                |

### FillDataPermit2

Data structure for Permit2 protocol same-chain order fills.

Simplified data structure for Permit2-based same-chain settlements.
Permit2 protocol provides a streamlined flow without the complexity of
pre-claim operations or gas stipends, making it more gas-efficient
for simple token transfers and swaps.

```solidity
struct FillDataPermit2 {
    Types.Order order;
    Types.Signatures userSigs;
}
```

**Properties**

| Name       | Type               | Description                                                                                                                                          |
| ---------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `order`    | `Types.Order`      | The complete order specification including tokens, operations, and metadata. Same structure as Compact but typically with simpler target operations. |
| `userSigs` | `Types.Signatures` | Container for required signatures, primarily the notarized claim signature. Permit2 typically requires fewer signatures than full Compact protocol.  |
