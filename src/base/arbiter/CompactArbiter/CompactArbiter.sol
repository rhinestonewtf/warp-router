// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    ITheCompactClaims,
    MultichainClaim,
    BatchMultichainClaim,
    ExogenousMultichainClaim,
    ExogenousBatchMultichainClaim
} from "the-compact/interfaces/ITheCompactClaims.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { SplitLib } from "./lib/SplitLib.sol";

/**
 * @title CompactArbiter
 * @notice Abstract base contract providing TheCompact protocol integration for cross-chain resource unlocking
 * @dev This contract serves as the core integration layer with TheCompact's resource locking system,
 *      enabling arbiters to unlock tokens and assets that were previously locked on origin chains.
 *
 *      TheCompact is a protocol for cross-chain resource management where users can lock resources
 *      on one chain and later unlock them on another chain through cryptographic proofs and signatures.
 *      This arbiter handles the complex claim operations required to unlock these resources.
 *
 *      Key TheCompact integration capabilities:
 *      - Multichain claims: Unlocking resources when the current chain is the notarized chain
 *      - Exogenous claims: Unlocking resources when operating on a non-notarized chain
 *      - Batch operations: Efficient processing of multiple token unlocks in single transaction
 *      - Signature validation: EIP-712 compliant mandate verification for secure unlocking
 *      - Cross-chain coordination: Managing state transitions across multiple blockchain networks
 *
 *      The contract abstracts away the complexity of TheCompact's claim operations while providing
 *      standardized interfaces for settlement-specific arbiters to leverage resource unlocking.
 *
 *      Security considerations:
 *      - All claim operations include sponsor validation to prevent unauthorized unlocking
 *      - Mandate hashes ensure cryptographic integrity of cross-chain operations
 *      - Failed claims revert transactions to maintain atomic settlement guarantees
 *
 *      Gas optimization notes:
 *      - Single vs batch claim operations are automatically selected based on token count
 *      - Immutable interface storage minimizes gas costs for repeated operations
 * @custom:security Cross-chain resource unlocking requires careful validation of all claim parameters
 */
abstract contract CompactArbiter {
    using SmartExecutionLib for Types.Operation;
    using SplitLib for uint256[2][];
    using IdLib for uint256;

    /// @notice TheCompact claims contract interface for unlocking locked resources
    /// @dev This is the core interface to TheCompact protocol for resource management
    ITheCompactClaims internal immutable CLAIM;

    /// @notice Thrown when a claim operation to TheCompact fails
    error ClaimFailed();

    /// @notice Thrown when order data is invalid or malformed
    error InvalidOrderData();

    /// @notice Emitted when a claim is successfully processed through TheCompact
    /// @param sponsor The address that sponsored the original order
    /// @param nonce The unique identifier of the processed order
    /// @param claimHash The hash returned by TheCompact claim operations
    event ProcessedClaim(address indexed sponsor, uint256 indexed nonce, bytes32 indexed claimHash);

    /// @notice EIP-712 typestring for mandate verification in TheCompact claims
    /// @dev This is the witness typestring used by TheCompact for validating cross-chain mandates.
    ///      The string defines the structure of the mandate data that gets hashed and signed.
    ///      Format includes Target, Operation arrays, and Token definitions for type safety.
    ///      The "stripped" version excludes the leading "Mandate mandate)" portion as required by TheCompact.
    string internal constant STRING_MANDATE_STRIPPED =
    // solhint-disable-next-line max-line-length
    "Target target,uint128 minGas,Op originOps,Op destOps,bytes32 q)Op(bytes32 vt,Ops[] ops)Ops(address to,uint256 value,bytes data)Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount";
    /**
     * @notice Initializes the CompactArbiter with TheCompact protocol integration
     * @dev Sets up the immutable interface to TheCompact's claims contract, which handles
     *      all resource unlocking operations. This interface is used for both multichain
     *      and exogenous claim operations across different settlement scenarios.
     * @param compact The address of TheCompact claims contract that manages resource locks and unlocks
     *                Must be a valid ITheCompactClaims implementation for the target network
     * @custom:security The compact address cannot be changed after deployment, ensure correct address
     */

    constructor(address compact) {
        CLAIM = ITheCompactClaims(compact);
    }

    /**
     * @notice Validates that an order is for cross-chain settlement
     * @dev Ensures the order doesn't have target operations (which would indicate same-chain execution)
     *      and that the notarized chain ID differs from the current chain
     * @param order The order being validated
     * @param notarizedChainId The chain ID where the order was originally notarized
     */
    modifier requireOtherChain(Types.Order calldata order, uint256 notarizedChainId) {
        // Target operations should be empty for cross-chain orders
        require(order.targetOps.data.length == 0, InvalidOrderData());
        // Notarized chain must be different from current chain for cross-chain settlement
        require(notarizedChainId != block.chainid, InvalidOrderData());
        _;
    }

    /**
     * @notice Unlocks resources from TheCompact for orders originating from the notarized chain
     * @dev Handles the case where resources were locked on the chain where the order was notarized,
     *      and now need to be unlocked for cross-chain settlement. Uses batchMultichainClaim for
     *      standard cross-chain resource unlocking.
     * @param order The order containing token inputs and settlement details
     * @param otherElements Additional chain elements for multi-chain validation
     * @param originChainSig The signature from the origin chain authorizing the unlock
     * @param allocatorData The allocator-specific data for resource allocation
     * @param depositor The address that will receive the unlocked tokens
     * @param mandateHash The mandate hash for TheCompact validation
     * @return claimHash The claim hash returned by TheCompact, used for tracking and validation
     */
    function _unlockNotarizedChain(
        Types.Order calldata order,
        bytes32[] calldata otherElements,
        bytes calldata originChainSig,
        bytes memory allocatorData,
        address depositor,
        bytes32 mandateHash
    )
        internal
        returns (bytes32 claimHash)
    {
        address sponsor = order.sponsor;
        // Prevent the arbiter from being the sponsor (security check)
        require(sponsor != address(this), InvalidOrderData());

        uint256[2][] calldata tokenIn = order.tokenIn;

        if (tokenIn.length == 1) {
            uint256 amount = tokenIn[0][1];
            claimHash = CLAIM.multichainClaim(
                MultichainClaim({
                    allocatorData: allocatorData,
                    sponsorSignature: originChainSig,
                    sponsor: sponsor,
                    nonce: order.nonce,
                    expires: order.expires,
                    witness: mandateHash,
                    witnessTypestring: STRING_MANDATE_STRIPPED,
                    additionalChains: otherElements,
                    claimants: SplitLib.toComponents(depositor, amount),
                    id: tokenIn[0][0],
                    allocatedAmount: amount
                })
            );
        } else {
            // Execute the batch multichain claim through TheCompact
            claimHash = CLAIM.batchMultichainClaim(
                BatchMultichainClaim({
                    allocatorData: allocatorData,
                    sponsorSignature: originChainSig,
                    sponsor: sponsor,
                    nonce: order.nonce,
                    expires: order.expires,
                    witness: mandateHash,
                    witnessTypestring: STRING_MANDATE_STRIPPED,
                    additionalChains: otherElements,
                    claims: order.tokenIn.toSplit(depositor)
                })
            );
        }

        // Ensure the claim was successful
        require(claimHash != bytes32(0), ClaimFailed());
    }

    /**
     * @notice Unlocks resources from TheCompact for orders originating from external (non-notarized) chains
     * @dev Handles the case where resources were locked on a different chain than where the order
     *      was notarized. Uses exogenousBatchClaim for cross-chain resource unlocking where the
     *      current chain is not the notarized chain.
     * @param order The order containing token inputs and settlement details
     * @param originChainSig The signature from the origin chain authorizing the unlock
     * @param notarizedChainId The chain ID where the order was originally notarized
     * @param chainIndex The index of the current chain in the cross-chain element array
     * @param otherElements Additional chain elements for multi-chain validation
     * @param allocatorData The allocator-specific data for resource allocation
     * @param depositor The address that will receive the unlocked tokens
     * @param mandateHash The mandate hash for TheCompact validation
     * @return claimHash The claim hash returned by TheCompact, used for tracking and validation
     */
    function _unlockExogenousChain(
        Types.Order calldata order,
        bytes calldata originChainSig,
        uint256 notarizedChainId,
        uint256 chainIndex,
        bytes32[] calldata otherElements,
        bytes memory allocatorData,
        address depositor,
        bytes32 mandateHash
    )
        internal
        returns (bytes32 claimHash)
    {
        address sponsor = order.sponsor;
        // Prevent the arbiter from being the sponsor (security check)
        require(sponsor != address(this), InvalidOrderData());

        uint256[2][] calldata tokenIn = order.tokenIn;

        if (tokenIn.length == 1) {
            uint256 amount = tokenIn[0][1];
            claimHash = CLAIM.exogenousClaim(
                ExogenousMultichainClaim({
                    allocatorData: allocatorData,
                    sponsorSignature: originChainSig,
                    sponsor: sponsor,
                    nonce: order.nonce,
                    expires: order.expires,
                    witness: mandateHash,
                    witnessTypestring: STRING_MANDATE_STRIPPED,
                    additionalChains: otherElements,
                    chainIndex: chainIndex,
                    notarizedChainId: notarizedChainId,
                    claimants: SplitLib.toComponents(depositor, amount),
                    id: tokenIn[0][0],
                    allocatedAmount: amount
                })
            );
        } else {
            // Execute the exogenous batch claim through TheCompact
            claimHash = CLAIM.exogenousBatchClaim(
                ExogenousBatchMultichainClaim({
                    allocatorData: allocatorData,
                    sponsorSignature: originChainSig,
                    sponsor: order.sponsor,
                    nonce: order.nonce,
                    expires: order.expires,
                    witness: mandateHash,
                    witnessTypestring: STRING_MANDATE_STRIPPED,
                    additionalChains: otherElements,
                    chainIndex: chainIndex,
                    notarizedChainId: notarizedChainId,
                    claims: order.tokenIn.toSplit(depositor)
                })
            );
        }

        // Ensure the claim was successful
        require(claimHash != bytes32(0), ClaimFailed());
    }
}
