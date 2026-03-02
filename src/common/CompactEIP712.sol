// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title CompactEIP712
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Abstract contract for EIP-712 domain separation and typed data hashing for The Compact protocol
 * @dev This contract provides the foundation for creating and verifying EIP-712 signatures
 *      specifically for The Compact protocol. Unlike Permit2, The Compact uses the full
 *      EIP-712 domain specification including name, version, chainId, and verifyingContract.
 *
 *      The Compact protocol enables cross-chain intent execution with proper domain separation
 *      to prevent signature replay attacks across different chains and contract deployments.
 *
 *      Key features:
 *      - Full EIP-712 domain with version field (v1)
 *      - Immutable domain separator caching for deployment chain
 *      - Support for notarized (cross-chain) signature validation
 *      - Gas-optimized assembly implementations
 *      - Efficient scratch space usage for digest computation
 *
 * @custom:security Domain separators ensure signatures cannot be replayed across chains or contracts
 * @custom:protocol The Compact uses this for intent-based cross-chain execution
 */
abstract contract CompactEIP712 {
    /// @notice The Compact contract address for signature verification
    /// @dev Immutable to ensure consistent domain separation throughout contract lifetime
    address internal immutable COMPACT;

    /// @notice Cached domain separator for the deployment chain
    /// @dev Pre-computed at deployment for gas efficiency on the primary chain
    bytes32 private immutable COMPACT_DOMAINSEPARATOR;

    /// @notice EIP-712 domain type hash: keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    /// @dev Standard EIP-712 domain with all four fields (includes version unlike Permit2)
    bytes32 internal constant _COMPACT_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @notice Hash of The Compact protocol name: keccak256(bytes("The Compact"))
    /// @dev Used in EIP-712 domain separator computation
    bytes32 internal constant _NAME_HASH = 0x5e6f7b4e1ac3d625bac418bc955510b3e054cb6cc23cc27885107f080180b292;

    /// @notice Hash of the protocol version: keccak256("1")
    /// @dev Version "1" indicates the first iteration of The Compact protocol
    bytes32 internal constant _VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    /**
     * @notice Initializes The Compact EIP-712 domain parameters
     * @dev Caches the domain separator for the deployment chain to save gas on subsequent calls.
     *      The cached separator is used when validating signatures on the same chain where
     *      the contract was deployed.
     *
     * @param compact The address of The Compact contract for signature verification
     */
    constructor(address compact) {
        COMPACT = compact;
        COMPACT_DOMAINSEPARATOR = _compactDomainSeparator(block.chainid);
    }

    /**
     * @notice Returns the cached domain separator for the deployment chain
     * @dev Gas-efficient getter that returns the pre-computed domain separator.
     *      This should be used for same-chain signature validation.
     *
     * @return The domain separator for the chain where this contract was deployed
     *
     * @custom:gas Minimal gas cost as it returns an immutable value
     */
    function _compactDomainSeparator() internal view virtual returns (bytes32) {
        return COMPACT_DOMAINSEPARATOR;
    }

    /**
     * @notice Computes the EIP-712 typed data hash for the deployment chain
     * @dev Creates the final digest for signature verification using the cached domain separator.
     *      This is the primary function for same-chain signature validation.
     *
     *      The digest is computed as:
     *      keccak256("\x19\x01" || domainSeparator || structHash)
     *
     *      Assembly optimization details:
     *      - Uses scratch space (0x00-0x5A) to avoid memory allocation
     *      - Stores "\x19\x01" prefix at 0x18-0x19 (shifted for alignment)
     *      - Places domain separator at 0x1A-0x39
     *      - Places struct hash at 0x3A-0x59
     *      - Hashes 66 bytes (0x42) starting from 0x18
     *      - Clears position 0x3A after use (defensive cleanup)
     *
     * @param structHash The hash of the structured data to be signed
     * @return digest The final EIP-712 digest for the deployment chain
     *
     * @custom:gas ~200 gas (just keccak256, no domain computation)
     * @custom:usage Primary function for validating signatures created on the same chain
     */
    function _compactHashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest) {
        digest = _compactDomainSeparator();
        assembly ("memory-safe") {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /**
     * @notice Computes the EIP-712 typed data hash for a notarized (cross-chain) signature
     * @dev Creates the final digest for cross-chain signature verification by computing
     *      the domain separator for the specified chain.
     *
     *      This enables The Compact protocol to validate signatures that were created
     *      on different chains, essential for cross-chain intent execution.
     *
     *      Uses the same assembly optimization pattern as the same-chain version but
     *      computes the domain separator dynamically for the notarized chain.
     *
     * @param structHash The hash of the structured data to be signed
     * @param notarizedChainId The chain ID where the signature was created
     * @return digest The final EIP-712 digest for cross-chain validation
     *
     * @custom:gas ~1000 gas (domain separator computation + keccak256)
     * @custom:security Critical for validating cross-chain intents in The Compact protocol
     */
    function _compactHashTypedData(bytes32 structHash, uint256 notarizedChainId) internal view virtual returns (bytes32 digest) {
        digest = _compactDomainSeparator(notarizedChainId);
        assembly ("memory-safe") {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /**
     * @notice Computes the domain separator for a specific chain ID
     * @dev Dynamically calculates the EIP-712 domain separator for cross-chain signature validation.
     *      This is essential for The Compact's cross-chain intent execution capabilities.
     *
     *      The domain separator is computed as:
     *      keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chainId, compactAddress))
     *
     *      Assembly implementation details:
     *      - Uses allocated memory (via mload(0x40)) for the domain struct
     *      - Stores 5 words sequentially: typehash, name, version, chainId, verifyingContract
     *      - Hashes 160 bytes (0xA0) to produce the domain separator
     *
     * @param notarizedChainId The chain ID for which to compute the domain separator
     * @return notarizedDomainSeparator The computed domain separator for the specified chain
     *
     * @custom:gas ~900 gas for computation (keccak256 + memory operations)
     * @custom:protocol Used for validating intents created on different chains
     */
    function _compactDomainSeparator(uint256 notarizedChainId) internal view returns (bytes32 notarizedDomainSeparator) {
        address compact = address(COMPACT);

        assembly ("memory-safe") {
            // Retrieve the free memory pointer.
            let m := mload(0x40)

            // Prepare domain data: EIP-712 typehash, name hash, version hash, notarizing chain ID,
            // and verifying contract.
            mstore(m, _COMPACT_DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), _NAME_HASH)
            mstore(add(m, 0x40), _VERSION_HASH)
            mstore(add(m, 0x60), notarizedChainId)
            mstore(add(m, 0x80), compact)

            // Derive the domain separator.
            notarizedDomainSeparator := keccak256(m, 0xa0)
        }
    }
}
