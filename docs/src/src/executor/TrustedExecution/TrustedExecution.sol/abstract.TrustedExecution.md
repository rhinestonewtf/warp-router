# TrustedExecution
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/TrustedExecution/TrustedExecution.sol)

Enables execution of operations without signatures for trusted arbiters

This contract implements a dual-layer trust system for executing operations without
requiring user signatures:
Layer 1 - Whitelisted Arbiters:
- SAMECHAIN_ARBITER: Pre-approved for same-chain operations
- SAMECHAIN_JIT_ARBITER: Pre-approved for just-in-time same-chain operations
- These arbiters can execute operations immediately without additional permissions
Layer 2 - Dynamic Trust (Signature Skip):
- Any address can gain temporary execution permission through signature skip mechanism
- Typically granted after successful execution of signed operations
- Allows follow-up operations without requiring additional signatures
Use cases:
- Multi-step intent execution where initial signature authorizes subsequent operations
- Cross-chain operations where origin chain execution grants permission for destination execution
- Gas-optimized execution flows avoiding repeated signature validations

**Note:**
security: CRITICAL SECURITY CONSIDERATIONS:
- Whitelisted arbiters have permanent execution privileges without user consent
- Signature skip permissions should only be granted after proper user authorization
- Address book integrity is crucial as it defines the trusted arbiters
- No expiration mechanism exists for signature skip permissions


## State Variables
### SAMECHAIN_ARBITER
Address of the pre-approved same-chain arbiter for standard operations


```solidity
address public immutable SAMECHAIN_ARBITER
```


## Functions
### constructor

Initializes the trusted execution system with whitelisted arbiters

Retrieves the trusted arbiter addresses from the address book using predefined
constant identifiers. These addresses are cached at deployment for gas efficiency
and to avoid external calls during execution validation.

**Note:**
security: The address book must be trusted as it defines the permanently
whitelisted arbiters who can execute operations without signatures


```solidity
constructor(address addressBook) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addressBook`|`address`|The address book contract containing the trusted arbiter addresses|


### executeOpsWithoutSignature

Executes operations on behalf of an account without requiring signatures

This function bypasses normal signature validation for trusted arbiters.
The caller must be a whitelisted arbiter
Execution flow:
1. Validates that the caller has permission to execute without signatures
2. Executes the operations on behalf of the specified account
This is the main entry point for trusted execution scenarios.

**Note:**
security: This function provides significant privileges to the caller.
Ensure that only trusted parties can call this function.


```solidity
function executeOpsWithoutSignature(address account, Types.Operation calldata ops) external onlyWhitelistedArbiter;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account address on whose behalf the operations will be executed|
|`ops`|`Types.Operation`|abi encoded Array of operations to execute|


### onlyWhitelistedArbiter


```solidity
modifier onlyWhitelistedArbiter() ;
```

### _isWhitelistedArbiter

Checks if an arbiter is in the permanent whitelist

Compares the arbiter address against the cached addresses of trusted arbiters.
These addresses are set during contract deployment from the address book.

**Note:**
gas: This function uses cached addresses to avoid storage reads and external calls


```solidity
function _isWhitelistedArbiter(address arbiter) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`arbiter`|`address`|The address to check for whitelist status|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the arbiter is whitelisted, false otherwise|


## Errors
### ExecutionNotTrusted

```solidity
error ExecutionNotTrusted()
```

