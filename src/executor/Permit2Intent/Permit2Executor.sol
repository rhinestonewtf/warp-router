// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IPermit2IntentExecutor } from "../interfaces/IPermit2Intent.sol";
import { ICompactIntentExecutor } from "../interfaces/ICompactIntent.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { IntentExecutorNonceLib } from "../lib/IntentExecutorNonceLib.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ConsumeNonceLib } from "../lib/ConsumeNonceLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { IntentExecutorBase } from "../IntentExecutorBase.sol";
import { ValidateSignature } from "@rhinestone/compact-utils/src/executor/VerifySignature/VerifySignature.sol";
import { Permit2EIP712 } from "@rhinestone/compact-utils/src/common/Permit2EIP712.sol";
import { LibERC7579 } from "@rhinestone/compact-utils/src/common/LibERC7579.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

/**
 * @title Permit2IntentExecutor
 * @notice Executor contract for intents using Permit2 for gasless token approvals
 * @dev This contract enables intent execution leveraging Uniswap's Permit2 system for efficient
 *      token permission management. Key features include:
 *
 *      - Gasless token approvals using EIP-712 structured signatures
 *      - Nonce-based replay protection with efficient storage patterns
 *      - Integration with signature skip functionality for trusted execution
 *      - EIP-1271 signature validation for smart contract accounts
 *
 *      The execution flow:
 *      1. User signs a Permit2-compatible intent with token permissions and operations
 *      2. Arbiter calls executePreClaimOpsWithPermit2Stub to execute pre-claim operations
 *      3. Contract validates the signature against Permit2's domain separator
 *      4. Nonce is consumed to prevent replay attacks
 *      5. Pre-claim operations are executed (e.g., token transfers, swaps)
 *      6. Signature skip permission is granted to the arbiter for subsequent operations
 *
 * @custom:security Critical security considerations:
 *                  - Permit2 domain separator validation prevents cross-protocol signature reuse
 *                  - Nonce consumption provides replay protection at the account level
 *                  - EIP-1271 validation supports both EOA and smart contract signatures
 *                  - Expiration timestamps prevent execution of stale intents
 */
abstract contract Permit2IntentExecutor is IPermit2IntentExecutor, IntentExecutorBase, ValidateSignature, Permit2EIP712 {
    using SignatureCheckerLib for address;
    using IntentExecutorNonceLib for uint256;
    using ConsumeNonceLib for bytes32;
    using SmartExecutionLib for Types.Operation;
    using EIP712TypeHashLib for Types.Operation;

    /**
     * @notice Executes pre-claim operations using Permit2-based authorization
     * @dev This function validates a Permit2-style EIP-712 signature and executes operations
     *      on behalf of the user account. The process includes:
     *
     *      1. Nonce consumption to prevent replay attacks
     *      2. Permit2 hash computation including all operation parameters
     *      3. EIP-712 signature validation using Permit2's domain separator
     *      4. Execution of pre-claim operations (typically token transfers or approvals)
     *      5. Granting signature skip permission to the caller for subsequent operations
     *
     *      Gas optimization: Uses cached domain separator to avoid external calls
     *
     * @param account The user account that signed the intent and will execute operations
     * @param permit2Stub Core Permit2 parameters including nonce and expiration
     * @param mandateStub Mandate-specific parameters including token and operation hashes
     * @param preClaimOps Array of operations to execute on the origin chain
     * @param signature EIP-712 signature from the account authorizing the operations
     * @return permit2Hash The computed Permit2 hash used for signature validation
     *
     * @custom:security The signature validation uses EIP-1271 which supports both EOA signatures
     *                  and smart contract signature validation for maximum compatibility
     */
    function executePreClaimOpsWithPermit2Stub(
        address account,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateStub calldata mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        returns (bytes32 permit2Hash)
    {
        // Consume the nonce to prevent replay attacks - this modifies storage immediately
        permit2Stub.nonce.permit2NonceSlot(account).consumeNonce();

        // Compute the Permit2 hash including all relevant parameters
        permit2Hash = _permit2Hash(permit2Stub, mandateStub, preClaimOps);

        bytes32 digest = _permit2HashTypedData(permit2Hash);

        // Validate the signature
        require(_isValidSignature(account, LOCKTAG, digest, permit2Hash, preClaimOps, signature), InvalidSignature());

        // Execute the pre-claim operations on behalf of the account
        LibERC7579.executeOps(account, preClaimOps);
    }

    /**
     * @notice Executes target operations using Permit2-based authorization
     * @dev This function validates a Permit2-style EIP-712 signature and executes operations
     *      on the destination chain. The process includes:
     *
     *      1. Chain validation to ensure execution on the correct target chain
     *      2. Nonce consumption to prevent replay attacks
     *      3. Permit2 hash computation including all operation parameters
     *      4. EIP-712 signature validation using Permit2's domain separator
     *      5. Execution of target operations (e.g., final asset transfers or swaps)
     *
     *      Gas optimization: Uses cached domain separator to avoid external calls
     *
     * @param account The user account that signed the intent and will execute operations
     * @param permit2Stub Core Permit2 parameters including nonce and expiration
     * @param mandateStub Mandate-specific parameters including token and operation hashes
     * @param targetOps Array of operations to execute on the destination chain
     * @param signature EIP-712 signature from the account authorizing the operations
     * @return permit2Hash The computed Permit2 hash used for signature validation
     *
     * @custom:security The signature validation uses EIP-1271 which supports both EOA signatures
     *                  and smart contract signature validation for maximum compatibility
     */
    function executeTargetOpsWithPermit2Stub(
        address account,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateDestinationStub calldata mandateStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        onlyRouter
        returns (bytes32 permit2Hash)
    {
        // Consume the nonce to prevent replay attacks - this modifies storage immediately
        permit2Stub.nonce.permit2NonceSlot(account).consumeNonce();

        // this reverts if the fill expiration is expired
        // this propagates block.chain id as the target chainID.
        permit2Hash = _permit2Hash(account, permit2Stub, mandateStub, targetOps);

        bytes32 digest = _permit2HashTypedData(permit2Hash, mandateStub.notarizedChainId);
        // Validate the signature
        require(_isValidSignature(account, LOCKTAG, digest, permit2Hash, targetOps, signature), InvalidSignature());

        // Execute the target operations on behalf of the account
        LibERC7579.executeOps(account, targetOps);
    }

    /**
     * @notice Internal function to compute the Permit2 hash for signature validation
     * @dev Constructs the complete Permit2 hash by combining mandate parameters with
     *      Permit2-specific fields. The hash computation follows this structure:
     *
     *      1. Compute mandate hash from target attributes, operation hashes, and q parameters
     *      2. Combine mandate hash with Permit2 fields (token, arbiter, nonce, expiration)
     *      3. Return the final hash for EIP-712 signature validation
     *
     *      The arbiter is set to msg.sender, establishing the caller as the authorized
     *      party for executing this intent.
     *
     * @param permit2Stub Core Permit2 parameters including nonce and expiration time
     * @param mandateStub Mandate-specific parameters including token and operation hashes
     * @param preClaimOps Operations to execute - hashed as part of the mandate
     * @return permit2Hash The computed hash for Permit2 signature validation
     */
    function _permit2Hash(
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateStub calldata mandateStub,
        Types.Operation calldata preClaimOps
    )
        internal
        view
        returns (bytes32 permit2Hash)
    {
        // Compute the mandate hash combining all operation and target parameters
        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: mandateStub.targetAttributesHash,
            minGas: mandateStub.minGas,
            preClaimOpsHash: preClaimOps.hashOps(),
            destOpsHash: mandateStub.destOpsHash,
            qHash: mandateStub.qHash
        });

        // Compute the final Permit2 hash combining mandate with Permit2-specific fields
        permit2Hash = EIP712TypeHashLib.hashPermit2({
            tokenInHash: mandateStub.tokenInHash,
            arbiter: msg.sender, // Caller becomes the authorized arbiter
            nonce: permit2Stub.nonce,
            expires: permit2Stub.expires,
            mandate: mandateHash
        });
    }

    /**
     * @notice Internal function to compute the Permit2 hash for target operations
     * @dev Constructs the complete Permit2 hash by combining mandate parameters with
     *      Permit2-specific fields. The hash computation follows this structure:
     *
     *      1. Compute mandate hash from target attributes, operation hashes, and q parameters
     *      2. Combine mandate hash with Permit2 fields (token, arbiter, nonce, expiration)
     *      3. Return the final hash for EIP-712 signature validation
     *
     *      The arbiter is set to mandateStub.arbiter, establishing the designated arbiter
     *      as the authorized party for executing this intent.
     *
     * @param recipient The Account that received the Permit2 based intent and will execute the targetOps
     * @param permit2Stub Core Permit2 parameters including nonce and expiration time
     * @param mandateStub Mandate-specific parameters including token and operation hashes
     * @param targetOps Operations to execute - hashed as part of the mandate
     * @return permit2Hash The computed hash for Permit2 signature validation
     */
    function _permit2Hash(
        address recipient,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateDestinationStub calldata mandateStub,
        Types.Operation calldata targetOps
    )
        internal
        view
        returns (bytes32 permit2Hash)
    {
        // Ensure the fill operation hasn't expired
        uint256 fillDeadline = mandateStub.targetStub.fillExpiry;
        require(fillDeadline >= block.timestamp, ICompactIntentExecutor.InvalidParams());

        bytes32 targetAttributesHash = EIP712TypeHashLib.hashTargetAttributesRaw({
            recipient: recipient,
            tokenOutHash: mandateStub.targetStub.tokenOutHash,
            targetChainId: block.chainid,
            fillDeadline: fillDeadline
        });

        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttributesHash,
            minGas: mandateStub.minGas,
            preClaimOpsHash: mandateStub.preClaimOpsHash,
            destOpsHash: targetOps.hashOps(),
            qHash: mandateStub.qHash
        });

        // Compute the final Permit2 hash combining mandate with Permit2-specific fields
        permit2Hash = EIP712TypeHashLib.hashPermit2({
            tokenInHash: mandateStub.tokenInHash,
            arbiter: mandateStub.arbiter, // Caller becomes the authorized arbiter
            nonce: permit2Stub.nonce,
            expires: permit2Stub.expires,
            mandate: mandateHash
        });
    }

    /**
     * @notice Checks if a nonce has been used for a specific account
     * @dev This function provides a clean way to check nonce usage without relying on low-level storage access
     * @param nonce The nonce value to check
     * @param account The account address that owns the nonce
     * @return used True if the nonce has been consumed, false otherwise
     */
    function isPermit2IntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        return nonce.permit2NonceSlot(account).isConsumed();
    }
}
