# CompactArbiter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/arbiter/CompactArbiter/CompactArbiter.sol)

Abstract base contract providing TheCompact protocol integration for cross-chain resource unlocking

This contract serves as the core integration layer with TheCompact's resource locking system,
enabling arbiters to unlock tokens and assets that were previously locked on origin chains.
TheCompact is a protocol for cross-chain resource management where users can lock resources
on one chain and later unlock them on another chain through cryptographic proofs and signatures.
This arbiter handles the complex claim operations required to unlock these resources.
Key TheCompact integration capabilities:
- Multichain claims: Unlocking resources when the current chain is the notarized chain
- Exogenous claims: Unlocking resources when operating on a non-notarized chain
- Batch operations: Efficient processing of multiple token unlocks in single transaction
- Signature validation: EIP-712 compliant mandate verification for secure unlocking
- Cross-chain coordination: Managing state transitions across multiple blockchain networks
The contract abstracts away the complexity of TheCompact's claim operations while providing
standardized interfaces for settlement-specific arbiters to leverage resource unlocking.
Security considerations:
- All claim operations include sponsor validation to prevent unauthorized unlocking
- Mandate hashes ensure cryptographic integrity of cross-chain operations
- Failed claims revert transactions to maintain atomic settlement guarantees
Gas optimization notes:
- Single vs batch claim operations are automatically selected based on token count
- Immutable interface storage minimizes gas costs for repeated operations

**Note:**
security: Cross-chain resource unlocking requires careful validation of all claim parameters


## State Variables
### CLAIM
TheCompact claims contract interface for unlocking locked resources

This is the core interface to TheCompact protocol for resource management


```solidity
ITheCompactClaims internal immutable CLAIM
```


### STRING_MANDATE_STRIPPED
EIP-712 typestring for mandate verification in TheCompact claims

This is the witness typestring used by TheCompact for validating cross-chain mandates.
The string defines the structure of the mandate data that gets hashed and signed.
Format includes Target, Operation arrays, and Token definitions for type safety.
The "stripped" version excludes the leading "Mandate mandate)" portion as required by TheCompact.


```solidity
string internal constant STRING_MANDATE_STRIPPED =
// solhint-disable-next-line max-line-length
"Target target,uint8 v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes data)Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount"
```


## Functions
### constructor

Initializes the CompactArbiter with TheCompact protocol integration

Sets up the immutable interface to TheCompact's claims contract, which handles
all resource unlocking operations. This interface is used for both multichain
and exogenous claim operations across different settlement scenarios.

**Note:**
security: The compact address cannot be changed after deployment, ensure correct address


```solidity
constructor(address compact) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`compact`|`address`|The address of TheCompact claims contract that manages resource locks and unlocks Must be a valid ITheCompactClaims implementation for the target network|


### requireOtherChain

Validates that an order is for cross-chain settlement

Ensures the order doesn't have target operations (which would indicate same-chain execution)
and that the notarized chain ID differs from the current chain


```solidity
modifier requireOtherChain(Types.Order calldata order, uint256 notarizedChainId) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`Types.Order`|The order being validated|
|`notarizedChainId`|`uint256`|The chain ID where the order was originally notarized|


### _unlockNotarizedChain

Unlocks resources from TheCompact for orders originating from the notarized chain

Handles the case where resources were locked on the chain where the order was notarized,
and now need to be unlocked for cross-chain settlement. Uses batchMultichainClaim for
standard cross-chain resource unlocking.


```solidity
function _unlockNotarizedChain(
    Types.Order calldata order,
    bytes32[] calldata otherElements,
    bytes calldata originChainSig,
    bytes memory allocatorData,
    address depositor,
    bytes32 mandateHash
)
    internal
    returns (bytes32 claimHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`Types.Order`|The order containing token inputs and settlement details|
|`otherElements`|`bytes32[]`|Additional chain elements for multi-chain validation|
|`originChainSig`|`bytes`|The signature from the origin chain authorizing the unlock|
|`allocatorData`|`bytes`|The allocator-specific data for resource allocation|
|`depositor`|`address`|The address that will receive the unlocked tokens|
|`mandateHash`|`bytes32`|The mandate hash for TheCompact validation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The claim hash returned by TheCompact, used for tracking and validation|


### _unlockExogenousChain

Unlocks resources from TheCompact for orders originating from external (non-notarized) chains

Handles the case where resources were locked on a different chain than where the order
was notarized. Uses exogenousBatchClaim for cross-chain resource unlocking where the
current chain is not the notarized chain.


```solidity
function _unlockExogenousChain(
    Types.Order calldata order,
    bytes calldata originChainSig,
    uint256 notarizedChainId,
    uint256 chainIndex,
    bytes32[] calldata otherElements,
    bytes memory allocatorData,
    address depositor,
    bytes32 mandateHash
)
    internal
    returns (bytes32 claimHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`Types.Order`|The order containing token inputs and settlement details|
|`originChainSig`|`bytes`|The signature from the origin chain authorizing the unlock|
|`notarizedChainId`|`uint256`|The chain ID where the order was originally notarized|
|`chainIndex`|`uint256`|The index of the current chain in the cross-chain element array|
|`otherElements`|`bytes32[]`|Additional chain elements for multi-chain validation|
|`allocatorData`|`bytes`|The allocator-specific data for resource allocation|
|`depositor`|`address`|The address that will receive the unlocked tokens|
|`mandateHash`|`bytes32`|The mandate hash for TheCompact validation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The claim hash returned by TheCompact, used for tracking and validation|


## Events
### ProcessedClaim
Emitted when a claim is successfully processed through TheCompact


```solidity
event ProcessedClaim(address indexed sponsor, uint256 indexed nonce, bytes32 indexed claimHash)
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sponsor`|`address`|The address that sponsored the original order|
|`nonce`|`uint256`|The unique identifier of the processed order|
|`claimHash`|`bytes32`|The hash returned by TheCompact claim operations|

## Errors
### ClaimFailed
Thrown when a claim operation to TheCompact fails


```solidity
error ClaimFailed()
```

### InvalidOrderData
Thrown when order data is invalid or malformed


```solidity
error InvalidOrderData()
```

