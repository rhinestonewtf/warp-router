# IntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/IntentExecutor.sol)

**Inherits:**
ERC7579ExecutorBase, [IntentExecutorBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/IntentExecutorBase.sol/abstract.IntentExecutorBase.md), [ValidateSignature](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/VerifySignature/VerifySignature.sol/abstract.ValidateSignature.md), [CompactIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/CompactIntent/CompactIntentExecutor.sol/abstract.CompactIntentExecutor.md), [Permit2IntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/Permit2Intent/Permit2Executor.sol/abstract.Permit2IntentExecutor.md), [StandaloneIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/StandaloneIntent/StandaloneIntent.sol/abstract.StandaloneIntentExecutor.md), [TrustedExecution](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/TrustedExecution/TrustedExecution.sol/abstract.TrustedExecution.md)

Main executor contract that unifies multiple intent execution mechanisms

This contract serves as the central hub for executing different types of intents:
- CompactIntentExecutor: Executes intents using The Compact protocol for cross-chain transfers
- Permit2IntentExecutor: Executes intents using Permit2 for gasless token approvals
- StandaloneIntentExecutor: Executes intents independently without external protocols
- TrustedExecution: Executes operations from trusted parties without signature verification
The contract inherits from ERC7579ExecutorBase to provide modular account compatibility
and implements the ERC-7579 executor module interface for smart contract wallets.

**Note:**
security: This contract aggregates multiple execution paths, each with different trust models.
Users should understand the security implications of each execution type before use.


## Functions
### constructor

Initializes the IntentExecutor with required dependencies for all execution types

Chains constructor calls to initialize each inherited executor component:
- CompactIntentExecutor requires router, compact protocol, and lock tag
- Permit2IntentExecutor has no constructor parameters
- TrustedExecution requires an address book for trusted party validation
- ExecutionSigChecker requires compact protocol


```solidity
constructor(address router, address compact, address allocator, address addressBook)
    TrustedExecution(addressBook)
    ValidateSignature(compact)
    CompactEIP712(compact)
    Permit2EIP712(address(Constants.PERMIT2))
    IntentExecutorBase(router, allocator);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The router contract address for cross-chain operations|
|`compact`|`address`|The Compact protocol contract address for cross-chain transfers|
|`allocator`|`address`|the RSAllocator|
|`addressBook`|`address`|The address book contract for managing trusted execution parties|


### isInitialized

Checks if the executor module is initialized for a specific smart account

This function is required by the ERC-7579 module interface but currently returns
false as initialization state is not tracked. Future implementations may add
account-specific initialization tracking.


```solidity
function isInitialized(address smartAccount) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`smartAccount`|`address`|The smart account address to check initialization status for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Always returns false in current implementation|


### isModuleType

Identifies this contract as an ERC-7579 executor module

Part of the ERC-7579 module interface. Returns true only for MODULE_TYPE_EXECUTOR
to indicate this contract implements executor functionality.


```solidity
function isModuleType(uint256 moduleTypeId) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`moduleTypeId`|`uint256`|The module type identifier to check against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if moduleTypeId matches MODULE_TYPE_EXECUTOR, false otherwise|


### onInstall

Handles module installation on a smart account

Required by ERC-7579 but currently performs no initialization logic.
Future implementations may add account-specific setup here.


```solidity
function onInstall(bytes calldata /* data*/) external;
```

### onUninstall

Handles module uninstallation from a smart account

Required by ERC-7579 but currently performs no cleanup logic.
Future implementations may add account-specific cleanup here.


```solidity
function onUninstall(bytes calldata /* data*/) external;
```

