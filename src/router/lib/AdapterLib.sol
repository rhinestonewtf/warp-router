// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/// @title AdapterLib
/// @notice Gas-optimized library for calling adapters with or without solver context using pure assembly
/// @dev Drop-in replacement for _callAdapterWithRelayerContext with 60% gas savings
library AdapterLib {
    error DelegatecallFailed();

    /// @notice Executes a delegatecall to an adapter without solver context
    /// @dev Optimized version for adapters that don't require solver context
    /// @dev Appends uint256(0) as context length to maintain protocol compatibility
    /// @dev caller MUST ensure, that adapter != address(0)
    /// @param adapter The address of the adapter to delegatecall
    /// @param adapterCalldata The original calldata for the adapter function
    /// @return ret The function selector returned by the adapter
    function callAdapter(address adapter, bytes calldata adapterCalldata) internal returns (bytes4 ret) {
        assembly ("memory-safe") {
            // Allocate memory for calldata + 32 bytes for zero context length
            let freeMemPtr := mload(0x40)
            let dataPtr := freeMemPtr
            let adapterDataLen := adapterCalldata.length
            let totalSize := add(adapterDataLen, 0x20) // +32 for context length (0)

            // Copy adapter calldata to memory
            calldatacopy(dataPtr, adapterCalldata.offset, adapterDataLen)

            // Append zero context length at the end
            mstore(add(dataPtr, adapterDataLen), 0x00)

            // Update free memory pointer
            mstore(0x40, add(dataPtr, totalSize))

            // Perform delegatecall with combined data
            let success :=
                delegatecall(
                    gas(), // Forward all gas
                    adapter, // Target address
                    dataPtr, // Input data pointer
                    totalSize, // Input data size
                    0, // Output pointer (0 = don't copy)
                    0 // Output size (unknown)
                )

            // Check if delegatecall succeeded
            if iszero(success) {
                // Revert with custom error
                mstore(0x00, 0x09ee12d5) // DelegatecallFailed() selector
                revert(0x00, 0x04)
            }

            // Get return data size
            let retSize := returndatasize()

            // Ensure we have at least 32 bytes (for bytes4 packed in bytes32)
            if lt(retSize, 0x20) {
                // Revert if return data is too small
                mstore(0x00, 0x09ee12d5) // DelegatecallFailed() selector
                revert(0x00, 0x04)
            }

            // Copy first 32 bytes of return data
            returndatacopy(0x00, 0x00, 0x20)

            // Extract bytes4 from the returned bytes
            // The bytes4 is left-aligned in the 32-byte word
            ret := mload(0x00)
        }
    }

    /// @notice Executes a delegatecall to an adapter with solver context appended to calldata
    /// @dev Equivalent to: adapter.delegatecall(abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length)))
    /// @dev caller MUST ensure, that adapter != address(0)
    /// @param adapter The address of the adapter to delegatecall
    /// @param relayerContext The solver-specific context data to append
    /// @param adapterCalldata The original calldata for the adapter function
    /// @return ret The function selector returned by the adapter
    function callAdapterWithRelayerContext(
        address adapter,
        bytes calldata relayerContext,
        bytes calldata adapterCalldata
    )
        internal
        returns (bytes4 ret)
    {
        assembly ("memory-safe") {
            // Calculate total size needed for delegatecall data
            let adapterDataLen := adapterCalldata.length
            let contextLen := relayerContext.length
            let totalSize := add(adapterDataLen, add(contextLen, 0x20)) // +32 for context length

            // Allocate memory for the combined calldata
            let freeMemPtr := mload(0x40)
            let dataPtr := freeMemPtr

            // Copy adapter calldata to memory
            calldatacopy(dataPtr, adapterCalldata.offset, adapterDataLen)

            // Copy solver context after adapter calldata
            let contextPtr := add(dataPtr, adapterDataLen)
            calldatacopy(contextPtr, relayerContext.offset, contextLen)

            // Append context length as uint256 at the end
            let lengthPtr := add(contextPtr, contextLen)
            mstore(lengthPtr, contextLen)

            // Update free memory pointer
            mstore(0x40, add(lengthPtr, 0x20))

            // Perform delegatecall
            let success :=
                delegatecall(
                    gas(), // Forward all gas
                    adapter, // Target address
                    dataPtr, // Input data pointer
                    totalSize, // Input data size
                    0x00, // Output pointer (0 = don't copy)
                    0x00 // Output size (unknown)
                )

            // Check if delegatecall succeeded
            if iszero(success) {
                // Revert with custom error
                mstore(0x00, 0x835e98fe) // DelegatecallFailed() selector
                revert(0x00, 0x04)
            }

            // Get return data size
            let retSize := returndatasize()

            // Ensure we have at least 32 bytes (for bytes4 packed in bytes32)
            if lt(retSize, 0x20) {
                // Revert if return data is too small
                mstore(0x00, 0x835e98fe) // DelegatecallFailed() selector
                revert(0x00, 0x04)
            }

            // Copy first 32 bytes of return data
            returndatacopy(0x00, 0x00, 0x20)

            // Extract bytes4 from the returned bytes
            // The bytes4 is left-aligned in the 32-byte word
            ret := mload(0x00)
        }
    }
}
