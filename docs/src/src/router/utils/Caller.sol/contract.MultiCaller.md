# MultiCaller

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/utils/Caller.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

A simple contract that provides a `multiCall` function to execute a batch of transactions.
It ensures that it can only be called by a designated Router, making it a secure, internal utility.

## Functions

### multiCall

Executes a batch of calls.

Can only be called by the `ROUTER` address. Reverts if any of the batched calls fail.

```solidity
function multiCall(Execution[] calldata executions) external payable;
```

**Parameters**

| Name         | Type          | Description                                                                     |
| ------------ | ------------- | ------------------------------------------------------------------------------- |
| `executions` | `Execution[]` | An array of `Execution` structs, each containing a target, value, and callData. |

### multiCallWithDrainToken

Executes a batch of calls.

Can only be called by the `ROUTER` address. Reverts if any of the batched calls fail.

```solidity
function multiCallWithDrainToken(Execution[] calldata executions, uint256[2][] calldata tokenAndAmounts, address recipient)
    external
    payable;
```

**Parameters**

| Name              | Type           | Description                                                                     |
| ----------------- | -------------- | ------------------------------------------------------------------------------- |
| `executions`      | `Execution[]`  | An array of `Execution` structs, each containing a target, value, and callData. |
| `tokenAndAmounts` | `uint256[2][]` |                                                                                 |
| `recipient`       | `address`      |                                                                                 |

### \_withdrawApprovedTokens

Internal function to withdraw approved tokens to a recipient address.

Handles both native ETH and ERC20 token transfers.
For native ETH, ensures contract balance is sufficient.
For ERC20 tokens, transfers from contract to recipient.

```solidity
function _withdrawApprovedTokens(uint256[2][] calldata tokenAndAmounts, address recipient) internal;
```

**Parameters**

| Name              | Type           | Description                                       |
| ----------------- | -------------- | ------------------------------------------------- |
| `tokenAndAmounts` | `uint256[2][]` | Array of [tokenAddress, amount] pairs to withdraw |
| `recipient`       | `address`      | Address to receive the withdrawn tokens           |

### receive

```solidity
receive() external payable;
```

## Errors

### Unauthorized

Thrown when a function is called by an unauthorized address.

```solidity
error Unauthorized()
```

### ExecutionFailed

Thrown when one of the calls in a multicall batch fails.

```solidity
error ExecutionFailed()
```

### WithdrawFailed

```solidity
error WithdrawFailed()
```
