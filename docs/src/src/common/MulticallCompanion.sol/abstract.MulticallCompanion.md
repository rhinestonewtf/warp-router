# MulticallCompanion

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/MulticallCompanion.sol)

**Inherits:**
ReentrancyGuardTransient

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

An abstract base contract for handling multicalls

## Functions

### \_weth

```solidity
function _weth() internal view virtual returns (address);
```

### onlySelf

Modifier to ensure only the contract itself can call the function.
This is crucial for functions that are part of a controlled multi-call execution
and should not be directly callable by external users.

```solidity
modifier onlySelf() ;
```

### \_requireSelf

Internal function to ensure the caller of the current function is this contract itself.
This is a security mechanism to prevent unauthorized external calls to functions that
are designed to be part of an internal, controlled execution flow (e.g., within a
multicall).

```solidity
function _requireSelf() internal view;
```

### \_drainRemainingToken

Internal function to drain remaining tokens (ERC20 or native Ether) to a specified
destination.
This function is crucial for cleaning up any residual tokens that might be left in the
contract
after an operation, preventing them from being locked or stolen.

```solidity
function _drainRemainingToken(address token, address destination) internal;
```

**Parameters**

| Name          | Type      | Description                                                                                                  |
| ------------- | --------- | ------------------------------------------------------------------------------------------------------------ |
| `token`       | `address` | The address of the token to drain. If `address(0x0)` (Constants.NATIVE_TOKEN), native Ether will be drained. |
| `destination` | `address` | The address to send the drained tokens to.                                                                   |

### \_drainLeftoverTokens

Drains a list of leftover tokens from this contract to a specified destination.

This function can only be called by the contract itself, typically as part of a
multicall.
It iterates through the provided array of token addresses and calls
`_drainRemainingToken` for each.

```solidity
function _drainLeftoverTokens(address[] calldata tokens, address destination) internal;
```

**Parameters**

| Name          | Type        | Description                                                                           |
| ------------- | ----------- | ------------------------------------------------------------------------------------- |
| `tokens`      | `address[]` | An array of token addresses to drain. This can include `address(0)` for native Ether. |
| `destination` | `address`   | The address to send all the drained tokens to.                                        |

### drainLeftoverTokens

```solidity
function drainLeftoverTokens(address[] calldata tokens, address destination)
    external
    onlySelf;
```

### drainLeftoverToken

Drains a single leftover token from this contract to a specified destination.

This function can only be called by the contract itself, typically as part of a
multicall.
It delegates the draining logic to `_drainRemainingToken`.

```solidity
function drainLeftoverToken(address token, address destination) external onlySelf;
```

**Parameters**

| Name          | Type      | Description                                                                              |
| ------------- | --------- | ---------------------------------------------------------------------------------------- |
| `token`       | `address` | The address of the token to drain. If `address(0)`, native tokens (ETH) will be drained. |
| `destination` | `address` | The address to send the drained tokens to.                                               |

### withdrawWETH

Withdraws a specified amount of WETH (Wrapped Ether) and sends the corresponding
Ether to a recipient.

This function can only be called by the contract itself. It first unwraps WETH to ETH
and then transfers the ETH to the `recipient`.

```solidity
function withdrawWETH(address recipient, uint256 amount) external onlySelf;
```

**Parameters**

| Name        | Type      | Description                                            |
| ----------- | --------- | ------------------------------------------------------ |
| `recipient` | `address` | The address to which the unwrapped Ether will be sent. |
| `amount`    | `uint256` | The amount of WETH to withdraw and convert to Ether.   |

### withdrawAllWETH

Withdraws all WETH (Wrapped Ether) held by this contract and sends the corresponding
Ether to a recipient.

This function can only be called by the contract itself. It retrieves the contract's
entire
WETH balance, unwraps it to ETH, and then transfers all the ETH to the `recipient`.

```solidity
function withdrawAllWETH(address recipient) external onlySelf;
```

**Parameters**

| Name        | Type      | Description                                            |
| ----------- | --------- | ------------------------------------------------------ |
| `recipient` | `address` | The address to which all unwrapped Ether will be sent. |

### \_multiCall

```solidity
function _multiCall(Execution[] calldata executions) internal;
```

### \_singleCall

```solidity
function _singleCall(address target, uint256 value, bytes calldata callData) internal;
```

### receive

Fallback function to receive native tokens (ETH).

This `receive` function allows the contract to accept incoming Ether.
It is marked `external payable` to enable direct Ether transfers to this contract.
This is particularly useful if the caller intends to unwrap native tokens to this
contract.

```solidity
receive() external payable;
```

## Events

### DrainedTokens

```solidity
event DrainedTokens(address indexed recipient, address indexed token, uint256 indexed amount)
```

## Errors

### Unauthorized

```solidity
error Unauthorized()
```

### NotSelf

Thrown if a function intended for self-call is called by an external address.

```solidity
error NotSelf()
```

### ExecutionFailed

Thrown when one of the calls in a multicall batch fails.

```solidity
error ExecutionFailed()
```
