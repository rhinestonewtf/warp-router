# IIntentExecutor

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IIntentExecutor.sol)

**Inherits:**
[ICompactIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/ICompactIntent.sol/interface.ICompactIntentExecutor.md), [IPermit2IntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/IPermit2Intent.sol/interface.IPermit2IntentExecutor.md), [IStandaloneIntentExecutor](/Users/ops/work/rhinestone/compact-utils/docs/src/src/executor/interfaces/IStandaloneIntent.sol/interface.IStandaloneIntentExecutor.md), [ITrustedExecution](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/ITrustedExecution.sol/interface.ITrustedExecution.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Interface for the IntentExecutor contract that handles intent execution within the Compact protocol

This interface combines multiple execution strategies by inheriting from specialized sub-executor interfaces:

- ICompactIntentExecutor: Handles Compact protocol operations with pre-claim and target execution
- IPermit2IntentExecutor: Handles Permit2-based intent execution
- IStandaloneIntentExecutor: Handles standalone multi-chain operations
- ITrustedExecution: Handles execution without signatures for whitelisted arbiters

## Functions

### isInitialized

Checks if the module is initialized for a given smart account

```solidity
function isInitialized(address smartAccount) external view returns (bool);
```

**Parameters**

| Name           | Type      | Description                               |
| -------------- | --------- | ----------------------------------------- |
| `smartAccount` | `address` | The address of the smart account to check |

**Returns**

| Name     | Type   | Description                                            |
| -------- | ------ | ------------------------------------------------------ |
| `<none>` | `bool` | bool True if the module is initialized for the account |

### isModuleType

Checks if the module supports a specific module type

```solidity
function isModuleType(uint256 moduleTypeId) external pure returns (bool);
```

**Parameters**

| Name           | Type      | Description                         |
| -------------- | --------- | ----------------------------------- |
| `moduleTypeId` | `uint256` | The module type identifier to check |

**Returns**

| Name     | Type   | Description                                                                             |
| -------- | ------ | --------------------------------------------------------------------------------------- |
| `<none>` | `bool` | bool True if the module type is supported (should return true for MODULE_TYPE_EXECUTOR) |

### onInstall

Called when the module is installed on a smart account

```solidity
function onInstall(bytes calldata data) external;
```

**Parameters**

| Name   | Type    | Description                |
| ------ | ------- | -------------------------- |
| `data` | `bytes` | Installation data (if any) |

### onUninstall

Called when the module is uninstalled from a smart account

```solidity
function onUninstall(bytes calldata data) external;
```

**Parameters**

| Name   | Type    | Description                  |
| ------ | ------- | ---------------------------- |
| `data` | `bytes` | Uninstallation data (if any) |
