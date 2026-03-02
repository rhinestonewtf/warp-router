// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title AdapterCalldataPassthroughLib
 * @notice Library for efficiently forwarding calldata to target contracts without additional encoding overhead
 * @dev This library provides gas-optimized calldata forwarding functionality using inline assembly.
 *      It constructs function calls by combining a function selector with pre-encoded parameters,
 *      avoiding the need for additional ABI encoding operations that would consume extra gas.
 *
 *      The assembly implementation directly manipulates memory and calldata to achieve maximum
 *      efficiency when acting as a proxy or adapter contract that needs to forward calls.
 *
 *      Key optimizations:
 *      - Zero-copy calldata forwarding using calldatacopy
 *      - Minimal memory allocation
 *      - Direct assembly call without high-level Solidity overhead
 *      - Proper error propagation maintaining original revert data
 * @custom:security Uses memory-safe assembly and properly manages the free memory pointer
 * @custom:gas Optimized for minimal gas consumption in adapter/proxy patterns
 */
library AdapterCalldataPassthroughLib {
    /**
     * @notice Private helper that constructs calldata and executes the call
     * @dev Returns (success, ptr, totalSize) to allow callers to handle success/failure differently
     * @return success Whether the call succeeded
     * @return ptr Memory pointer where calldata was constructed
     * @return totalSize Total size of the calldata
     */
    function _executeCall(
        address target,
        bytes4 selector,
        bytes calldata abiEncodedParams
    )
        private
        returns (bool success, uint256 ptr, uint256 totalSize)
    {
        assembly ("memory-safe") {
            // Load the free memory pointer
            ptr := mload(0x40)

            // Store the function selector
            mstore(ptr, selector)

            // Copy parameters from calldata to memory after the selector
            calldatacopy(add(ptr, 0x04), abiEncodedParams.offset, abiEncodedParams.length)

            // Calculate total calldata size
            totalSize := add(abiEncodedParams.length, 0x04)

            // Execute the call
            success := call(gas(), target, 0x00, ptr, totalSize, 0x00, 0x00)
        }
    }

    /**
     * @notice Forwards a function call to a target contract by constructing calldata from a selector and parameters
     * @dev This function uses assembly to efficiently construct and forward calls without additional memory allocation.
     *      The implementation directly copies calldata to minimize gas costs and avoid redundant encoding operations.
     *
     *      The function preserves the exact revert data from the target contract, ensuring that error messages
     *      and custom errors are properly propagated to the caller. This is crucial for debugging and maintaining
     *      the same error semantics as a direct call.
     *
     *      Memory safety: This function is marked as memory-safe and properly manages the free memory pointer
     *      to ensure compatibility with Solidity's memory model.
     *
     * @param target The address of the contract to call - must be a valid contract address
     * @param selector The 4-byte function selector to call on the target contract
     * @param abiEncodedParams The ABI-encoded parameters for the function call (without the selector).
     *                        This should be the exact calldata that would follow the selector in a normal call.
     *
     * @custom:security The function makes an external call with all available gas. Ensure proper access controls
     *                  are in place before calling this function to prevent unauthorized contract interactions.
     * @custom:gas Uses calldatacopy for zero-copy parameter forwarding, avoiding expensive memory operations.
     *             Gas cost is approximately: 21000 (base call) + calldata costs + target execution costs.
     *
     * @dev Reverts with the original revert data if the target call fails, preserving error context.
     *      The assembly block is marked as memory-safe for optimization compatibility.
     */
    function passthrough(address target, bytes4 selector, bytes calldata abiEncodedParams) internal {
        (bool success, uint256 ptr, uint256 totalSize) = _executeCall(target, selector, abiEncodedParams);

        assembly ("memory-safe") {
            // Check if the call failed and handle error propagation
            if iszero(success) {
                // Copy the error data returned by the failed call to memory starting at position 0
                returndatacopy(0x00, 0x00, returndatasize())
                // Revert with the copied error data, maintaining the original error context
                revert(0x00, returndatasize())
            }

            // Update the free memory pointer to reflect the memory we've used
            mstore(0x40, add(ptr, totalSize))
        }
    }

    /**
     * @notice Forwards a function call to a target contract and returns the result as bytes
     * @dev Captures and returns the call result as bytes memory.
     *      Uses assembly for efficient calldata forwarding with return data capture.
     *
     * @param target The address of the contract to call - must be a valid contract address
     * @param selector The 4-byte function selector to call on the target contract
     * @param abiEncodedParams The ABI-encoded parameters for the function call (without the selector)
     *
     * @return returnData The bytes returned by the target contract call
     *
     * @custom:security The function makes an external call with all available gas. Ensure proper access controls
     *                  are in place before calling this function to prevent unauthorized contract interactions.
     * @custom:gas Slightly more expensive than passthrough due to return data copying.
     *
     * @dev Reverts with the original revert data if the target call fails, preserving error context.
     */
    function passthroughToBytes(
        address target,
        bytes4 selector,
        bytes calldata abiEncodedParams
    )
        internal
        returns (bytes memory returnData)
    {
        (bool success, uint256 ptr,) = _executeCall(target, selector, abiEncodedParams);

        assembly ("memory-safe") {
            // Get the size of returned data
            let returnSize := returndatasize()

            // Copy return data to memory after the length slot
            returndatacopy(add(ptr, 0x20), 0x00, returnSize)

            // Handle failure case
            if iszero(success) {
                // Revert with the return data (error message)
                revert(add(ptr, 0x20), returnSize)
            }

            // Update free memory pointer to account for both our calldata and return data
            mstore(0x40, add(add(ptr, 0x20), returnSize))

            // Store the return data length in the first 32 bytes (standard bytes format)
            mstore(ptr, returnSize)

            // Set returnData to point to our allocated memory
            returnData := ptr
        }
    }

    /**
     * @notice Forwards a function call and returns a uint256 directly (gas optimized)
     * @dev More gas efficient than passthroughToBytes as it skips the bytes memory allocation
     *      and directly reads the return value
     *
     * @param target The address of the contract to call
     * @param selector The 4-byte function selector to call on the target contract
     * @param abiEncodedParams The ABI-encoded parameters for the function call (without the selector)
     *
     * @return val The uint256 value returned by the target contract
     *
     * @custom:gas Saves gas by avoiding intermediate bytes memory allocation
     */
    function passthroughToUint256(address target, bytes4 selector, bytes calldata abiEncodedParams) internal returns (uint256 val) {
        (bool success,,) = _executeCall(target, selector, abiEncodedParams);

        assembly ("memory-safe") {
            // Handle failure case
            if iszero(success) {
                // Copy error data to memory and revert
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            // Directly read the uint256 from return data (first 32 bytes)
            returndatacopy(0x00, 0x00, 0x20)
            val := mload(0x00)
        }
    }

    /**
     * @notice Forwards a function call and returns (address, uint256) directly (gas optimized)
     * @dev More gas efficient than passthroughToBytes as it skips the bytes memory allocation
     *      and directly reads the return values
     *
     * @param target The address of the contract to call
     * @param selector The 4-byte function selector to call on the target contract
     * @param abiEncodedParams The ABI-encoded parameters for the function call (without the selector)
     *
     * @return account The address value returned by the target contract
     * @return val The uint256 value returned by the target contract
     *
     * @custom:gas Saves gas by avoiding intermediate bytes memory allocation
     */
    function passthroughToAddressUint256(
        address target,
        bytes4 selector,
        bytes calldata abiEncodedParams
    )
        internal
        returns (address account, uint256 val)
    {
        (bool success,,) = _executeCall(target, selector, abiEncodedParams);

        assembly ("memory-safe") {
            // Handle failure case
            if iszero(success) {
                // Copy error data to memory and revert
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            // Directly read the address and uint256 from return data (64 bytes total)
            returndatacopy(0x00, 0x00, 0x40)
            account := mload(0x00)
            val := mload(0x20)
        }
    }

    /**
     * @notice Forwards a function call and emits an event directly from return data (highly gas optimized)
     * @dev Most gas efficient approach - copies return data directly to scratch space and emits event
     *      without any intermediate memory allocations or loads/stores beyond what's needed for the log.
     *      Validates that the return data is exactly 64 bytes (address + uint256).
     *
     * @param target The address of the contract to call
     * @param selector The 4-byte function selector to call on the target contract
     * @param params The ABI-encoded parameters for the function call (without the selector)
     * @param eventSignature The keccak256 hash of the event signature to emit
     *
     * @custom:gas Minimizes gas by:
     *             - Using returndatacopy directly to scratch space (0x00-0x40)
     *             - Emitting event immediately without intermediate mload operations
     *             - No memory allocation or pointer management needed
     * @custom:security Validates return data size to prevent emitting garbage data
     */
    function passthroughWithEmit(address target, bytes4 selector, bytes calldata params, bytes32 eventSignature) internal {
        (bool success,,) = _executeCall(target, selector, params);

        assembly ("memory-safe") {
            // Handle failure case
            if iszero(success) {
                // Copy error data to memory and revert
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            // Validate return data size is exactly 64 bytes (address + uint256)
            if iszero(eq(returndatasize(), 0x40)) {
                // Store error selector for InvalidReturnDataSize()
                mstore(0x00, 0x648cc85a00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }

            // Copy return data (address, uint256) directly to scratch space and emit
            // This is the most gas-efficient approach - single returndatacopy followed by log
            returndatacopy(0x00, 0x00, 0x40)
            log1(0x00, 0x40, eventSignature)
        }
    }

    /// @notice Thrown when return data size is not exactly 64 bytes (address + uint256)
    error InvalidReturnDataSize();
}
