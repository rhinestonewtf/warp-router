# ArbiterBase

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/arbiter/ArbiterBase.sol)

**Inherits:**
[CompactArbiter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/arbiter/CompactArbiter/CompactArbiter.sol/abstract.CompactArbiter.md), [Permit2Arbiter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/arbiter/Permit2Arbiter/Permit2Arbiter.sol/abstract.Permit2Arbiter.md), [PreClaimExecution](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/arbiter/lib/PreClaimExecution.sol/abstract.PreClaimExecution.md), [IArbiter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/IArbiter.sol/interface.IArbiter.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Base arbiter contract that enables unlocking funds from user accounts or resource locks

This contract serves as a critical component in the Warp Routerr ecosystem, acting as
an arbiter that can unlock and manage funds on behalf of users. It provides dual protocol
support for both TheCompact and Permit2 standards, enabling flexible settlement mechanisms.
Key responsibilities:

- Executes pre-claim operations before settlement
- Computes mandate hashes for protocol validation
- Maintains Router-only access control for security
- Orchestrates the settlement flow for both Compact and Permit2 protocols
  Security model: Only the Router can call settlement functions, preventing unauthorized
  access to user funds and ensuring proper validation of all operations.

## State Variables

### ROUTER

The Router address that has exclusive access to settlement functions

```solidity
address internal immutable ROUTER
```

## Functions

### constructor

Initializes the ArbiterBase with protocol addresses and access control

Sets up the inheritance chain for Compact, Permit2, and PreClaim functionality.
The router address is stored as immutable for gas efficiency and security.

```solidity
constructor(address router, address compact, address addressBook)
    CompactArbiter(compact)
    Permit2Arbiter(address(Constants.PERMIT2))
    PreClaimExecution(addressBook);
```

**Parameters**

| Name          | Type      | Description                                                                         |
| ------------- | --------- | ----------------------------------------------------------------------------------- |
| `router`      | `address` | The Router contract address that will have exclusive access to settlement functions |
| `compact`     | `address` | The TheCompact protocol contract address for Compact-based settlements              |
| `addressBook` | `address` | The addressbook for lookup                                                          |

### \_compactPreClaimOps

Handles pre-claim operations and computes the mandate hash for TheCompact integration

This function orchestrates the pre-settlement validation and execution flow:

1. Computes various EIP-712 hashes for order components
2. Executes pre-claim operations if they exist and are ERC7579 type
3. Returns the mandate hash needed for TheCompact claims

```solidity
function _compactPreClaimOps(
    Types.Order calldata order,
    Types.Signatures calldata sigs,
    bytes32[] calldata otherElements,
    uint256 elementOffset,
    uint256 notarizedChainId
)
    internal
    returns (bytes32 mandateHash);
```

**Parameters**

| Name               | Type               | Description                                    |
| ------------------ | ------------------ | ---------------------------------------------- |
| `order`            | `Types.Order`      | The order containing all settlement data       |
| `sigs`             | `Types.Signatures` | The signatures required for validation         |
| `otherElements`    | `bytes32[]`        | Additional elements for cross-chain validation |
| `elementOffset`    | `uint256`          | The offset for element processing              |
| `notarizedChainId` | `uint256`          | The chain ID where the order was notarized     |

**Returns**

| Name          | Type      | Description                                               |
| ------------- | --------- | --------------------------------------------------------- |
| `mandateHash` | `bytes32` | The computed mandate hash for TheCompact claim operations |

### \_permit2PreClaimOps

Handles pre-claim operations and computes the mandate hash for Permit2 integration

This function orchestrates the pre-settlement validation and execution flow for Permit2:

1. Computes EIP-712 hashes for all order components (target attributes, operations, qualifier)
2. Executes pre-claim operations if they exist and are ERC7579 type
3. Returns the mandate hash needed for Permit2 claims
   Unlike Compact integration, Permit2 uses a different stub structure and execution path
   but maintains the same core validation and mandate hash computation logic.

**Notes:**

- security: Pre-claim operations are executed with proper signature validation through Permit2 stub

- gas: Operations are only executed if preClaimOpsHash != NO_EXEC to avoid unnecessary gas costs

```solidity
function _permit2PreClaimOps(Types.Order calldata order, Types.Signatures calldata sigs) internal returns (bytes32 mandateHash);
```

**Parameters**

| Name    | Type               | Description                                                                             |
| ------- | ------------------ | --------------------------------------------------------------------------------------- |
| `order` | `Types.Order`      | The order containing all settlement data including sponsor, operations, and tokens      |
| `sigs`  | `Types.Signatures` | The signatures required for validation, specifically uses notarizedClaimSig for Permit2 |

**Returns**

| Name          | Type      | Description                                                               |
| ------------- | --------- | ------------------------------------------------------------------------- |
| `mandateHash` | `bytes32` | The computed mandate hash that Permit2 will use for settlement validation |

### onlyRouter

Restricts function access to only the authorized Router contract

This modifier is critical for maintaining the security model of the arbiter system.
It ensures that only the Router can execute settlement operations, preventing:

- Unauthorized access to user funds
- Bypass of Router's validation logic
- Direct manipulation of arbiter state

**Note:**
security: This is the primary access control mechanism for all settlement functions

```solidity
modifier onlyRouter() ;
```

### \_onlyRouter

Internal function to validate Router-only access

Ensures that settlement operations maintain proper access control within the Router ecosystem

```solidity
function _onlyRouter() internal virtual;
```

### supportsInterface

```solidity
function supportsInterface(bytes4 selector) public pure virtual returns (bool);
```

## Errors

### OnlyRouter

Thrown when a function is called by an address other than the authorized Router

This error enforces the critical security boundary that prevents unauthorized entities
from executing settlement operations or accessing user funds through the arbiter

```solidity
error OnlyRouter()
```
