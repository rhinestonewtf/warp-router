// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Compressed } from "./CompressedStorageLib.sol";
import { WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";

/**
 * @title EmissaryStorageLib
 * @notice Library for computing storage slots and performing low-level storage operations for Emissary
 * @dev This library uses assembly for gas-efficient storage slot derivation and direct storage access.
 * It implements a collision-resistant storage slot scheme by hashing multiple parameters together.
 *
 * Storage slot calculation uses a base slot combined with sponsor, configId, lockTag, and validator
 * to ensure unique storage locations across all Emissary configurations.
 */
library EmissaryStorageLib {
    error NotSet();

    /**
     * @dev Base slot for Emissary config storage
     * Derived from: keccak256("Emissary.StorageSlot.Config")
     * Full hash: 0x86f750d6ba7a384ce70cb2fd5989007de5d38fd9606c07e52f64aeb3eaa2f447
     * Using 6 most significant bytes (48 bits): 0x86f750d6ba7a
     *
     * This base slot is combined with sponsor, configId, lockTag, and validator parameters
     * to create unique storage locations for each configuration, preventing collisions
     * between different Emissary instances and other protocol storage.
     */
    uint256 internal constant EMISSARY_CONFIG_BASE_SLOT = 0x86f750d6ba7a;

    /**
     * @dev Base slot for Emissary nonce storage
     * Derived from: keccak256("Emissary.StorageSlot.Nonce")
     * Full hash: 0x95198fc29028bf37f01b49da35e2a93273ed28197c2094acd14f7de81c3c558f
     * Using 6 most significant bytes (48 bits): 0x95198fc29028
     *
     * This base slot is combined with sponsor and lockTag to create unique nonce
     * storage locations for replay protection, isolated from config storage.
     */
    uint256 internal constant EMISSARY_NONCE_BASE_SLOT = 0x95198fc29028;

    /**
     * @notice Computes the storage slot for a validator configuration
     * @dev Storage slot derivation uses keccak256 of base slot combined with parameters:
     * slot = keccak256(EMISSARY_BASE_SLOT || sponsor || configId || lockTag || validator)
     *
     * The base slot ensures Emissary storage is isolated from other protocol components.
     * Each unique combination of parameters gets a unique storage location:
     * - sponsor account (who owns the config)
     * - configId (allows multiple configs per validator)
     * - lockTag (derived from allocator + scope + resetPeriod)
     * - validator address (ECDSA_VALIDATOR, PASSKEY_VALIDATOR, or custom)
     *
     * @param sponsor The sponsor account address (20 bytes)
     * @param configId The configuration type identifier (1 byte)
     * @param lockTag The lock tag from allocator parameters (12 bytes)
     * @param validator The validator address (20 bytes)
     * @return slot The computed storage slot (32 bytes)
     * @custom:gas Uses assembly for optimal gas efficiency (avoids ABI encoding overhead)
     */
    function configSlot(address sponsor, uint8 configId, bytes12 lockTag, address validator) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, EMISSARY_CONFIG_BASE_SLOT) // Store base slot at offset 0
            mstore(add(m, 0x20), sponsor) // Store sponsor at offset 32 (left-padded to 32 bytes)
            mstore(add(m, 0x40), configId) // Store configId at offset 64 (left-padded to 32 bytes)
            mstore(add(m, 0x60), lockTag) // Store lockTag at offset 96 (left-padded to 32 bytes)
            mstore(add(m, 0x80), validator) // Store validator at offset 128 (left-padded to 32 bytes)
            slot := keccak256(m, 0xa0) // Hash 160 bytes total (5 * 32 bytes)
        }
    }

    /**
     * @notice Computes the storage slot for a nonce value
     * @dev Nonces are used for replay protection during config updates.
     * slot = keccak256(EMISSARY_NONCE_BASE_SLOT || sponsor || lockTag)
     *
     * The base slot ensures nonce storage is isolated from config storage.
     * Each sponsor+lockTag pair has its own nonce counter that must increase
     * monotonically with each config update to prevent:
     * - Replay attacks (reusing old signed config updates)
     * - Reordering attacks (applying updates out of intended order)
     *
     * @param sponsor The sponsor account address (20 bytes)
     * @param lockTag The lock tag from allocator parameters (12 bytes)
     * @return slot The computed storage slot for the nonce (32 bytes)
     * @custom:gas Uses assembly for optimal gas efficiency
     */
    function nonceSlot(address sponsor, bytes12 lockTag) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, EMISSARY_NONCE_BASE_SLOT) // Store base slot at offset 0
            mstore(add(m, 0x20), sponsor) // Store sponsor at offset 32 (left-padded to 32 bytes)
            mstore(add(m, 0x40), lockTag) // Store lockTag at offset 64 (left-padded to 32 bytes)
            slot := keccak256(m, 0x60) // Hash 96 bytes total (3 * 32 bytes)
        }
    }

    /**
     * @notice Loads an address from storage and reverts if it's not set
     * @dev Reads the address value from the given storage slot and validates it's non-zero.
     * Used when we expect a value to exist and want to fail explicitly if it doesn't.
     * @param slot The storage slot to read from
     * @return value The address stored at the slot
     * @custom:reverts NotSet if the stored address is address(0)
     */
    function loadAddress(bytes32 slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := sload(slot)
        }
        require(value != address(0), NotSet());
    }

    /**
     * @notice Loads an address from storage without validation
     * @dev Reads the address value from the given storage slot, allowing address(0).
     * Used during initialization checks where address(0) indicates uninitialized state.
     * @param slot The storage slot to read from
     * @return value The address stored at the slot (may be address(0))
     */
    function loadAddressUnchecked(bytes32 slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := sload(slot)
        }
    }

    /**
     * @notice Loads a uint256 value from storage
     * @dev Reads a uint256 from the given storage slot. Used for nonce loading.
     * Returns 0 for uninitialized slots, which is the expected behavior for nonces.
     * @param slot The storage slot to read from
     * @return value The uint256 value stored at the slot
     */
    function loadUint256(bytes32 slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := sload(slot)
        }
    }

    /**
     * @notice Returns a storage pointer to compressed bytes data
     * @dev Creates a storage reference to a Compressed.Bytes struct at the given slot.
     * This is a pure function that only manipulates the storage pointer, not actual storage.
     * The returned pointer can be used with CompressedStorageLib operations.
     * @param slot The storage slot where compressed bytes are stored
     * @return config A storage pointer to the Compressed.Bytes at the slot
     */
    function loadCompressedBytes(bytes32 slot) internal pure returns (Compressed.Bytes storage config) {
        assembly ("memory-safe") {
            config.slot := slot
        }
    }

    /**
     * @notice Returns a storage pointer to WebAuthn credentials
     * @dev Creates a storage reference to a WebAuthnCredential struct at the given slot.
     * This is a pure function that only manipulates the storage pointer, not actual storage.
     * The credentials include P256 public key coordinates and validation flags.
     * @param slot The storage slot where credentials are stored
     * @return creds A storage pointer to the WebAuthnCredential at the slot
     */
    function loadPasskeyCredentials(bytes32 slot) internal pure returns (WebAuthnCredential storage creds) {
        assembly ("memory-safe") {
            creds.slot := slot
        }
    }

    /**
     * @notice Stores an address value to the specified storage slot
     * @dev Directly writes the address to storage using SSTORE.
     * @param slot The storage slot to write to
     * @param value The address value to store
     */
    function storeAddress(bytes32 slot, address value) internal {
        assembly ("memory-safe") {
            sstore(slot, value)
        }
    }

    /**
     * @notice Stores a uint256 value to the specified storage slot
     * @dev Directly writes the uint256 to storage using SSTORE.
     * This is an alias for storeUint256 for consistency.
     * @param slot The storage slot to write to
     * @param value The uint256 value to store
     */
    function setUint256(bytes32 slot, uint256 value) internal {
        assembly ("memory-safe") {
            sstore(slot, value)
        }
    }

    /**
     * @notice Stores a uint256 value to the specified storage slot
     * @dev Directly writes the uint256 to storage using SSTORE.
     * Used primarily for nonce updates.
     * @param slot The storage slot to write to
     * @param value The uint256 value to store
     */
    function storeUint256(bytes32 slot, uint256 value) internal {
        assembly ("memory-safe") {
            sstore(slot, value)
        }
    }
}
