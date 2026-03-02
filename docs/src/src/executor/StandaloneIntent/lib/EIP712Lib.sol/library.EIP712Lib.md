# EIP712Lib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/StandaloneIntent/lib/EIP712Lib.sol)

Library for EIP-712 structured data hashing in standalone intent execution

This library provides efficient EIP-712 hash computation for multi-chain operations
with gas-optimized assembly implementations. It supports two main data structures:
1. ChainOps: Operations for a specific chain (chainId, nonce, operations array)
2. MultiChainOps: Account-level operations across multiple chains
The library implements a Merkle tree-like structure where operations from different
chains are combined into a single hash, enabling atomic multi-chain intent execution
with a single signature.
EIP-712 Structure:
- ChainOps(uint256 chainId, uint256 nonce, Op[] ops)
- MultiChainOps(address account, ChainOps[] ops)
- Op(address to, uint256 value, bytes data)

**Note:**
gas: All hash functions use assembly for gas optimization while maintaining memory safety


## State Variables
### CHAINOPS_TYPEHASH
EIP-712 type hash for ChainOps structure - includes dependent Op type definition


```solidity
bytes32 internal constant CHAINOPS_TYPEHASH =
    keccak256(abi.encodePacked("ChainOps(uint256 chainId,uint256 nonce,Op[] ops)", "Op(address to,uint256 value,bytes data)"))
```


### MULTICHAINOPS_TYPEHASH
EIP-712 type hash for MultiChainOps structure - includes all dependent type definitions


```solidity
bytes32 internal constant MULTICHAINOPS_TYPEHASH = keccak256(
    abi.encodePacked(
        "MultiChainOps(address account,ChainOps[] ops)",
        "ChainOps(uint256 chainId,uint256 nonce,Op[] ops)",
        "Op(address to,uint256 value,bytes data)"
    )
)
```


## Functions
### hashChainOps

Computes the EIP-712 hash for chain-specific operations

Creates a structured hash for operations on a specific chain, including
the chain ID for replay protection across different networks. Uses
gas-optimized assembly for memory management and hashing.
Hash structure: keccak256(typehash || chainId || nonce || opsHash)

**Note:**
gas: Uses assembly with memory-safe annotation for efficient hashing


```solidity
function hashChainOps(uint256 chainId, uint256 nonce, Execution[] calldata ops) internal pure returns (bytes32 _hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`chainId`|`uint256`|The blockchain identifier where these operations will execute|
|`nonce`|`uint256`|The nonce for replay protection on this specific chain|
|`ops`|`Execution[]`|Array of operations to execute on this chain|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_hash`|`bytes32`|The computed EIP-712 hash for this chain's operations|


### hashAndDecode

Computes the complete EIP-712 hash for multi-chain operations

This is the main hash function that combines operations from multiple chains
into a single hash for signature validation. The process:
1. Extracts nonce and account from the multi-chain operations
2. Computes hash for operations on the current chain
3. Inserts current chain operations into the multi-chain structure
4. Combines all chain operations into final EIP-712 hash
This enables atomic multi-chain execution with a single signature.

**Note:**
gas: Uses view function to access block.chainid and assembly for efficient hashing


```solidity
function hashAndDecode(IStandaloneIntentExecutor.MultiChainOps calldata multichainOps)
    internal
    view
    returns (bytes32 _hash, uint256 nonce, SmartExecutionLib.SigMode sigMode, Execution[] calldata executions);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`multichainOps`|`IStandaloneIntentExecutor.MultiChainOps`|The complete multi-chain operations structure|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_hash`|`bytes32`|The computed EIP-712 hash for signature validation|
|`nonce`|`uint256`|The extracted nonce for replay protection|
|`sigMode`|`SmartExecutionLib.SigMode`||
|`executions`|`Execution[]`||


### hash

Computes EIP-712 hash from pre-computed chain operation hashes

Alternative hash function that takes pre-computed chain hashes instead of
raw multi-chain operations. Useful for optimization when chain hashes
are already available or for external hash verification.
This function is pure since it doesn't need access to block.chainid.

**Note:**
gas: Pure function with assembly optimization for gas efficiency


```solidity
function hash(address account, bytes32[] calldata allChains) internal pure returns (bytes32 _hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account address that owns these multi-chain operations|
|`allChains`|`bytes32[]`|Array of pre-computed hashes for all chain operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_hash`|`bytes32`|The computed EIP-712 hash for signature validation|


