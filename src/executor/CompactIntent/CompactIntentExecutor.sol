// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { ICompactIntentExecutor } from "../interfaces/ICompactIntent.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { ValidateSignature } from "../VerifySignature/VerifySignature.sol";
import { IntentExecutorNonceLib } from "../lib/IntentExecutorNonceLib.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Bytes32ArrayLib } from "@rhinestone/compact-utils/src/common/Bytes32ArrayLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { LibERC7579 } from "@rhinestone/compact-utils/src/common/LibERC7579.sol";
import { CompactEIP712 } from "@rhinestone/compact-utils/src/common/CompactEIP712.sol";
import { IntentExecutorBase } from "../IntentExecutorBase.sol";
import { ConsumeNonceLib } from "../lib/ConsumeNonceLib.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";

/**
 * @title CompactIntentExecutor
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Executor contract for cross-chain intents using The Compact protocol
 * @dev This contract enables secure cross-chain intent execution through a two-phase process:
 *
 *      Phase 1 (Origin Chain): executePreClaimOpsWithCompactStub
 *      - User signs an EIP-712 structured intent specifying cross-chain operations
 *      - Arbiter calls this function to execute pre-claim operations (e.g., token approvals)
 *      - Contract validates signature and computes claim hash for cross-chain verification
 *      - Sets signature skip permission for the arbiter to execute target operations
 *
 *      Phase 2 (Destination Chain): executeTargetOpsWithCompactStub
 *      - Arbiter provides proof of origin chain execution via claim hash
 *      - Contract validates the claim hash through The Compact protocol's verification system
 *      - If valid, executes the target operations on behalf of the user
 *
 * @custom:security The security model relies on:
 *                  - EIP-712 signatures for user authorization
 *                  - The Compact protocol's cross-chain verification system
 *                  - Router-only access control for cross-chain operations
 *                  - Expiration timestamps to prevent stale execution
 */
abstract contract CompactIntentExecutor is
    ICompactIntentExecutor,
    CompactEIP712,
    IntentExecutorBase,
    ValidateSignature,
    ReentrancyGuardTransient
{
    using Bytes32ArrayLib for bytes32[];
    using SmartExecutionLib for Types.Operation;
    using ConsumeNonceLib for bytes32;
    using IntentExecutorNonceLib for uint256;
    using EIP712TypeHashLib for Types.Operation;

    /**
     * @notice Executes target operations on the destination chain with claim hash verification
     * @dev This function implements the second phase of cross-chain intent execution. It:
     *      1. Reconstructs the element hash from the provided stub data
     *      2. Validates that execution is happening on the correct target chain
     *      3. Checks that the fill hasn't expired
     *      4. Builds the complete Compact Merkle tree with all elements
     *      5. Computes the final EIP-712 claim hash
     *      6. Verifies the claim hash proof through the designated proofer contract
     *      7. Executes the target operations if all validations pass
     * @param account The recipient account address for the target operations
     * @param notarizedArbiter The arbiter address that notarized the cross-chain transfer
     * @param compactStub Core Compact order data (nonce, expires, notarized chain)
     * @param elementStub Element-specific data needed for destination chain execution
     * @param targetOps Array of operations to execute on the destination chain
     * @param signature EIP-712 signature authorizing the target operations
     * @return claimHash The computed claim hash used for verification
     */
    function executeTargetOpsWithCompactStub(
        address account,
        address notarizedArbiter,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubDestination calldata elementStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        onlyRouter
        returns (bytes32 claimHash)
    {
        claimHash = _compactClaimHash({
            account: account, notarizedArbiter: notarizedArbiter, compactStub: compactStub, elementStub: elementStub, targetOps: targetOps
        });

        // consume nonce
        compactStub.nonce.compactNonceSlot(account).consumeNonce();

        // recreate Compact Digest for notarized chain
        bytes32 digest = _compactHashTypedData(claimHash, compactStub.notarizedChainId);

        // Validate the signature using the execution signature checker
        require(_isValidSignature(account, LOCKTAG, digest, claimHash, targetOps, signature), InvalidSignature());

        // Execute the target operations on behalf of the account
        LibERC7579.executeOps(account, targetOps);
    }

    /**
     * @notice Executes pre-claim operations on the origin chain before cross-chain transfer
     * @dev This function implements the first phase of cross-chain intent execution. It:
     *      1. Reconstructs the element hash using the caller as the arbiter
     *      2. Builds the complete Compact Merkle tree with all elements
     *      3. Computes the final EIP-712 claim hash
     *      4. Executes the pre-claim operations after signature validation
     *      5. Sets the signature skip flag for corresponding target operations
     * @param account The smart account address that owns the assets and signed the order
     * @param compactStub Core Compact order data (nonce, expires, notarized chain)
     * @param elementStub Element-specific data needed for origin chain execution
     * @param preClaimOps Array of operations to execute before cross-chain transfer (e.g., token approvals)
     * @param signature EIP-712 signature from the account authorizing these operations
     * @return sigOk True if the signature validation passed
     * @return execOk True if the pre-claim operations executed successfully
     */
    function executePreClaimOpsWithCompactStub(
        address account,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubOrigin calldata elementStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        nonReentrant
        returns (bool sigOk, bool execOk)
    {
        // Reconstruct the element hash with the caller as the arbiter
        // The arbiter is responsible for facilitating the cross-chain transfer
        bytes32 elementHash = EIP712TypeHashLib.hashElementRaw({
            arbiter: msg.sender,
            originChainId: block.chainid,
            tokenInHash: elementStub.tokenInHash,
            mandateHash: EIP712TypeHashLib.hashMandateRaw({
                targetAttributes: elementStub.targetAttributesHash,
                minGas: elementStub.minGas,
                preClaimOpsHash: preClaimOps.hashOps(),
                destOpsHash: elementStub.destOpsHash,
                qHash: elementStub.qHash
            })
        });

        // Insert the computed `elementHash` into the `otherElements` array at the specified `elementOffset`.
        // This builds the complete list of elements for the Compact Merkle tree.
        // Note: `elementOffset` handling differs from TheCompact; here, 0 is notarized, 1 is first exogenous.
        bytes32 allElementsHash = elementStub.otherElements.insertAtAndHash({ index: elementStub.elementOffset, element: elementHash });

        // Compute the final EIP-712 claim hash for the entire Compact order.
        bytes32 claimHash = EIP712TypeHashLib.hashCompact({
            sponsor: account, nonce: compactStub.nonce, expires: compactStub.expires, allElementsHash: allElementsHash
        });

        bytes32 digest = _compactHashTypedData(claimHash, compactStub.notarizedChainId);
        // Validate the signature using the execution signature checker
        sigOk = _isValidSignature(account, LOCKTAG, digest, claimHash, preClaimOps, signature);
        // Early return if signature validation fails
        if (!sigOk) return (false, false);

        // consume nonce
        compactStub.nonce.compactNonceSlot(account).consumeNonce();

        execOk = LibERC7579.tryExecuteOps(account, preClaimOps);
    }

    /**
     * @notice Internal function to compute the claim hash for destination chain execution
     * @dev This function reconstructs the complete claim hash that was originally computed during
     *      pre-claim operations on the origin chain. The hash must match exactly to validate
     *      that the cross-chain intent execution is legitimate. The process involves:
     *
     *      1. Computing the element hash from all individual components
     *      2. Building the complete Compact Merkle tree structure
     *      3. Computing the final EIP-712 claim hash
     *
     *      Critical: All hash components must match the original computation exactly
     *
     * @param account The recipient account address for the target operations
     * @param notarizedArbiter The arbiter address that facilitated the cross-chain transfer
     * @param compactStub Core Compact order data from the origin chain
     * @param elementStub Element-specific data needed for hash reconstruction
     * @param targetOps The operations to execute on this destination chain
     * @return claimHash The computed claim hash for verification
     */
    function _compactClaimHash(
        address account,
        address notarizedArbiter,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubDestination calldata elementStub,
        Types.Operation calldata targetOps
    )
        internal
        view
        returns (bytes32 claimHash)
    {
        // Ensure the fill operation hasn't expired
        require(elementStub.fillExpires >= block.timestamp, InvalidParams());
        // Reconstruct the element hash by combining all element components
        // This hash must match the one computed during pre-claim operations
        bytes32 targetAttributesHash =
            EIP712TypeHashLib.hashTargetAttributesRaw(account, elementStub.tokenOutHash, block.chainid, elementStub.fillExpires);

        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttributesHash,
            minGas: 0, // Default for target operations
            preClaimOpsHash: elementStub.preClaimOpsHash,
            destOpsHash: targetOps.hashOps(),
            qHash: elementStub.qHash
        });

        bytes32 elementHash = EIP712TypeHashLib.hashElementRaw({
            arbiter: notarizedArbiter,
            originChainId: compactStub.notarizedChainId,
            tokenInHash: elementStub.tokenInHash,
            mandateHash: mandateHash
        });

        // Insert the computed `elementHash` into the `otherElements` array at the specified `elementOffset`.
        // This builds the complete list of elements for the Compact Merkle tree.
        // Note: `elementOffset` handling differs from TheCompact; here, 0 is notarized, 1 is first exogenous.
        bytes32 allElementsHash = elementStub.otherElements.insertAtAndHash({ index: elementStub.elementOffset, element: elementHash });

        // Compute the final EIP-712 claim hash for the entire Compact order.
        claimHash = EIP712TypeHashLib.hashCompact({
            sponsor: elementStub.sponsor, nonce: compactStub.nonce, expires: compactStub.expires, allElementsHash: allElementsHash
        });
    }

    /**
     * @notice Checks if a nonce has been used for a specific account
     * @dev This function provides a clean way to check nonce usage without relying on low-level storage access
     * @param nonce The nonce value to check
     * @param account The account address that owns the nonce
     * @return used True if the nonce has been consumed, false otherwise
     */
    function isCompactIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        return nonce.compactNonceSlot(account).isConsumed();
    }
}
