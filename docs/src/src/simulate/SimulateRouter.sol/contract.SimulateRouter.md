# SimulateRouter

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/simulate/SimulateRouter.sol)

**Inherits:**
[RouterLogic](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/RouterLogic.sol/contract.RouterLogic.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

A specialized router for simulating and measuring the gas costs of various routing operations.
This contract inherits the core logic from `RouterLogic` but wraps key functions
in a `withGasMeasurement` modifier. Instead of completing the state change, it reverts
with a `GasUsed` error, reporting the amount of gas consumed. This is invaluable for
off-chain systems to estimate transaction costs accurately.

## Functions

### constructor

Initializes the SimulateRouter.

```solidity
constructor(address atomicFillSigner, address adder, address remover) RouterLogic(atomicFillSigner, adder, remover);
```

**Parameters**

| Name               | Type      | Description                                      |
| ------------------ | --------- | ------------------------------------------------ |
| `atomicFillSigner` | `address` | The address authorized to sign for atomic fills. |
| `adder`            | `address` | The address granted the role to add routes.      |
| `remover`          | `address` | The address granted the role to remove routes.   |

### withGasMeasurement

A modifier that measures the gas consumed by the function it wraps.

It records `gasleft()` before and after the function execution (`_`),
calculates the difference, and then reverts with the `GasUsed` error to
report the cost.

```solidity
modifier withGasMeasurement() ;
```

### \_isAtomic

Override of \_isAtomic that bypasses signature validation for gas simulation purposes

This override is specifically designed for the simulation environment where we need to
measure gas costs without requiring valid atomic signatures. The function still calls
the parent implementation to ensure any side effects or gas costs from the original
validation logic are included in the simulation, but then unconditionally returns true.
This design allows for accurate gas measurement of the complete routing flow while
removing the signature validation requirement that would otherwise prevent simulation
without access to the atomic signer's private key.
Why this override is safe for simulation\*\*:

- SimulateRouter is used exclusively for gas estimation via the withGasMeasurement modifier
- All simulation functions revert with GasUsed error, preventing state changes
- No actual asset transfers or protocol state modifications occur during simulation
- The parent call ensures gas costs of signature verification are still measured

**Notes:**

- security: This override is safe because:
- Only used in simulation context where all operations revert via withGasMeasurement
- No state changes are persisted due to the GasUsed revert pattern
- Cannot be used to bypass security in production Router contracts
- Parent call preserves gas measurement accuracy for the validation logic

- gas: The parent call ensures simulation includes:
- Storage read costs for $atomicFillSigner
- ECDSA signature recovery computation costs
- All other gas overhead from the original validation logic
  This provides accurate gas estimates for production routing calls.

```solidity
function _isAtomic(bytes32 hash, bytes calldata atomicSig) internal override returns (bool atomic);
```

**Parameters**

| Name        | Type      | Description                                                                                                                                                                 |
| ----------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hash`      | `bytes32` | The keccak256 hash of the encoded adapter calldatas. While not used for validation in this override, it's still passed to the parent function for gas measurement accuracy. |
| `atomicSig` | `bytes`   | The ECDSA signature bytes. Not validated in simulation, but passed to parent to ensure the complete gas cost profile is captured.                                           |

**Returns**

| Name     | Type   | Description                                                                                                                                                             |
| -------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `atomic` | `bool` | Always returns true to allow simulation to proceed without signature validation. This enables gas measurement of routing operations without requiring valid signatures. |

### simulate_routeFill

Simulates the gas cost of a `routeFill` operation.

This function wraps the `routeFill` logic with the `withGasMeasurement` modifier
to report the gas cost via a revert.

```solidity
function simulate_routeFill(bytes[] calldata relayerContexts, bytes calldata encodedAdapterCalldatas, bytes calldata sig)
    external
    virtual
    withGasMeasurement;
```

**Parameters**

| Name                      | Type      | Description                                                    |
| ------------------------- | --------- | -------------------------------------------------------------- |
| `relayerContexts`         | `bytes[]` | An array of solver-specific contexts for each adapter call.    |
| `encodedAdapterCalldatas` | `bytes`   | An abi encoded array of calldata for each adapter call.        |
| `sig`                     | `bytes`   | The atomic fill signature authorizing the batch of operations. |

### simulate_routeClaim

Simulates the gas cost of a `routeClaim` operation.

This function wraps the `routeClaim` logic with the `withGasMeasurement` modifier
to report the gas cost via a revert.

```solidity
function simulate_routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) external withGasMeasurement;
```

**Parameters**

| Name              | Type    | Description                                |
| ----------------- | ------- | ------------------------------------------ |
| `relayerContext`  | `bytes` | The solver-specific context for the claim. |
| `adapterCalldata` | `bytes` | The calldata for the claim adapter.        |

## Errors

### GasUsed

Custom error to report the gas used by a simulated transaction.

This error is intentionally reverted by the `withGasMeasurement` modifier to return
the gas cost without making a state change.

```solidity
error GasUsed(bool success, uint256 gasUsed)
```

**Parameters**

| Name      | Type      | Description                                                   |
| --------- | --------- | ------------------------------------------------------------- |
| `success` | `bool`    | Always true, indicating the simulation itself was successful. |
| `gasUsed` | `uint256` | The amount of gas consumed by the wrapped operation.          |
