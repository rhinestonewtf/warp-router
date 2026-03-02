// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title Permit2EIP712
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Abstract contract for EIP-712 domain separation and typed data hashing for Permit2 protocol
 * @dev This contract provides the foundation for creating and verifying EIP-712 signatures
 *      specifically for the Permit2 protocol. It handles domain separator computation and
 *      typed data hashing in a gas-efficient manner using assembly optimizations.
 *
 *      The Permit2 protocol uses a simplified EIP-712 domain with only name, chainId, and
 *      verifyingContract fields (no version field), making it distinct from standard EIP-712.
 *
 *      Key features:
 *      - Immutable domain separator caching for the deployment chain
 *      - Support for cross-chain signature validation via dynamic domain separators
 *      - Gas-optimized assembly implementations for hashing operations
 *      - Scratch space utilization to minimize memory allocation
 *
 * @custom:security Domain separators prevent signature replay across chains and contracts
 */
abstract contract Permit2EIP712 {
    /// @notice Hash of the Permit2 protocol name: keccak256("Permit2")
    /// @dev Used in EIP-712 domain separator computation
    bytes32 private constant _NAME_HASH = 0x9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a;

    /// @notice EIP-712 domain type hash for Permit2: keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)")
    /// @dev Note the absence of version field, which differs from standard EIP-712 domains
    bytes32 private constant _PERMIT2_DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866;

    /// @notice The Permit2 contract address for signature verification
    /// @dev Immutable to ensure consistent domain separation throughout contract lifetime
    address private immutable PERMIT2;

    /// @notice Cached domain separator for the deployment chain
    /// @dev Pre-computed at deployment for gas efficiency on the primary chain
    bytes32 internal immutable PERMIT2_DOMAINSEPARATOR;

    /**
     * @notice Initializes the Permit2 EIP-712 domain parameters
     * @dev Caches the domain separator for the deployment chain to save gas on subsequent calls.
     *      The cached separator is used when validating signatures on the same chain where
     *      the contract was deployed.
     *
     * @param permit2 The address of the Permit2 contract for signature verification
     */
    constructor(address permit2) {
        PERMIT2 = permit2;
        PERMIT2_DOMAINSEPARATOR = _permit2DomainSeparator(block.chainid);
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
    function _permit2DomainSeparator() internal view returns (bytes32) {
        return PERMIT2_DOMAINSEPARATOR;
    }

    /**
     * @notice Computes the domain separator for a specific chain ID
     * @dev Dynamically calculates the EIP-712 domain separator for cross-chain signature validation.
     *      This enables verification of signatures created on different chains (notarized signatures).
     *
     *      The domain separator is computed as:
     *      keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, chainId, permit2Address))
     *
     *      Assembly implementation details:
     *      - Uses allocated memory (via mload(0x40)) for the domain struct
     *      - Stores 4 words sequentially: typehash, name, chainId, verifyingContract
     *      - Hashes 128 bytes (0x80) to produce the domain separator
     *
     * @param notarizedChainId The chain ID for which to compute the domain separator
     * @return notarizedDomainSeparator The computed domain separator for the specified chain
     *
     * @custom:gas ~800 gas for computation (keccak256 + memory operations)
     * @custom:security Critical for preventing cross-chain replay attacks
     */
    function _permit2DomainSeparator(uint256 notarizedChainId) internal view returns (bytes32 notarizedDomainSeparator) {
        address permit2 = PERMIT2;

        assembly ("memory-safe") {
            // Retrieve the free memory pointer.
            let m := mload(0x40)

            // Prepare domain data: EIP-712 typehash, name hash, notarizing chain ID,
            // and verifying contract (no version for Permit2).
            mstore(m, _PERMIT2_DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), _NAME_HASH)
            mstore(add(m, 0x40), notarizedChainId)
            mstore(add(m, 0x60), permit2)

            // Derive the domain separator.
            notarizedDomainSeparator := keccak256(m, 0x80)
        }
    }

    /**
     * @notice Computes the EIP-712 typed data hash for a specific chain
     * @dev Creates the final digest for signature verification by combining the domain separator
     *      with the struct hash according to EIP-712 specification.
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
     * @param chainId The chain ID for domain separator computation
     * @return digest The final EIP-712 digest ready for signature verification
     *
     * @custom:gas ~1000 gas (domain separator computation + keccak256)
     * @custom:security The digest binds the signature to a specific chain and contract
     */
    function _permit2HashTypedData(bytes32 structHash, uint256 chainId) internal view returns (bytes32 digest) {
        digest = _permit2DomainSeparator(chainId);

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
     * @notice Computes the EIP-712 typed data hash for the deployment chain
     * @dev Optimized version that uses the cached domain separator for same-chain operations.
     *      This is more gas-efficient than the cross-chain version as it skips domain
     *      separator computation.
     *
     *      Uses the same assembly optimization pattern as the cross-chain version but
     *      with the pre-computed domain separator.
     *
     * @param structHash The hash of the structured data to be signed
     * @return digest The final EIP-712 digest for the deployment chain
     *
     * @custom:gas ~200 gas (just keccak256, no domain computation)
     * @custom:usage Primary function for same-chain signature validation
     */
    function _permit2HashTypedData(bytes32 structHash) internal view returns (bytes32 digest) {
        digest = _permit2DomainSeparator();

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
}
