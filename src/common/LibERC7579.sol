// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";

library LibERC7579 {
    using LibERC7579 for *;

    /// @dev Single execution mode (0x00 << 248)
    bytes32 internal constant SINGLE_MODE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    /// @dev Batch execution mode (0x01 << 248)
    bytes32 internal constant BATCH_MODE = 0x0100000000000000000000000000000000000000000000000000000000000000;

    /// @dev Decodes a batch.
    /// Reverts if `executionData` is not correctly encoded.

    /// @dev Decodes a batch without bounds checks.
    /// This function can be used in `execute`, if the validation phase has already
    /// decoded the `executionData` with checks via `decodeBatch`.
    function decodeBatchUnchecked(bytes calldata executionData) internal pure returns (bytes32[] calldata pointers) {
        /// @solidity memory-safe-assembly
        assembly ("memory-safe") {
            let o := add(executionData.offset, calldataload(executionData.offset))
            pointers.offset := add(o, 0x20)
            pointers.length := calldataload(o)
        }
    }

    /**
     * @dev Executes a Types.Operation on an ERC7579 account by extracting pre-encoded execution data
     * @param account The ERC7579 account to execute on
     * @param ops The operation containing pre-encoded execution data in ops.data
     *
     * @notice This function extracts execution data from ops.data[2:] (skipping the first 2 bytes)
     * and delegates to executeEncoded for gas-optimized execution. The first 2 bytes are typically
     * used for operation metadata/flags and are stripped before passing to executeFromExecutor.
     *
     * @dev This is part of the gas optimization strategy - instead of decoding the entire
     * Types.Operation struct and re-encoding it, we directly extract the relevant execution
     * data portion and use it with executeEncoded.
     */
    function executeOps(address account, Types.Operation calldata ops) internal {
        executeEncoded(account, ops.data[SmartExecutionLib.OFFSET_EXEC_DATA:]).bubbleRevert();
    }

    /**
     * @dev Executes a single ETH transfer on an ERC7579 account
     * @param account The ERC7579 account to execute on
     * @param target The recipient address
     * @param value The ETH value to send
     */
    function executeSingleETHTransfer(address account, address target, uint256 value) internal {
        _executeSingleETHTransfer(account, target, value).bubbleRevert();
    }

    /**
     * @dev Executes a Types.Operation on an ERC7579 account by extracting pre-encoded execution data
     * @param account The ERC7579 account to execute on
     * @param ops The operation containing pre-encoded execution data in ops.data
     *
     * @notice This function extracts execution data from ops.data[2:] (skipping the first 2 bytes)
     * and delegates to executeEncoded for gas-optimized execution. The first 2 bytes are typically
     * used for operation metadata/flags and are stripped before passing to executeFromExecutor.
     *
     * @dev This is part of the gas optimization strategy - instead of decoding the entire
     * Types.Operation struct and re-encoding it, we directly extract the relevant execution
     * data portion and use it with executeEncoded.
     */
    function tryExecuteOps(address account, Types.Operation calldata ops) internal returns (bool success) {
        return executeEncoded(account, ops.data[SmartExecutionLib.OFFSET_EXEC_DATA:]);
    }

    /**
     * @dev Executes pre-encoded execution data on an ERC7579 account via executeFromExecutor
     * @param account The ERC7579 account to execute on
     * @param encodedExec Pre-encoded execution data (already in correct format for executeFromExecutor)
     *
     * @notice This is a gas optimization that avoids decoding/re-encoding Types.Operation
     * Instead of decoding a Types.Operation struct and re-encoding it for executeFromExecutor,
     * this function directly uses pre-encoded data, saving significant gas costs by eliminating
     * the decode/encode round-trip that would otherwise be required.
     *
     * The function constructs the call to executeFromExecutor(mode, executionData) where:
     * - mode: BATCH_MODE (0x01 << 248) constant for batch execution
     * - executionData: The pre-encoded execution data passed as encodedExec
     *
     * @dev Uses inline assembly for maximum gas efficiency when constructing the call
     */
    function executeEncoded(address account, bytes calldata encodedExec) internal returns (bool success) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            // Store function selector (executeFromExecutor)
            mstore(ptr, 0xd691c96400000000000000000000000000000000000000000000000000000000)

            // Store mode using constant (saves gas vs runtime calculation)
            mstore(add(ptr, 4), BATCH_MODE)

            // Store offset to execution data (0x40)
            mstore(add(ptr, 36), 0x40)

            // Store length of execution data
            mstore(add(ptr, 68), encodedExec.length)

            // Copy execution data directly from calldata
            calldatacopy(add(ptr, 100), encodedExec.offset, encodedExec.length)

            success := call(gas(), account, 0, ptr, add(100, encodedExec.length), 0, 0)
        }
    }

    /**
     * @dev Executes a single ETH transfer on an ERC7579 account via executeFromExecutor
     * @param account The ERC7579 account to execute on
     * @param target The recipient address
     * @param value The ETH value to send
     *
     * @notice Uses ERC7579 packed format for single execution:
     *         - executionData = target (20 bytes) || value (32 bytes) || callData (0 bytes for ETH transfer)
     */
    function _executeSingleETHTransfer(address account, address target, uint256 value) private returns (bool success) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            // Store function selector (executeFromExecutor)
            mstore(ptr, 0xd691c96400000000000000000000000000000000000000000000000000000000)

            // Store SINGLE_MODE (0x00)
            mstore(add(ptr, 4), SINGLE_MODE)

            // Store offset to execution data (0x40)
            mstore(add(ptr, 36), 0x40)

            // Execution data length for single ETH transfer: 0x34 (52 bytes)
            // 20 (target packed) + 32 (value) + 0 (empty callData)
            mstore(add(ptr, 68), 0x34)

            // Store target as packed 20 bytes (shift left by 96 bits to align to start)
            mstore(add(ptr, 100), shl(96, target))

            // Store value (32 bytes starting at ptr+120)
            mstore(add(ptr, 120), value)

            // Total calldata: 4 (selector) + 32 (mode) + 32 (offset) + 32 (length) + 52 (data) = 152 bytes
            success := call(gas(), account, 0, ptr, 152, 0, 0)
        }
    }

    function bubbleRevert(bool success) internal pure {
        assembly ("memory-safe") {
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
