// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;
import { WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";

/**
 * @title EmissaryLib
 * @notice Library for packing and unpacking emissary data format
 * @dev EmissaryData format: [validator(20)][configId(1)][signatureData(variable)]
 *
 * The emissaryData encoding contains three components:
 * 1. Validator address (20 bytes) - Determines validation mode (ECDSA, Passkey, or custom)
 * 2. Config ID (1 byte) - Identifies which config to use for this validator
 * 3. Signature data (variable length) - Validator-specific signature payload
 *
 * This format allows:
 * - Multiple configs per validator address (via different configIds)
 * - Compact encoding for gas efficiency
 * - Clear separation between routing info (validator+configId) and signature data
 */
library EmissaryLib {
    /**
     * @notice Unpacks emissary data into its component parts
     * @dev Extracts validator address, config ID, and signature data from packed bytes
     *
     * Format breakdown:
     * - Bytes [0:20]: Validator address (determines ECDSA/Passkey/Custom mode)
     * - Byte [20]: Config ID (allows multiple configs per validator)
     * - Bytes [21:]: Signature data (format depends on validator type)
     *
     * @param emissaryData The packed emissary data bytes
     * @return validator The validator address extracted from bytes [0:20]
     * @return configId The config ID extracted from byte [20]
     * @return signatureData The remaining bytes [21:] containing validator-specific signature
     *
     * @custom:example
     * For ECDSA: signatureData is raw ECDSA signature (v,r,s format)
     * For Passkey: signatureData is ABI-encoded WebAuthn.WebAuthnAuth struct
     * For Custom: signatureData format is defined by the custom validator
     */
    function unpack(bytes calldata emissaryData) internal pure returns (address validator, uint8 configId, bytes calldata signatureData) {
        // Extract validator address from first 20 bytes
        validator = address(bytes20(emissaryData[:20]));

        // Extract config ID from byte 20
        configId = uint8(bytes1(emissaryData[20:21]));

        // Extract signature data from remaining bytes (21 onwards)
        signatureData = emissaryData[21:];
    }

    /**
     * @notice Packs validator address, config ID, and signature data into emissary data format
     * @dev Concatenates the three components into the standard emissary data format
     *
     * This function creates the packed format expected by verifyClaim:
     * [validator address][config ID][signature data]
     *
     * @param validator The validator address (20 bytes) - determines validation mode
     * @param configId The config ID (1 byte) - identifies which config to use
     * @param signatureData The validator-specific signature data (variable length)
     * @return emissaryData The packed bytes in emissary data format
     *
     * @custom:usage This is typically used when constructing claims that will be verified
     * via the Emissary contract's verifyClaim function
     */
    function pack(address validator, uint8 configId, bytes memory signatureData) internal pure returns (bytes memory emissaryData) {
        emissaryData = abi.encodePacked(validator, configId, signatureData);
    }

    function pack(WebAuthnCredential memory passkeyAuth) internal pure returns (bytes memory packed) {
        return abi.encodePacked(passkeyAuth.requireUV, passkeyAuth.usePrecompile, passkeyAuth.pubKeyX, passkeyAuth.pubKeyY);
    }

    /**
     * @notice Unpacks bytes into WebAuthnCredential components
     * @dev Extracts the four fields from packed bytes created by pack(WebAuthnCredential)
     *
     * Format breakdown:
     * - Byte [0]: requireUV (bool)
     * - Byte [1]: usePrecompile (bool)
     * - Bytes [2:34]: pubKeyX (uint256)
     * - Bytes [34:66]: pubKeyY (uint256)
     *
     * @param packed The packed WebAuthnCredential bytes (66 bytes total)
     * @return requireUV Whether user verification is required
     * @return usePrecompile Whether to use precompile for verification
     * @return pubKeyX The X coordinate of the public key
     * @return pubKeyY The Y coordinate of the public key
     */
    function unpackWebAuthnCredential(bytes calldata packed)
        internal
        pure
        returns (bool requireUV, bool usePrecompile, uint256 pubKeyX, uint256 pubKeyY)
    {
        // Extract requireUV from byte 0
        requireUV = uint8(bytes1(packed[0:1])) != 0;

        // Extract usePrecompile from byte 1
        usePrecompile = uint8(bytes1(packed[1:2])) != 0;

        // Extract pubKeyX from bytes 2:34
        pubKeyX = uint256(bytes32(packed[2:34]));

        // Extract pubKeyY from bytes 34:66
        pubKeyY = uint256(bytes32(packed[34:66]));
    }
}
