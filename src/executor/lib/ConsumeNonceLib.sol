// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title ConsumeNonceLib
 * @notice Library for atomic nonce consumption with replay protection
 * @dev This library provides gas-optimized nonce management for intent execution systems.
 *      It implements atomic check-and-set operations to prevent replay attacks across
 *      different intent execution mechanisms.
 *
 *      Key features:
 *      - Atomic nonce consumption (check + mark as used in single operation)
 *      - Gas-optimized assembly implementation
 *      - Consistent storage slot computation across all intent executors
 *      - Deterministic slot generation based on base slot, account, and nonce
 *
 *      Storage Layout:
 *      Each executor type uses a different base slot to avoid collisions
 *      Slot computation: keccak256(baseSlot || account || nonce)
 *      Storage value: 0 = unused, 1 = consumed
 *
 * @custom:security Critical for replay protection - any vulnerability here could allow
 *                  replay attacks across the entire intent execution system
 */
library ConsumeNonceLib {
    /// @notice Thrown when attempting to use a nonce that has already been consumed
    error NonceAlreadyUsed();

    /**
     * @notice Atomically consumes a nonce for replay protection
     * @dev Performs an atomic check-and-set operation:
     *      1. Loads the current value from storage
     *      2. If already set (value == 1), reverts with NonceAlreadyUsed
     *      3. If not used (value == 0), marks as used by storing 1
     *
     *      Uses assembly for gas optimization and to perform the operation atomically.
     *      The error selector 0x21f123e1 corresponds to NonceAlreadyUsed().
     *
     * @param slot The storage slot containing the nonce usage flag
     *
     * @custom:gas Assembly implementation saves gas by avoiding Solidity overhead
     *             and performing the check-and-set atomically
     */
    function consumeNonce(bytes32 slot) internal {
        assembly ("memory-safe") {
            let s := sload(slot) // Load current nonce state
            if eq(s, 1) {
                // Check if already used
                let ptr := mload(0x40) // Get free memory pointer
                mstore(ptr, 0x21f123e1) // Store NonceAlreadyUsed() selector
                revert(ptr, 4) // Revert with error selector
            }

            sstore(slot, 1) // Mark nonce as used
        }
    }

    /**
     * @notice Computes deterministic storage slot for nonce tracking
     * @dev Creates a unique storage slot for each (baseSlot, account, nonce) combination.
     *      The computation ensures:
     *      - Different executor types don't interfere (different base slots)
     *      - Each account has isolated nonce spaces
     *      - Each nonce maps to a unique slot
     *
     *      Slot = keccak256(baseSlot || account || nonce)
     *
     * @param baseSlot The base storage slot specific to each executor type
     * @param nonce The nonce value to create a slot for
     * @param account The account address that owns this nonce
     * @return slot The computed storage slot for this nonce
     *
     * @custom:gas Pure function with assembly optimization for gas efficiency
     */
    function _nonceSlot(uint256 baseSlot, uint256 nonce, address account) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, baseSlot) // Store base slot at memory location
            mstore(add(m, 0x20), account) // Store account at offset 0x20
            mstore(add(m, 0x40), nonce) // Store nonce at offset 0x40
            slot := keccak256(m, 0x60) // Hash 96 bytes (3 * 32 bytes)
        }
    }

    function isConsumed(bytes32 slot) internal view returns (bool consumed) {
        assembly ("memory-safe") {
            consumed := sload(slot) // Load current nonce state
        }
    }
}
