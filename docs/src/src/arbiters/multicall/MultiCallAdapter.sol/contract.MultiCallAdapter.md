# MultiCallAdapter

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/arbiters/multicall/MultiCallAdapter.sol)

**Inherits:**
[AdapterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/adapter/AdapterBase.sol/abstract.AdapterBase.md), [Caller](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/utils/Caller.sol/contract.Caller.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Adapter for executing batched arbitrary calls through the Warp Routerr with solver compensation

This adapter enables solvers to execute multiple calls on behalf of users while ensuring proper token
transfers and fee collection. It supports various fill operations including standard fills, fills with
fees, and fills with both fees and refunds. The adapter validates that solvers receive expected payment
and handles the complexity of multi-step transactions.

## Functions

### \_\_encodeRelayerData

Encodes recipient addresses for solver context

Helper function for off-chain components to construct relayerContext data

```solidity
function __encodeRelayerData(address tokenInRecipient) external pure returns (bytes memory);
```

**Parameters**

| Name               | Type      | Description                                        |
| ------------------ | --------- | -------------------------------------------------- |
| `tokenInRecipient` | `address` | Address to receive input tokens from the multicall |

**Returns**

| Name     | Type    | Description                                      |
| -------- | ------- | ------------------------------------------------ |
| `<none>` | `bytes` | Packed bytes containing both recipient addresses |

### \_tokenInRecipient

Extracts the tokenIn recipient from solver context

Reads the first 20 bytes of solver context data

```solidity
function _tokenInRecipient() internal pure returns (address);
```

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `address` | Address designated to receive input tokens |

### constructor

Initializes the MultiCallAdapter with router and arbiter addresses

```solidity
constructor(address router) AdapterBase(router, address(0)) SemVer(0, 0);
```

**Parameters**

| Name     | Type      | Description                               |
| -------- | --------- | ----------------------------------------- |
| `router` | `address` | Address of the Warp Routerr contract |

### multicall_handleJITClaim

Handles Just-In-Time claim operations with multicall execution

Executes multicalls and ensures solver receives specified tokenIn amounts

```solidity
function multicall_handleJITClaim(JITClaimData calldata jitClaimData) external onlyViaRouter returns (bytes4);
```

**Parameters**

| Name           | Type           | Description                                            |
| -------------- | -------------- | ------------------------------------------------------ |
| `jitClaimData` | `JITClaimData` | Contains tokenIn compensation and multicall executions |

**Returns**

| Name     | Type     | Description                        |
| -------- | -------- | ---------------------------------- |
| `<none>` | `bytes4` | Function selector for verification |

### multicall_handlePayable

Handles payable multicall operations with ETH value

Forwards ETH value to arbiter for multicall execution

```solidity
function multicall_handlePayable(uint256 value, Execution[] calldata executions) external payable onlyViaRouter returns (bytes4);
```

**Parameters**

| Name         | Type          | Description                              |
| ------------ | ------------- | ---------------------------------------- |
| `value`      | `uint256`     | Amount of ETH to send with the multicall |
| `executions` | `Execution[]` | Array of calls to execute                |

**Returns**

| Name     | Type     | Description                        |
| -------- | -------- | ---------------------------------- |
| `<none>` | `bytes4` | Function selector for verification |

### multicall_handleFill

Executes a standard multicall fill operation

Router-only function that extracts tokenIn recipient from context and processes fill

```solidity
function multicall_handleFill(FillData calldata fillData) external payable onlyViaRouter returns (bytes4);
```

**Parameters**

| Name       | Type       | Description                                       |
| ---------- | ---------- | ------------------------------------------------- |
| `fillData` | `FillData` | Contains token transfers and multicall executions |

**Returns**

| Name     | Type     | Description                        |
| -------- | -------- | ---------------------------------- |
| `<none>` | `bytes4` | Function selector for verification |

### \_handleMulticall

Internal handler for multicall fill operations

Prefunds user account with tokenOut before executing multicalls

```solidity
function _handleMulticall(FillData calldata fillData, address tokenInReceiver) internal;
```

**Parameters**

| Name              | Type       | Description                              |
| ----------------- | ---------- | ---------------------------------------- |
| `fillData`        | `FillData` | Contains all data for the fill operation |
| `tokenInReceiver` | `address`  | Address to receive tokenIn payments      |

### \_multicallAssertTokenIn

Core multicall execution with token validation

Executes multicalls through arbiter and ensures tokenIn is properly transferred

```solidity
function _multicallAssertTokenIn(Execution[] calldata multicalls, uint256[2][] calldata tokenIn, address tokenInReceiver, uint256 value)
    internal;
```

**Parameters**

| Name              | Type           | Description                          |
| ----------------- | -------------- | ------------------------------------ |
| `multicalls`      | `Execution[]`  | Array of calls to execute            |
| `tokenIn`         | `uint256[2][]` | Expected token payments to solver    |
| `tokenInReceiver` | `address`      | Address to receive the tokens        |
| `value`           | `uint256`      | ETH value to send with the multicall |

### supportsInterface

Checks if adapter supports a given function selector

Used for interface detection and compatibility checks

```solidity
function supportsInterface(bytes4 selector) public pure override(AdapterBase, Caller) returns (bool);
```

**Parameters**

| Name       | Type     | Description                |
| ---------- | -------- | -------------------------- |
| `selector` | `bytes4` | Function selector to check |

**Returns**

| Name     | Type   | Description                                       |
| -------- | ------ | ------------------------------------------------- |
| `<none>` | `bool` | True if the selector is supported by this adapter |

## Errors

### TokenNotPaidInMulticall

Using the IdLib library to handle token ID conversions.

Thrown if the solver does not receive the expected amount of input tokens after the multicall.

```solidity
error TokenNotPaidInMulticall()
```

## Structs

### FillData

Data structure for multicall fill operations

```solidity
struct FillData {
    // What the solver is being paid back in.
    uint256[2][] tokenIn;
    // What the solver pays the account.
    uint256[2][] tokenOut;
    Execution[] multicalls;
    address account;
    // Value to send with the multicall
    uint256 value;
}
```

**Properties**

| Name         | Type           | Description                                                         |
| ------------ | -------------- | ------------------------------------------------------------------- |
| `tokenIn`    | `uint256[2][]` | Array of [token_address, amount] pairs representing solver payment  |
| `tokenOut`   | `uint256[2][]` | Array of [token_address, amount] pairs the solver transfers to user |
| `multicalls` | `Execution[]`  | Batch of execution calls to perform                                 |
| `account`    | `address`      | Target smart contract account for the operations                    |
| `value`      | `uint256`      |                                                                     |

### JITClaimData

Data structure for Just-In-Time claim operations

```solidity
struct JITClaimData {
    // What the solver is being paid back in.
    uint256[2][] tokenIn;
    Execution[] multicalls;
}
```

**Properties**

| Name         | Type           | Description                                                    |
| ------------ | -------------- | -------------------------------------------------------------- |
| `tokenIn`    | `uint256[2][]` | Array of [token_address, amount] pairs for solver compensation |
| `multicalls` | `Execution[]`  | Batch of execution calls for the JIT claim                     |
