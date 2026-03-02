# Permit2IntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/Permit2Intent/Permit2Executor.sol)

**Inherits:**
[IPermit2IntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/IPermit2Intent.sol/interface.IPermit2IntentExecutor.md), [IntentExecutorBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/IntentExecutorBase.sol/abstract.IntentExecutorBase.md), [ValidateSignature](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/VerifySignature/VerifySignature.sol/abstract.ValidateSignature.md), [Permit2EIP712](/Users/ops/work/rhinestone/compact-utils/docs/src/src/common/Permit2EIP712.sol/abstract.Permit2EIP712.md)

Executor contract for intents using Permit2 for gasless token approvals

This contract enables intent execution leveraging Uniswap's Permit2 system for efficient
token permission management. Key features include:
- Gasless token approvals using EIP-712 structured signatures
- Nonce-based replay protection with efficient storage patterns
- Integration with signature skip functionality for trusted execution
- EIP-1271 signature validation for smart contract accounts
The execution flow:
1. User signs a Permit2-compatible intent with token permissions and operations
2. Arbiter calls executePreClaimOpsWithPermit2Stub to execute pre-claim operations
3. Contract validates the signature against Permit2's domain separator
4. Nonce is consumed to prevent replay attacks
5. Pre-claim operations are executed (e.g., token transfers, swaps)
6. Signature skip permission is granted to the arbiter for subsequent operations

**Note:**
security: Critical security considerations:
- Permit2 domain separator validation prevents cross-protocol signature reuse
- Nonce consumption provides replay protection at the account level
- EIP-1271 validation supports both EOA and smart contract signatures
- Expiration timestamps prevent execution of stale intents


## Functions
### executePreClaimOpsWithPermit2Stub

Executes pre-claim operations using Permit2-based authorization

This function validates a Permit2-style EIP-712 signature and executes operations
on behalf of the user account. The process includes:
1. Nonce consumption to prevent replay attacks
2. Permit2 hash computation including all operation parameters
3. EIP-712 signature validation using Permit2's domain separator
4. Execution of pre-claim operations (typically token transfers or approvals)
5. Granting signature skip permission to the caller for subsequent operations
Gas optimization: Uses cached domain separator to avoid external calls

**Note:**
security: The signature validation uses EIP-1271 which supports both EOA signatures
and smart contract signature validation for maximum compatibility


```solidity
function executePreClaimOpsWithPermit2Stub(
    address account,
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateStub calldata mandateStub,
    Types.Operation calldata preClaimOps,
    bytes calldata signature
)
    external
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The user account that signed the intent and will execute operations|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration|
|`mandateStub`|`EIP712Permit2MandateStub`|Mandate-specific parameters including token and operation hashes|
|`preClaimOps`|`Types.Operation`|Array of operations to execute on the origin chain|
|`signature`|`bytes`|EIP-712 signature from the account authorizing the operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed Permit2 hash used for signature validation|


### executeTargetOpsWithPermit2Stub

Executes target operations using Permit2-based authorization

This function validates a Permit2-style EIP-712 signature and executes operations
on the destination chain. The process includes:
1. Chain validation to ensure execution on the correct target chain
2. Nonce consumption to prevent replay attacks
3. Permit2 hash computation including all operation parameters
4. EIP-712 signature validation using Permit2's domain separator
5. Execution of target operations (e.g., final asset transfers or swaps)
Gas optimization: Uses cached domain separator to avoid external calls

**Note:**
security: The signature validation uses EIP-1271 which supports both EOA signatures
and smart contract signature validation for maximum compatibility


```solidity
function executeTargetOpsWithPermit2Stub(
    address account,
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateDestinationStub calldata mandateStub,
    Types.Operation calldata targetOps,
    bytes calldata signature
)
    external
    onlyRouter
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The user account that signed the intent and will execute operations|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration|
|`mandateStub`|`EIP712Permit2MandateDestinationStub`|Mandate-specific parameters including token and operation hashes|
|`targetOps`|`Types.Operation`|Array of operations to execute on the destination chain|
|`signature`|`bytes`|EIP-712 signature from the account authorizing the operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed Permit2 hash used for signature validation|


### _permit2Hash

Internal function to compute the Permit2 hash for signature validation

Constructs the complete Permit2 hash by combining mandate parameters with
Permit2-specific fields. The hash computation follows this structure:
1. Compute mandate hash from target attributes, operation hashes, and q parameters
2. Combine mandate hash with Permit2 fields (token, arbiter, nonce, expiration)
3. Return the final hash for EIP-712 signature validation
The arbiter is set to msg.sender, establishing the caller as the authorized
party for executing this intent.


```solidity
function _permit2Hash(
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateStub calldata mandateStub,
    Types.Operation calldata preClaimOps
)
    internal
    view
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration time|
|`mandateStub`|`EIP712Permit2MandateStub`|Mandate-specific parameters including token and operation hashes|
|`preClaimOps`|`Types.Operation`|Operations to execute - hashed as part of the mandate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed hash for Permit2 signature validation|


### _permit2Hash

Internal function to compute the Permit2 hash for target operations

Constructs the complete Permit2 hash by combining mandate parameters with
Permit2-specific fields. The hash computation follows this structure:
1. Compute mandate hash from target attributes, operation hashes, and q parameters
2. Combine mandate hash with Permit2 fields (token, arbiter, nonce, expiration)
3. Return the final hash for EIP-712 signature validation
The arbiter is set to mandateStub.arbiter, establishing the designated arbiter
as the authorized party for executing this intent.


```solidity
function _permit2Hash(
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateDestinationStub calldata mandateStub,
    Types.Operation calldata targetOps
)
    internal
    pure
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration time|
|`mandateStub`|`EIP712Permit2MandateDestinationStub`|Mandate-specific parameters including token and operation hashes|
|`targetOps`|`Types.Operation`|Operations to execute - hashed as part of the mandate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed hash for Permit2 signature validation|


### isPermit2IntentNonceConsumed

Checks if a nonce has been used for a specific account

This function provides a clean way to check nonce usage without relying on low-level storage access


```solidity
function isPermit2IntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
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


