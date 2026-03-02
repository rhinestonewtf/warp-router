// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IStatelessValidator } from "./IStatelessValidator.sol";
import { ResetPeriod } from "the-compact/types/ResetPeriod.sol";
import { Scope } from "the-compact/types/Scope.sol";

/**
 * @dev WebAuthn credential structure for P256 passkey validation
 * Stores the public key coordinates and validation flags for WebAuthn signature verification
 * @param requireUV Whether user verification (UV) is required during authentication
 * @param usePrecompile Whether to use RIP-7212 precompile for P256 verification (if available)
 * @param pubKeyX The X coordinate of the P256 public key
 * @param pubKeyY The Y coordinate of the P256 public key
 */
struct WebAuthnCredential {
    bool requireUV;
    bool usePrecompile;
    uint256 pubKeyX;
    uint256 pubKeyY;
}

interface IEmissary {
    error InvalidNonce();
    // verify a claim. Called from The Compact as part of claim processing.

    function verifyClaim(
        address sponsor, // the sponsor of the claim
        bytes32 digest,
        bytes32 claimHash, // The message hash representing the claim.
        bytes calldata signature,
        bytes12 lockTag
    )
        external
        view
        returns (bytes4); // Must return the function selector.IEmissary

    struct EmissaryConfig {
        uint8 configId;
        address allocator;
        Scope scope;
        ResetPeriod resetPeriod;
        IStatelessValidator validator;
        bytes validatorConfig;
    }

    struct EmissaryEnable {
        bytes allocatorSig;
        bytes userSig;
        uint256 expires;
        uint256 nonce;
        uint256[] allChainIds;
        uint256 chainIndex;
    }
}
