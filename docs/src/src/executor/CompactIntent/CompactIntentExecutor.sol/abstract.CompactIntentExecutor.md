# CompactIntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/CompactIntent/CompactIntentExecutor.sol)

**Inherits:**
[ICompactIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/ICompactIntent.sol/interface.ICompactIntentExecutor.md), [CompactEIP712](/Users/ops/work/rhinestone/compact-utils/docs/src/src/types/EIP712.sol/library.CompactEIP712.md), [IntentExecutorBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/IntentExecutorBase.sol/abstract.IntentExecutorBase.md), [ValidateSignature](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/VerifySignature/VerifySignature.sol/abstract.ValidateSignature.md)

Executor contract for cross-chain intents using The Compact protocol

This contract enables secure cross-chain intent execution through a two-phase process:
Phase 1 (Origin Chain): executePreClaimOpsWithCompactStub
- User signs an EIP-712 structured intent specifying cross-chain operations
- Arbiter calls this function to execute pre-claim operations (e.g., token approvals)
- Contract validates signature and computes claim hash for cross-chain verification
- Sets signature skip permission for the arbiter to execute target operations
Phase 2 (Destination Chain): executeTargetOpsWithCompactStub
- Arbiter provides proof of origin chain execution via claim hash
- Contract validates the claim hash through The Compact protocol's verification system
- If valid, executes the target operations on behalf of the user

**Note:**
security: The security model relies on:
- EIP-712 signatures for user authorization
- The Compact protocol's cross-chain verification system
- Router-only access control for cross-chain operations
- Expiration timestamps to prevent stale execution


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
    onlyRouter
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


### _compactClaimHash

Internal function to compute the claim hash for destination chain execution

This function reconstructs the complete claim hash that was originally computed during
pre-claim operations on the origin chain. The hash must match exactly to validate
that the cross-chain intent execution is legitimate. The process involves:
1. Computing the element hash from all individual components
2. Building the complete Compact Merkle tree structure
3. Computing the final EIP-712 claim hash
Critical: All hash components must match the original computation exactly


```solidity
function _compactClaimHash(
    address account,
    address notarizedArbiter,
    EIP712CompactStub calldata compactStub,
    EIP712ElementStubDestination calldata elementStub,
    Execution[] calldata targetOps,
    SmartExecutionLib.SigMode sigMode
)
    internal
    pure
    returns (bytes32 claimHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The recipient account address for the target operations|
|`notarizedArbiter`|`address`|The arbiter address that facilitated the cross-chain transfer|
|`compactStub`|`EIP712CompactStub`|Core Compact order data from the origin chain|
|`elementStub`|`EIP712ElementStubDestination`|Element-specific data needed for hash reconstruction|
|`targetOps`|`Execution[]`|The operations to execute on this destination chain|
|`sigMode`|`SmartExecutionLib.SigMode`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The computed claim hash for verification|


### isCompactIntentNonceConsumed

Checks if a nonce has been used for a specific account

This function provides a clean way to check nonce usage without relying on low-level storage access


```solidity
function isCompactIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce value to check|
|`account`|`address`|The account address that owns the nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`used`|`bool`|True if the nonce has been consumed, false otherwise|


