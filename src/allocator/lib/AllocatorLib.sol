// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title AllocatorLib
 * @notice Library for allocator-related functions, including qualification hash computation and allocator data encoding.
 */
library AllocatorLib {
    /* //////////////////////////////////////////////////////////////
                                TYPEHASH
    //////////////////////////////////////////////////////////////*/

    // keccak256("QualifiedClaim(bytes32 claimHash,bytes32 qualificationHash)")
    bytes32 internal constant QUALIFICATION_TYPEHASH = 0xa002e4a5708d4424abeaa7aa762b36027c1c7eb8604af120ad2ddda6f419c071;

    /* //////////////////////////////////////////////////////////////
                                  HASH
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes a qualification hash for a claim.
     * @param claimHash The hash of the claim.
     * @param _qualificationHash The qualification hash to be included.
     * @return hash The resulting qualification hash.
     */
    function qualificationHash(bytes32 claimHash, bytes32 _qualificationHash) internal pure returns (bytes32 hash) {
        bytes32 typehash = QUALIFICATION_TYPEHASH;

        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, typehash) // Store QUALIFICATION_TYPEHASH at offset 0
            mstore(add(m, 0x20), claimHash) // Store claimHash at offset 32
            mstore(add(m, 0x40), _qualificationHash) // Store qualificationHash at offset 32
            hash := keccak256(m, 0x60) // Hash 160 bytes total (5 * 32 bytes)
        }
    }

    /* //////////////////////////////////////////////////////////////
                               ENCODE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Encodes allocator data by combining a qualification hash and a signature.
     * @param signature The signature bytes.
     * @param _qualificationHash The qualification hash to be included.
     * @return allocatorData The encoded allocator data.
     */

    function encodeAllocatorData(bytes calldata signature, bytes32 _qualificationHash) internal pure returns (bytes memory allocatorData) {
        allocatorData = abi.encodePacked(_qualificationHash, signature);
    }
}
