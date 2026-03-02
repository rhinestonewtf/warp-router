# ValidateSignature
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/VerifySignature/VerifySignature.sol)

Abstract contract that provides signature validation capabilities using multiple modes

This contract supports various signature validation strategies including:
- Pure ERC-1271 validation for smart contract wallets
- Emissary-based validation for session keys and delegation patterns
- Hybrid modes that attempt multiple validation methods with fallback logic
The contract integrates with TheCompact protocol to lookup authorized emissaries
for a given account and lock tag, enabling complex delegation and session key patterns.
Security considerations:
- Emissary validation requires the emissary to be authorized via TheCompact
- ERC-1271 validation relies on the account's own signature validation logic
- Fallback modes provide flexibility but should be used carefully to avoid bypassing intended restrictions


## State Variables
### COMPACT
The Compact contract for getting emissary status


```solidity
ITheCompact private immutable COMPACT
```


## Functions
### constructor

Initializes the execution signature checker with TheCompact


```solidity
constructor(address compact) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`compact`|`address`|The Compact contract address for getting emissary status|


### _isValidSignature

Validates a signature using the specified validation mode

This is the main signature validation function that dispatches to different
validation strategies based on the sigMode parameter. The function supports
both pure modes (single validation method) and hybrid modes (with fallback logic).
Pure modes:
- ERC1271: Only validates using the account's ERC-1271 implementation
- EMISSARY: Only validates using emissary's verifyClaim method
- EMISSARYEXECUTION: Only validates using emissary's verifyExecution method
Hybrid modes with fallback:
- EMISSARY_ERC1271: Try emissary validation first, fallback to ERC-1271
- ERC1271_EMISSARY: Try ERC-1271 first, fallback to emissary validation
- EMISSARYEXECUTION_ERC1271: Try emissary execution validation first, fallback to ERC-1271
- ERC1271_EMISSARYEXECUTION: Try ERC-1271 first, fallback to emissary execution validation

**Note:**
security: Each validation mode has different security properties:
- ERC-1271 relies on the account's own validation logic
- Emissary modes require the emissary to be authorized in TheCompact
- Fallback modes may allow validation even if the primary method fails


```solidity
function _isValidSignature(
    address account,
    SmartExecutionLib.SigMode sigMode,
    bytes12 lockTag,
    bytes32 digest,
    bytes32 claimHash,
    bytes calldata signature,
    Execution[] calldata executions
)
    internal
    returns (bool validSig);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account address that should authorize this signature|
|`sigMode`|`SmartExecutionLib.SigMode`|The validation mode determining which methods to try and in what order|
|`lockTag`|`bytes12`|The lock identifier used for emissary lookups in TheCompact|
|`digest`|`bytes32`|The EIP-712 digest of the data being signed (used for emissary validation)|
|`claimHash`|`bytes32`|The hash of the claim being validated (used for ERC-1271 validation)|
|`signature`|`bytes`|The signature data to validate|
|`executions`|`Execution[]`|The execution operations (only used for EMISSARYEXECUTION modes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validSig`|`bool`|True if the signature is valid according to the specified mode|


### _verifyExecutionWithEmissary

Validates a signature using an emissary's execution-aware verification

This method provides the most comprehensive validation by giving the emissary
full context about both the signature and the operations being executed.
The emissary can enforce fine-grained policies such as:
- Restricting which contracts can be called
- Limiting transaction values or gas usage
- Enforcing time-based restrictions
- Validating complex business logic
The verification process:
1. Looks up the authorized emissary for the account/lockTag pair in TheCompact
2. Calls the emissary's verifyExecution method with full execution context
3. Validates that the emissary returns the correct selector (indicating approval)

**Notes:**
- security: The emissary must be authorized in TheCompact for the given account/lockTag.
If no emissary is found, validation fails immediately for security.

- gas: This method may be more gas-intensive than simple signature validation
as it allows the emissary to perform complex validation logic.


```solidity
function _verifyExecutionWithEmissary(
    address account,
    bytes12 lockTag,
    bytes32 digest,
    bytes calldata signature,
    Execution[] calldata executions
)
    private
    returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account address that authorized the emissary|
|`lockTag`|`bytes12`|The lock identifier used to lookup the emissary in TheCompact|
|`digest`|`bytes32`|The EIP-712 digest of the data being signed|
|`signature`|`bytes`|The signature data (format depends on emissary implementation)|
|`executions`|`Execution[]`|Array of operations to be executed - emissary can validate each one|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if the emissary approves both the signature and execution context|


### _verifyWithERC1271

Validates a signature using the ERC-1271 standard

This method delegates signature validation to the account's own isValidSignature
implementation. This is the standard way to validate signatures for smart contract
wallets and accounts that implement custom signature logic.
The validation is performed using Solady's SignatureCheckerLib which:
- First checks if the account is a contract
- If it's a contract, calls the ERC-1271 isValidSignature method
- If it's an EOA, performs ECDSA signature recovery and comparison
- Handles various signature formats and edge cases

**Notes:**
- security: This method trusts the account's own signature validation logic.
Malicious contracts could return true for invalid signatures.

- gas: Uses Solady's optimized implementation for efficient validation.


```solidity
function _verifyWithERC1271(address account, bytes32 digest, bytes calldata signature) private view returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account address whose signature should be validated|
|`digest`|`bytes32`|The hash that was signed (typically a claim hash or message hash)|
|`signature`|`bytes`|The signature bytes to validate against the hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if the signature is valid according to ERC-1271 or ECDSA verification|


### _verifyClaimWithEmissary

Validates a signature using an emissary's claim verification method

This method is used for session key validation where the emissary acts as
a delegated signer for specific claims. Unlike verifyExecution, this method
only validates the signature against a claim hash, without considering the
execution context. This is suitable for:
- Simple session key authorization
- Delegation patterns where execution validation is handled elsewhere
- Claims that don't require execution-specific validation
The verification process:
1. Looks up the authorized emissary for the account/lockTag pair
2. Calls the emissary's verifyClaim method with claim context
3. Validates that the emissary returns the correct selector

**Note:**
security: The emissary must be authorized in TheCompact. No fallback validation
is performed if the emissary is not found.


```solidity
function _verifyClaimWithEmissary(address expectedSigner, bytes12 lockTag, bytes32 digest, bytes32 claimHash, bytes calldata signature)
    private
    view
    returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expectedSigner`|`address`|The account address that should have authorized this claim|
|`lockTag`|`bytes12`|The lock identifier used to lookup the emissary in TheCompact|
|`digest`|`bytes32`|The EIP-712 digest of the original signed data|
|`claimHash`|`bytes32`|The hash of the specific claim being validated|
|`signature`|`bytes`|The signature data (format depends on emissary implementation)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if the emissary validates the claim signature|


## Errors
### InvalidSignature
Thrown when signature verification fails


```solidity
error InvalidSignature()
```

