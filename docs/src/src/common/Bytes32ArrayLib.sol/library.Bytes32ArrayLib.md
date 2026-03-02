# Bytes32ArrayLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/Bytes32ArrayLib.sol)

A gas-efficient library for manipulating bytes32 arrays with insertion operations

This library provides utilities for inserting elements into bytes32 arrays and computing
their hashes. It leverages Solady's EfficientHashLib for optimized memory management
and hash computation, making it suitable for scenarios where array manipulation
performance is critical, such as:
- Merkle tree construction and verification
- Batch processing with dynamic element insertion
- State commitment schemes requiring ordered data structures
- Gas-optimized array operations in smart contracts
The library uses a memory-efficient approach by allocating exactly the required
memory space and properly managing buffer lifecycle to prevent memory leaks.


## Functions
### insertAt

Inserts a bytes32 element at a specified index in an array, returning a new array

Creates a new array with the element inserted at the specified position. All elements
at or after the insertion index are shifted one position to the right. This function
uses Solady's EfficientHashLib.malloc for optimized memory allocation, which provides
better gas efficiency compared to standard Solidity array operations.
The function performs bounds checking to ensure the index is valid for insertion.
Valid insertion indices range from 0 to array.length (inclusive), allowing insertion
at the beginning, middle, or end of the array.
Example usage:
- Insert at beginning: insertAt([0x02, 0x03], 0, 0x01) → [0x01, 0x02, 0x03]
- Insert at middle: insertAt([0x01, 0x03], 1, 0x02) → [0x01, 0x02, 0x03]
- Insert at end: insertAt([0x01, 0x02], 2, 0x03) → [0x01, 0x02, 0x03]

**Note:**
gas: Uses EfficientHashLib.malloc and .set() methods for optimal gas consumption
compared to standard array operations. Gas cost scales linearly with array size.


```solidity
function insertAt(bytes32[] calldata array, uint256 index, bytes32 element) internal pure returns (bytes32[] memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`array`|`bytes32[]`|The original bytes32 array (passed as calldata for gas efficiency)|
|`index`|`uint256`|The position at which to insert the new element (0-based indexing)|
|`element`|`bytes32`|The bytes32 value to insert into the array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes32[]`|A new bytes32 array containing all original elements plus the inserted element|


### insertAtAndHash

Inserts an element at a specified index and returns the keccak256 hash of the resulting array

This function combines array insertion with hash computation in a single operation,
optimizing for use cases where only the hash of the modified array is needed rather
than the array itself. This is particularly useful for:
- Merkle tree leaf computation where array order matters
- State commitment verification in rollup systems
- Batch transaction hashing with dynamic element insertion
- Gas-optimized proof generation systems
The function uses proper memory management by:
1. Creating the modified array using insertAt()
2. Computing the keccak256 hash via EfficientHashLib.hash()
3. Freeing the temporary buffer to prevent memory bloat
This approach is more gas-efficient than keeping the array in memory when only
the hash is required, as it immediately frees the allocated memory after hashing.
Example usage:
- hash = insertAtAndHash([0x02, 0x03], 0, 0x01)
// Returns keccak256([0x01, 0x02, 0x03])
- hash = insertAtAndHash([0x01, 0x03], 1, 0x02)
// Returns keccak256([0x01, 0x02, 0x03])

**Notes:**
- gas: More gas-efficient than insertAt() + separate hash computation due to
immediate memory deallocation. Saves gas on memory expansion costs.

- security: The hash computation uses keccak256, providing cryptographic security
suitable for commitment schemes and integrity verification.


```solidity
function insertAtAndHash(bytes32[] calldata array, uint256 index, bytes32 element) internal pure returns (bytes32 hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`array`|`bytes32[]`|The original bytes32 array (passed as calldata for gas efficiency)|
|`index`|`uint256`|The position at which to insert the new element (0-based indexing)|
|`element`|`bytes32`|The bytes32 value to insert into the array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|The keccak256 hash of the array after insertion|


## Errors
### Bytes32ArrayLib_IndexOutOutOfBounds
Thrown when attempting to insert at an index beyond the array bounds

This error occurs when the insertion index is greater than or equal to
the length of the resulting array (original length + 1)


```solidity
error Bytes32ArrayLib_IndexOutOutOfBounds()
```

