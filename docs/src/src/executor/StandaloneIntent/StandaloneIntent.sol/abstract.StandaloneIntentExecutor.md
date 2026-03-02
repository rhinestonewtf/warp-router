# StandaloneIntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/StandaloneIntent/StandaloneIntent.sol)

**Inherits:**
[IStandaloneIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/IStandaloneIntent.sol/interface.IStandaloneIntentExecutor.md), EIP712, [IntentExecutorBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/IntentExecutorBase.sol/abstract.IntentExecutorBase.md), [ValidateSignature](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/VerifySignature/VerifySignature.sol/abstract.ValidateSignature.md)

Executor contract for standalone multi-chain intent execution without external protocols

This contract enables self-contained intent execution with the following key features:
- Chain-agnostic signature validation using EIP-712 without chain-specific components
- Direct nonce management for replay protection at the account level
- ERC-1271 signature validation supporting both EOA and smart contract accounts
- Batch operation execution with gas-optimized single vs. multi-operation handling
The execution flow:
1. User signs a MultiChainOps struct containing operations and metadata
2. Anyone can submit the signed operations for execution
3. Contract validates the signature using chain-agnostic EIP-712 hashing
4. Nonce is consumed to prevent replay attacks
5. Operations are executed on behalf of the signing account
Key differences from other executors:
- No dependency on external protocols (Compact, Permit2)
- Chain-agnostic signatures work across different networks
- Direct account-based authorization without intermediaries

**Note:**
security: Security considerations:
- Chain-agnostic signatures prevent replay across different chains
- Account-level nonce management provides granular replay protection
- ERC-1271 validation ensures compatibility with various account types
- No external protocol dependencies reduce attack surface


## Functions
### executeMultichainOps

Executes a batch of multi-chain operations after verifying signature and nonce

This is the main entry point for standalone intent execution. The function performs
comprehensive validation before execution:
1. Extracts the account address and nonce from the signed operations structure
2. Consumes the nonce immediately to prevent replay attacks
3. Computes the chain-agnostic EIP-712 digest for signature validation
4. Validates the signature using ERC-1271 standard (supports both EOAs and smart contracts)
5. Executes the operations on behalf of the signing account
Chain-agnostic design: The signature validation excludes chain ID from the digest,
allowing the same signature to be valid across different chains. However, the
chain ID is still included in the hash computation by the EIP712Lib to maintain
security while enabling cross-chain compatibility.

**Note:**
security: The nonce consumption happens before signature validation to prevent
partial state changes in case of signature validation failure


```solidity
function executeMultichainOps(MultiChainOps calldata signedOps) external returns (uint256 _nonce);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signedOps`|`MultiChainOps`|The MultiChainOps struct containing account, operations, nonce, and signature|


### isStandaloneIntentNonceConsumed

Checks if a nonce has been used for a specific account

This function provides a clean way to check nonce usage without relying on low-level storage access


```solidity
function isStandaloneIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
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


### _domainNameAndVersion

Provides the EIP-712 domain name and version for signature validation

These values are used in the EIP-712 domain separator computation and must remain
constant to ensure signature compatibility across deployments


```solidity
function _domainNameAndVersion() internal pure override returns (string memory name, string memory version);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The domain name used in EIP-712 signatures ("IntentExecutor")|
|`version`|`string`|The version string used in EIP-712 signatures ("v0.0.1")|


