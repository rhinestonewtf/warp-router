# ICompactIntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/interfaces/ICompactIntent.sol)


## Functions
### executeTargetOpsWithCompactStub

Executes target operations on the destination chain with claim hash verification

This function implements the second phase of cross-chain intent execution. It:
1. Reconstructs the element hash from the provided stub data
2. Validates that execution is happening on the correct target chain
3. Checks that the fill hasn't expired
4. Builds the complete Compact Merkle tree with all elements
5. Computes the final EIP-712 claim hash
6. Verifies the claim hash proof through the designated proofer contract
7. Executes the target operations if all validations pass


```solidity
function executeTargetOpsWithCompactStub(
    address account,
    address notarizedArbiter,
    EIP712CompactStub calldata compactStub,
    EIP712ElementStubDestination calldata elementStub,
    Types.Operation calldata targetOps,
    bytes calldata signature
)
    external
    returns (bytes32 claimHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The recipient account address for the target operations|
|`notarizedArbiter`|`address`|The arbiter address that notarized the cross-chain transfer|
|`compactStub`|`EIP712CompactStub`|Core Compact order data (nonce, expires, notarized chain)|
|`elementStub`|`EIP712ElementStubDestination`|Element-specific data needed for destination chain execution|
|`targetOps`|`Types.Operation`|Array of operations to execute on the destination chain|
|`signature`|`bytes`|EIP-712 signature authorizing the target operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The computed claim hash used for verification|


### executePreClaimOpsWithCompactStub

Executes pre-claim operations on the origin chain before cross-chain transfer

This function implements the first phase of cross-chain intent execution. It:
1. Reconstructs the element hash using the caller as the arbiter
2. Builds the complete Compact Merkle tree with all elements
3. Computes the final EIP-712 claim hash
4. Executes the pre-claim operations after signature validation
5. Sets the signature skip flag for corresponding target operations


```solidity
function executePreClaimOpsWithCompactStub(
    address account,
    EIP712CompactStub calldata compactStub,
    EIP712ElementStubOrigin calldata elementStub,
    Types.Operation calldata preClaimOps,
    bytes calldata signature
)
    external
    returns (bytes32 claimHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The smart account address that owns the assets and signed the order|
|`compactStub`|`EIP712CompactStub`|Core Compact order data (nonce, expires, notarized chain)|
|`elementStub`|`EIP712ElementStubOrigin`|Element-specific data needed for origin chain execution|
|`preClaimOps`|`Types.Operation`|Array of operations to execute before cross-chain transfer (e.g., token approvals)|
|`signature`|`bytes`|EIP-712 signature from the account authorizing these operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The computed claim hash that will be used for target operation verification|


### isCompactIntentNonceConsumed


```solidity
function isCompactIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
```

## Errors
### InvalidParams

```solidity
error InvalidParams()
```

## Structs
### EIP712ElementStubOrigin
Stub data for EIP-712 element construction on origin chain

Used during pre-claim operation execution to reconstruct the full element hash
without requiring all data to be passed as parameters


```solidity
struct EIP712ElementStubOrigin {
    /// @dev Array of other element hashes in the Compact Merkle tree
    bytes32[] otherElements;
    uint128 minGas;
    /// @dev Index position where this element should be inserted in the otherElements array
    uint256 elementOffset;
    /// @dev Hash of target operations that will be executed on destination chain
    bytes32 destOpsHash;
    /// @dev Hash of input token details for this element
    bytes32 tokenInHash;
    /// @dev Pre-computed hash of target attributes (account, tokenOut, chain, expires, proofer)
    bytes32 targetAttributesHash;
    /// @dev Hash of the qualifier data specific to this element
    bytes32 qHash;
}
```

### EIP712ElementStubDestination
Stub data for EIP-712 element construction on destination chain

Used during target operation execution to reconstruct the full element hash
and verify the claim hash proof before execution


```solidity
struct EIP712ElementStubDestination {
    /// @dev Address that sponsored the original Compact order
    address sponsor;
    /// @dev Array of other element hashes in the Compact Merkle tree
    bytes32[] otherElements;
    /// @dev Index position where this element should be inserted in the otherElements array
    uint256 elementOffset;
    /// @dev Hash of pre-claim operations that were executed on origin chain
    bytes32 preClaimOpsHash;
    /// @dev Hash of input token details for this element
    bytes32 tokenInHash;
    /// @dev Hash of output token details for this element
    bytes32 tokenOutHash;
    /// @dev Timestamp after which the fill operation expires
    uint256 fillExpires;
    /// @dev Chain ID where target operations should be executed
    uint256 targetChain;
    /// @dev Hash of the qualifier data specific to this element
    bytes32 qHash;
}
```

### EIP712CompactStub
Core Compact order data that remains consistent across all elements

Contains the essential order metadata that's used in EIP-712 hash construction
for both pre-claim and target operations


```solidity
struct EIP712CompactStub {
    /// @dev Unique nonce for this Compact order to prevent replay attacks
    uint256 nonce;
    /// @dev Timestamp after which the entire Compact order expires
    uint256 expires;
    /// @dev Chain ID where the order was originally notarized/signed
    uint256 notarizedChainId;
}
```

