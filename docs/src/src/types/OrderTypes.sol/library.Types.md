# Types

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/types/OrderTypes.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

A library defining the core data structures used throughout the Compact protocol for orders and executions.

## Functions

### splitGasStipend

```solidity
function splitGasStipend(uint256 gasStipend) internal pure returns (uint128 _gasStipend, uint128 minGas);
```

### packGasValues

```solidity
function packGasValues(uint128 gasStipend, uint128 minGas) internal pure returns (uint256 packed);
```

### useNotarizedChainSig

Returns the signature required for the notarized chain claim.

```solidity
function useNotarizedChainSig(Signatures calldata signatures) internal pure returns (bytes calldata sig);
```

**Parameters**

| Name         | Type         | Description                           |
| ------------ | ------------ | ------------------------------------- |
| `signatures` | `Signatures` | The struct containing all signatures. |

**Returns**

| Name  | Type    | Description              |
| ----- | ------- | ------------------------ |
| `sig` | `bytes` | The `notarizedClaimSig`. |

### userPreClaimSig

Returns the signature for the pre-claim operations, with a fallback to the notarized chain signature.

This enables single-signature flows where one signature can authorize multiple steps.

```solidity
function userPreClaimSig(Signatures calldata signatures) internal pure returns (bytes calldata sig);
```

**Parameters**

| Name         | Type         | Description                           |
| ------------ | ------------ | ------------------------------------- |
| `signatures` | `Signatures` | The struct containing all signatures. |

**Returns**

| Name  | Type    | Description                                                  |
| ----- | ------- | ------------------------------------------------------------ |
| `sig` | `bytes` | The `preClaimSig` if present, otherwise `notarizedClaimSig`. |

## Errors

### GasStipendTooLow

Error thrown when the provided gas stipend is less than the minimum required gas.

```solidity
error GasStipendTooLow()
```

## Structs

### Order

The core structure representing a user's intent or order.

```solidity
struct Order {
    address sponsor;
    address recipient;
    uint256 nonce;
    uint256 expires;
    uint256 fillDeadline;
    uint256 notarizedChainId;
    uint256 targetChainId;
    uint256[2][] tokenIn; // aka idsAndAmounts
    uint256[2][] tokenOut;
    uint256 packedGasValues; // Packed gasStipend and minGas values
    Operation preClaimOps; // See SmartExecutionLib
    Operation targetOps; // See SmartExecutionLib
    bytes qualifier; // User qualification (Non-legible EIP712, ends up in `q` param in mandate)
}
```

**Properties**

| Name               | Type           | Description                                                                                   |
| ------------------ | -------------- | --------------------------------------------------------------------------------------------- |
| `sponsor`          | `address`      | The user or smart account initiating the order.                                               |
| `recipient`        | `address`      | The final beneficiary of the output tokens.                                                   |
| `nonce`            | `uint256`      | A unique number to prevent replay attacks, scoped to the sponsor.                             |
| `expires`          | `uint256`      | A timestamp after which the order is no longer valid.                                         |
| `fillDeadline`     | `uint256`      | A timestamp by which the order must be filled by a solver.                                    |
| `notarizedChainId` | `uint256`      | The chain ID where the primary claim and notarization occur.                                  |
| `targetChainId`    | `uint256`      | The chain ID where the final output is delivered.                                             |
| `tokenIn`          | `uint256[2][]` | An array of `[token_address, amount]` pairs for the input assets.                             |
| `tokenOut`         | `uint256[2][]` | An array of `[token_address, amount]` pairs for the output assets.                            |
| `packedGasValues`  | `uint256`      | Packed gasStipend and minGas values (minGas in upper 128 bits, gasStipend in lower 128 bits). |
| `preClaimOps`      | `Operation`    | Encoded operations (e.g., approvals) to be executed before the main claim.                    |
| `targetOps`        | `Operation`    | Encoded operations (e.g., swaps) to be executed on the target chain.                          |
| `qualifier`        | `bytes`        | Chain-specific data used by arbiters for validation.                                          |

### Operation

A generic wrapper for an encoded execution payload.

```solidity
struct Operation {
    bytes data;
}
```

**Properties**

| Name   | Type    | Description                                                      |
| ------ | ------- | ---------------------------------------------------------------- |
| `data` | `bytes` | The raw bytes of the execution payload, see `SmartExecutionLib`. |

### Signatures

A container for the various signatures required during the order lifecycle.

For single-signature flows, `preClaimSig` and `destinationChainSig` can be left empty.
In such cases, the system is designed to fall back and reuse the `notarizedClaimSig`.
Modules and arbiters will override the calldata pointers to use the fallback signature.

```solidity
struct Signatures {
    bytes notarizedClaimSig;
    bytes preClaimSig;
}
```

**Properties**

| Name                | Type    | Description                                                         |
| ------------------- | ------- | ------------------------------------------------------------------- |
| `notarizedClaimSig` | `bytes` | The primary signature for the claim on the notarizing chain.        |
| `preClaimSig`       | `bytes` | Signature for `preClaimOps`. If empty, `notarizedClaimSig` is used. |
