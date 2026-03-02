// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title CompactEIP712
 * @notice EIP-712 struct definitions for the Compact cross-chain intent protocol
 * @dev This library defines the core EIP-712 type structures used throughout the protocol.
 *      These structs mirror the type strings used in EIP712TypeHashLib for signature validation.
 *
 *      Key design decisions:
 *      - The legacy `v` parameter has been REMOVED from Mandate and is now encoded in Op.vt
 *      - Op is a wrapper struct containing vt (version+type) and inner Ops[] array
 *      - Target field ordering: recipient, targetChain, fillExpiry, tokenOut (matches TYPEHASH)
 */
library CompactEIP712 {
    /**
     * @notice Root structure for multi-chain compact signatures
     * @dev Contains the sponsor details and array of chain-specific elements
     */
    struct MultichainCompact {
        /// @dev Address sponsoring this compact transaction
        address sponsor;
        /// @dev Unique nonce for replay protection
        uint256 nonce;
        /// @dev Expiration timestamp for compact validity
        uint256 expires;
        /// @dev Array of chain-specific execution elements
        Element[] elements;
    }

    /**
     * @notice Chain-specific element in a multichain compact
     * @dev Each element corresponds to operations on a specific chain
     */
    struct Element {
        /// @dev Arbiter authorized to execute this element
        address arbiter;
        /// @dev Chain ID where this element operates
        uint256 chainId;
        /// @dev Token commitments (locks) for this element
        Lock[] commitments;
    }

    /**
     * @notice Token commitment (lock) structure
     * @dev Represents tokens locked on the origin chain
     */
    struct Lock {
        /// @dev Tag identifying the lock type
        bytes12 lockTag;
        /// @dev Token contract address
        address token;
        /// @dev Amount of tokens locked
        uint256 amount;
    }

    /**
     * @notice Cross-chain execution mandate
     * @dev Contains target execution details and operation specifications.
     *      Note: The legacy `v` parameter (signature mode) has been REMOVED.
     *      Signature mode is now encoded in Op.vt for each operation group.
     */
    struct Mandate {
        /// @dev Target chain execution parameters
        Target target;
        /// @dev Minimum gas required for pre-claim operations
        uint128 minGas;
        /// @dev Operations to execute on the origin chain (with vt encoding)
        Op originOps;
        /// @dev Operations to execute on the destination chain (with vt encoding)
        Op destOps;
        /// @dev Qualifier hash for additional validation parameters
        bytes32 q;
    }

    /**
     * @notice Operation wrapper struct with version and type encoding
     * @dev This struct wraps the inner Ops array with a vt field that encodes:
     *      - Byte 0: Execution type (NONE, Eip712Hash, Calldata, ERC7579, MultiCall)
     *      - Byte 1: Signature validation mode (NONE, EMISSARY, ERC1271, etc.)
     *      - Bytes 2-31: Reserved for future protocol extensions
     *
     *      This design replaces the legacy `v` parameter in Mandate, allowing
     *      each operation group to have its own execution format and signature mode.
     */
    struct Op {
        /// @dev Version + Type field (exec type in byte 0, sig mode in byte 1)
        bytes32 vt;
        /// @dev Array of individual operations
        Ops[] ops;
    }

    /**
     * @notice Individual operation for smart account execution
     * @dev Represents a single contract call with target, value, and calldata
     */
    struct Ops {
        /// @dev Target contract address
        address to;
        /// @dev ETH value to send with the call
        uint256 value;
        /// @dev Encoded function call data
        bytes data;
    }

    /**
     * @notice Target chain execution parameters
     * @dev Specifies where and when tokens should be delivered.
     *      Field ordering matches the TYPEHASH_TARGET constant in EIP712TypeHashLib.
     */
    struct Target {
        /// @dev Recipient address on target chain
        address recipient;
        /// @dev Target chain ID for cross-chain delivery
        uint256 targetChain;
        /// @dev Deadline for filling this target
        uint256 fillExpiry;
        /// @dev Expected output tokens on target chain
        Token[] tokenOut;
    }

    /**
     * @notice Token specification for expected outputs
     * @dev Used in Target to specify expected token deliveries
     */
    struct Token {
        /// @dev Token contract address
        address token;
        /// @dev Token amount
        uint256 amount;
    }
}

