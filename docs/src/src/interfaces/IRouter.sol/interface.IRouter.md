# IRouter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IRouter.sol)

Interface for the Warp Routerr contract

This interface defines all external functions and errors for the RouterLogic contract


## Functions
### optimized_routeFill921336808

Gas-optimized version of routeFill with enhanced batching and caching mechanisms


```solidity
function optimized_routeFill921336808(
    bytes[] calldata relayerContexts,
    bytes calldata encodedAdapterCalldatas,
    bytes calldata atomicFillSignature
)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayerContexts`|`bytes[]`|Array of solver-specific contexts, consumed only by regular adapter calls|
|`encodedAdapterCalldatas`|`bytes`|ABI-encoded bytes containing the array of adapter calldatas|
|`atomicFillSignature`|`bytes`|Signature from atomicFillSigner authorizing this batch execution|


### routeClaim

Routes multiple claim operations to their adapters


```solidity
function routeClaim(bytes[] calldata relayerContexts, bytes[] calldata adapterCalldatas) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayerContexts`|`bytes[]`|Array of solver-specific context for these operations|
|`adapterCalldatas`|`bytes[]`|Array of calldata for the adapters|


### routeClaim

Routes a single claim operation to its adapter


```solidity
function routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayerContext`|`bytes`|The solver-specific context for this operation|
|`adapterCalldata`|`bytes`|The calldata for the adapter|


## Errors
### InvalidAccountAddress
Thrown when the provided account address is the zero address


```solidity
error InvalidAccountAddress()
```

### AccountCreationFailed
Thrown if account creation fails


```solidity
error AccountCreationFailed()
```

### Paused
Thrown when the contract is paused


```solidity
error Paused()
```

### LengthMismatch
Thrown when input arrays have mismatched lengths


```solidity
error LengthMismatch()
```

### InvalidAtomicity
Thrown when an atomic operation fails signature validation


```solidity
error InvalidAtomicity()
```

### AtomicSignerNotSet
Thrown when atomic signer isn't set


```solidity
error AtomicSignerNotSet()
```

### AdapterCallFailed
Thrown when an adapter call fails


```solidity
error AdapterCallFailed()
```

