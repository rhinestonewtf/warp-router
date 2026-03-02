// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ITheCompact } from "the-compact/interfaces/ITheCompact.sol";
import { EmissaryStatus } from "the-compact/types/EmissaryStatus.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { ISmartSessionEmissary } from "@rhinestone/compact-utils/src/interfaces/ISmartSessionEmissary.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { AddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/AddressBook.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

/**
 * @title ValidateSignature
 * @notice Abstract contract that provides signature validation capabilities using multiple modes
 * @dev This contract supports various signature validation strategies including:
 *      - Pure ERC-1271 validation for smart contract wallets
 *      - Emissary-based validation for session keys and delegation patterns
 *      - Hybrid modes that attempt multiple validation methods with fallback logic
 *
 *      The contract integrates with TheCompact protocol to lookup authorized emissaries
 *      for a given account and lock tag, enabling complex delegation and session key patterns.
 *
 *      Security considerations:
 *      - Emissary validation requires the emissary to be authorized via TheCompact
 *      - ERC-1271 validation relies on the account's own signature validation logic
 *      - Fallback modes provide flexibility but should be used carefully to avoid bypassing intended restrictions
 */
abstract contract ValidateSignature {
    using SignatureCheckerLib for address;

    /// @notice Thrown when signature verification fails
    error InvalidSignature();

    /// @dev The Compact contract for getting emissary status
    ITheCompact private immutable COMPACT;

    /// @dev The smart session emissary contract address
    ISmartSessionEmissary private immutable SMART_SESSION_EMISSARY;

    /**
     * @notice Initializes the execution signature checker with TheCompact
     * @param compact The Compact contract address for getting emissary status
     * @param smartSessionEmissary The smart session emissary contract address
     */
    constructor(address compact, address smartSessionEmissary) {
        COMPACT = ITheCompact(compact);
        SMART_SESSION_EMISSARY = ISmartSessionEmissary(smartSessionEmissary);
    }

    /**
     * @notice Validates a signature using the specified validation mode
     * @dev This is the main signature validation function that dispatches to different
     *      validation strategies based on the sigMode extracted from the ops parameter.
     *      The function supports both pure modes (single validation method) and hybrid modes
     *      (with fallback logic).
     *
     *      Pure modes:
     *      - ERC1271: Only validates using the account's ERC-1271 implementation
     *      - EMISSARY: Only validates using emissary's verifyClaim method
     *      - EMISSARY_EXECUTION: Only validates using emissary's verifyExecution method
     *
     *      Hybrid modes with fallback:
     *      - EMISSARY_ERC1271: Try emissary validation first, fallback to ERC-1271
     *      - ERC1271_EMISSARY: Try ERC-1271 first, fallback to emissary validation
     *      - EMISSARYEXECUTION_ERC1271: Try emissary execution validation first, fallback to ERC-1271
     *      - ERC1271_EMISSARYEXECUTION: Try ERC-1271 first, fallback to emissary execution validation
     *
     * @param account The account address that should authorize this signature
     * @param lockTag The lock identifier used for emissary lookups in TheCompact
     * @param digest The EIP-712 digest of the data being signed (used for ERC-1271 validation)
     * @param claimHash The hash of the claim being validated (used for emissary validation)
     * @param ops The operation struct containing the signature mode and execution data
     * @param signature The signature data to validate
     * @return validSig True if the signature is valid according to the specified mode
     * @custom:security Each validation mode has different security properties:
     *                  - ERC-1271 relies on the account's own validation logic
     *                  - Emissary modes require the emissary to be authorized in TheCompact
     *                  - Fallback modes may allow validation even if the primary method fails
     */
    // solhint-disable-next-line code-complexity
    function _isValidSignature(
        address account,
        bytes12 lockTag,
        bytes32 digest,
        bytes32 claimHash,
        Types.Operation calldata ops,
        bytes calldata signature
    )
        internal
        returns (bool validSig)
    {
        SmartExecutionLib.SigMode sigMode = SmartExecutionLib.extractSigMode(ops);

        // Handle pure ERC-1271 validation mode
        if (sigMode == SmartExecutionLib.SigMode.ERC1271) {
            // Uses the account's own ERC-1271 isValidSignature implementation
            // This is suitable for smart contract wallets that implement their own signature logic
            return _verifyWithERC1271(account, digest, signature);
        }

        // Handle pure emissary claim validation mode
        if (sigMode == SmartExecutionLib.SigMode.EMISSARY) {
            // Uses the emissary's verifyClaim method for session key or delegation validation
            // The emissary must be authorized for this account and lockTag in TheCompact
            return _verifyClaimWithEmissary(account, lockTag, digest, claimHash, signature);
        }

        // Handle emissary-first hybrid mode with ERC-1271 fallback
        if (sigMode == SmartExecutionLib.SigMode.EMISSARY_ERC1271) {
            // Prioritizes emissary validation, useful when session keys are preferred
            // but the account should still be able to directly authorize transactions
            validSig = _verifyClaimWithEmissary(account, lockTag, digest, claimHash, signature);
            if (!validSig) {
                // Fallback to ERC-1271 if emissary validation fails
                // This allows the account owner to bypass session restrictions when needed
                validSig = _verifyWithERC1271(account, digest, signature);
            }
            return validSig;
        }

        // Handle ERC-1271-first hybrid mode with emissary fallback
        if (sigMode == SmartExecutionLib.SigMode.ERC1271_EMISSARY) {
            // Prioritizes account's own validation, useful for accounts that primarily
            // self-authorize but have backup session key capabilities
            validSig = _verifyWithERC1271(account, digest, signature);
            if (!validSig) {
                // Fallback to emissary if direct validation fails
                // This allows session keys to work even if the account's validation is restrictive
                validSig = _verifyClaimWithEmissary(account, lockTag, digest, claimHash, signature);
            }
            return validSig;
        }

        // Handle pure emissary execution validation mode
        if (sigMode == SmartExecutionLib.SigMode.EMISSARY_EXECUTION) {
            // Uses emissary's verifyExecution method which validates both signature and execution context
            // This mode is more secure as the emissary can enforce execution-specific restrictions
            return _verifyExecutionWithEmissary(account, digest, signature, ops);
        }

        // Handle emissary execution-first hybrid mode with ERC-1271 fallback
        if (sigMode == SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271) {
            // Prioritizes execution-aware emissary validation for fine-grained control
            // Falls back to simple signature validation if emissary rejects
            validSig = _verifyExecutionWithEmissary(account, digest, signature, ops);
            if (!validSig) {
                // Fallback to ERC-1271 - note this loses execution context validation
                // The account's ERC-1271 implementation should be aware of this limitation
                validSig = _verifyWithERC1271(account, digest, signature);
            }
            return validSig;
        }

        // Handle ERC-1271-first hybrid mode with emissary execution fallback
        if (sigMode == SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION) {
            // Prioritizes account's own validation, useful for accounts with sophisticated
            // built-in execution validation that should take precedence over session keys
            validSig = _verifyWithERC1271(account, digest, signature);
            if (!validSig) {
                // Fallback to execution-aware emissary validation
                validSig = _verifyExecutionWithEmissary(account, digest, signature, ops);
            }
            return validSig;
        }

        // If we reach here, an unsupported sigMode was provided
        // This should not happen in normal operation and indicates a programming error
        return false;
    }

    /**
     * @notice Validates a signature using an emissary's execution-aware verification
     * @dev This method provides the most comprehensive validation by giving the emissary
     *      full context about both the signature and the operations being executed.
     *      The emissary can enforce fine-grained policies such as:
     *      - Restricting which contracts can be called
     *      - Limiting transaction values or gas usage
     *      - Enforcing time-based restrictions
     *      - Validating complex business logic
     *
     *      The verification process:
     *      1. Calls the smart session emissary's verifyExecution method with full execution context
     *      2. Validates that the emissary returns the correct selector (indicating approval)
     *
     * @param account The account address that authorized the emissary
     * @param digest The EIP-712 digest of the data being signed
     * @param signature The signature data (format depends on emissary implementation)
     * @param ops Types.Operation to verify
     * @return valid True if the emissary approves both the signature and execution context
     * @custom:gas This method may be more gas-intensive than simple signature validation
     *             as it allows the emissary to perform complex validation logic.
     */
    function _verifyExecutionWithEmissary(
        address account,
        bytes32 digest,
        bytes calldata signature,
        Types.Operation calldata ops
    )
        private
        returns (bool valid)
    {
        // Call the Smart session emissary's verifyExecution method and validate the return value
        // The emissary must return its own function selector to indicate approval
        // This pattern prevents accidental approval from functions that return true/false
        // Use try-catch to handle emissaries that don't implement this function
        try SMART_SESSION_EMISSARY.verifyExecution(account, digest, signature, ops) returns (bytes4 selector) {
            valid = selector == ISmartSessionEmissary.verifyExecution.selector;
        } catch {
            // If the call fails (e.g., function not implemented), return false
            // This allows graceful handling of emissaries that don't support execution validation
            valid = false;
        }
    }

    /**
     * @notice Validates a signature using the ERC-1271 standard
     * @dev This method delegates signature validation to the account's own isValidSignature
     *      implementation. This is the standard way to validate signatures for smart contract
     *      wallets and accounts that implement custom signature logic.
     *
     *      The validation is performed using Solady's SignatureCheckerLib which:
     *      - First checks if the account is a contract
     *      - If it's a contract, calls the ERC-1271 isValidSignature method
     *      - If it's an EOA, performs ECDSA signature recovery and comparison
     *      - Handles various signature formats and edge cases
     *
     * @param account The account address whose signature should be validated
     * @param digest The hash that was signed (typically a claim hash or message hash)
     * @param signature The signature bytes to validate against the hash
     * @return valid True if the signature is valid according to ERC-1271 or ECDSA verification
     * @custom:security This method trusts the account's own signature validation logic.
     *                  Malicious contracts could return true for invalid signatures.
     * @custom:gas Uses Solady's optimized implementation for efficient validation.
     */
    function _verifyWithERC1271(address account, bytes32 digest, bytes calldata signature) private view returns (bool valid) {
        // Use Solady's SignatureCheckerLib for robust ERC-1271 validation
        // This handles both contract wallets (via ERC-1271) and EOAs (via ECDSA)
        // The "NowCalldata" variant is gas-optimized for calldata signatures
        valid = account.isValidSignatureNowCalldata(digest, signature);
    }

    /**
     * @notice Validates a signature using an emissary's claim verification method
     * @dev This method is used for session key validation where the emissary acts as
     *      a delegated signer for specific claims. Unlike verifyExecution, this method
     *      only validates the signature against a claim hash, without considering the
     *      execution context. This is suitable for:
     *      - Simple session key authorization
     *      - Delegation patterns where execution validation is handled elsewhere
     *      - Claims that don't require execution-specific validation
     *
     *      The verification process:
     *      1. Looks up the authorized emissary for the account/lockTag pair
     *      2. Calls the emissary's verifyClaim method with claim context
     *      3. Validates that the emissary returns the correct selector
     *
     * @param expectedSigner The account address that should have authorized this claim
     * @param lockTag The lock identifier used to lookup the emissary in TheCompact
     * @param digest The EIP-712 digest of the original signed data
     * @param claimHash The hash of the specific claim being validated
     * @param signature The signature data (format depends on emissary implementation)
     * @return valid True if the emissary validates the claim signature
     * @custom:security The emissary must be authorized in TheCompact. No fallback validation
     *                  is performed if the emissary is not found.
     */
    function _verifyClaimWithEmissary(
        address expectedSigner,
        bytes12 lockTag,
        bytes32 digest,
        bytes32 claimHash,
        bytes calldata signature
    )
        private
        view
        returns (bool valid)
    {
        // Query TheCompact to find the authorized emissary for this signer and lock tag
        // This ensures only properly authorized emissaries can validate claims
        address emissary;
        try ITheCompact(COMPACT).getEmissaryStatus(expectedSigner, lockTag) returns (EmissaryStatus, uint256, address _emissary) {
            emissary = _emissary;
        } catch {
            // If the call fails, return false
            return false;
        }

        // Security: fail immediately if no emissary is authorized
        // This prevents any unauthorized claim validation
        if (emissary == address(0)) return false;

        // Call the emissary's verifyClaim method and check for the correct return selector
        // The selector-based validation ensures the emissary explicitly approves the claim
        // rather than accidentally returning a truthy value
        // Use try-catch to handle emissaries that don't implement this function
        try IEmissary(emissary).verifyClaim(expectedSigner, digest, claimHash, signature, lockTag) returns (bytes4 selector) {
            valid = selector == IEmissary.verifyClaim.selector;
        } catch {
            // If the call fails (e.g., function not implemented), return false
            // This allows graceful handling of emissaries that don't support claim validation
            valid = false;
        }
    }
}
