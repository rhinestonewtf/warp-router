# IStandaloneIntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/interfaces/IStandaloneIntent.sol)

Interface for standalone multi-chain intent execution

Defines the contract interface for executing intents independently without external protocols


## Functions
### executeMultichainOps

Executes a multi-chain intent after signature validation

Validates the chain-agnostic EIP-712 signature and executes operations


```solidity
function executeMultichainOps(MultiChainOps calldata signedOps) external returns (uint256 nonce);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signedOps`|`MultiChainOps`|The complete multi-chain operations structure with signature|


### isStandaloneIntentNonceConsumed

Checks if a nonce has been used for a specific account

Provides a way to check nonce usage for standalone intents


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


## Errors
### InvalidStandaloneIntentSignature
Thrown when standalone intent signature validation fails


```solidity
error InvalidStandaloneIntentSignature()
```

## Structs
### MultiChainOps
Multi-chain operations structure for standalone intent execution

Contains all data needed for chain-agnostic multi-chain operation execution


```solidity
struct MultiChainOps {
    /// @dev The account address that owns and signed these operations
    address account;
    /// @dev Index position of current chain in the otherChains array
    uint256 chainIndex;
    /// @dev Array of operation hashes from other chains in the multi-chain intent
    bytes32[] otherChains;
    /// @dev Nonce for replay protection
    uint256 nonce;
    /// @dev Operations to execute on the current chain
    Types.Operation ops;
    /// @dev EIP-712 signature from the account authorizing all operations
    bytes signature;
}
```

