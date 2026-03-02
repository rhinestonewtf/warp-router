// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { ConsumeNonceLib } from "./ConsumeNonceLib.sol";

/**
 * @title IntentExecutorNonceLib
 * @notice Library for managing nonces across different intent executor types
 * @dev This library provides centralized nonce management for intent executors using
 *      distinct storage slots for each executor type to prevent nonce conflicts.
 *
 *      Storage slot calculation follows a deterministic pattern using keccak256 of
 *      descriptive strings, with only the 6 most significant bytes used as base slots
 *      to optimize gas costs while maintaining collision resistance.
 *
 *      Each executor type uses a different base slot:
 *      - Compact: Uses TheCompact protocol for cross-chain intent execution
 *      - Permit2: Uses Uniswap's Permit2 system for gasless token approvals
 *      - Standalone: Direct execution without external protocol dependencies
 */
library IntentExecutorNonceLib {
    /**
     * @dev Base slot for Compact intent executor nonces
     * Derived from: keccak256("IntentExecutor.NonceSlot.Compact")
     * Full hash: 0x7e285120190b5ee6c0c2f3c033f56e41053c0e5465feb7add16c33106d9931fc
     * Using 6 most significant bytes (48 bits): 0x7e285120190b
     *
     * This provides 2^48 possible base values while maintaining collision resistance
     * and optimizing storage access patterns for gas efficiency.
     */
    uint256 internal constant COMPACT_NONCE_SLOT = 0x7e285120190b;

    /**
     * @dev Base slot for Permit2 intent executor nonces
     * Derived from: keccak256("IntentExecutor.NonceSlot.Permit2")
     * Full hash: 0xab6374e82b038c2dcc6bdb966d10f8cfbefdc3c6df3ac046488915a3e18895c0
     * Using 6 most significant bytes (48 bits): 0xab6374e82b03
     *
     * Permit2 executors handle gasless token approvals using EIP-712 signatures,
     * requiring isolated nonce management to prevent replay attacks across
     * different authorization contexts.
     */
    uint256 internal constant PERMIT2_NONCE_SLOT = 0xab6374e82b03;

    /**
     * @dev Base slot for Standalone intent executor nonces
     * Derived from: keccak256("IntentExecutor.NonceSlot.Standalone")
     * Full hash: 0x1974dd592f369e01eb68ebc04729bc8a1cbfb86115de346f943c591cdc8d0a08
     * Using 6 most significant bytes (48 bits): 0x1974dd592f36
     *
     * Standalone executors operate independently without external protocol
     * integration, using direct account-based authorization and nonce management.
     */
    uint256 internal constant STANDALONE_NONCE_SLOT = 0x1974dd592f36;

    /**
     * @notice Computes the storage slot for a Compact intent executor nonce
     * @dev Uses the Compact-specific base slot combined with nonce and account
     *      to create a unique storage location. This prevents nonce collisions
     *      between different executor types and accounts.
     *
     * @param nonce The nonce value to create a slot for
     * @param account The account address that owns the nonce
     * @return slot The computed storage slot for this nonce/account pair
     */
    function compactNonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot) {
        return ConsumeNonceLib._nonceSlot({ baseSlot: COMPACT_NONCE_SLOT, nonce: nonce, account: account });
    }

    /**
     * @notice Computes the storage slot for a Permit2 intent executor nonce
     * @dev Uses the Permit2-specific base slot to ensure nonces for Permit2-based
     *      intents are isolated from other executor types. This is critical for
     *      security as Permit2 signatures have specific replay protection requirements.
     *
     * @param nonce The nonce value to create a slot for
     * @param account The account address that owns the nonce
     * @return slot The computed storage slot for this nonce/account pair
     */
    function permit2NonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot) {
        return ConsumeNonceLib._nonceSlot({ baseSlot: PERMIT2_NONCE_SLOT, nonce: nonce, account: account });
    }

    /**
     * @notice Computes the storage slot for a Standalone intent executor nonce
     * @dev Uses the Standalone-specific base slot for direct execution scenarios
     *      where no external protocols are involved. This provides the cleanest
     *      nonce management for simple multi-chain operations.
     *
     * @param nonce The nonce value to create a slot for
     * @param account The account address that owns the nonce
     * @return slot The computed storage slot for this nonce/account pair
     */
    function standaloneNonceSlot(uint256 nonce, address account) internal pure returns (bytes32 slot) {
        return ConsumeNonceLib._nonceSlot({ baseSlot: STANDALONE_NONCE_SLOT, nonce: nonce, account: account });
    }
}
