// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { ArbiterBase } from "@rhinestone/compact-utils/src/base/arbiter/ArbiterBase.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";

/**
 * @title SameChainArbiter
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Arbiter contract for validating and executing same-chain order settlements within the Router ecosystem.
 *         This contract handles the core settlement logic for orders where both origin and execution occur
 *         on the same blockchain, providing atomic settlement guarantees while supporting both Compact
 *         and Permit2 protocols with their respective validation and execution patterns.
 *
 * @dev SAME-CHAIN SETTLEMENT PROCESSING:
 *      The arbiter implements the critical resource unlock and execution phase of same-chain settlement.
 *      It works in coordination with SameChainAdapter, which pre-funds recipients before calling the arbiter.
 *      The arbiter's role is to validate user authorization and execute the final settlement steps:
 *
 *      1. **SIGNATURE VALIDATION**: Verifies user signatures against order data and metadata
 *      2. **PRE-CLAIM EXECUTION**: Handles pre-claim operations (approvals, setup) for Compact protocol
 *      3. **RESOURCE UNLOCKING**: Claims and unlocks user input tokens from the appropriate protocol
 *      4. **TARGET EXECUTION**: Executes user-specified operations (swaps, transfers) on target assets
 *
 * @dev DUAL PROTOCOL ARCHITECTURE:
 *      Supports both major authorization protocols with protocol-specific handling:
 *
 *      **Compact Protocol Flow:**
 *      - Validates complex signatures and metadata (otherElements, allocatorData)
 *      - Executes pre-claim operations with allocated gas stipends
 *      - Handles notarized chain validation and resource unlock
 *      - Supports multi-step operations and complex authorization patterns
 *
 *      **Permit2 Protocol Flow:**
 *      - Streamlined validation with simplified signature requirements
 *      - Direct resource unlock without pre-claim complexity
 *      - Optimized for gas efficiency and simple token operations
 *      - Lower overhead for straightforward token transfers and swaps
 *
 * @dev SECURITY AND VALIDATION:
 *      - **Access Control**: Only Router can call arbiter functions (onlyRouter modifier)
 *      - **Signature Security**: All user signatures validated before any asset movements
 *      - **Atomic Execution**: Either entire settlement succeeds or reverts completely
 *      - **Protocol Integrity**: Maintains protocol-specific validation rules and constraints
 *      - **Target Operation Safety**: User operations executed in controlled environment
 *
 * @dev INTEGRATION PATTERNS:
 *      - Extends ArbiterBase for common arbiter functionality and Router integration
 *      - Uses SmartExecutionLib for target operation execution without separate signatures
 *      - Coordinates with SameChainAdapter for complete settlement orchestration
 *      - Provides protocol-specific entry points for different authorization methods
 *
 * @custom:security Arbiter validation occurs after recipient pre-funding to ensure atomicity.
 *                  If validation fails, the entire transaction reverts including pre-funding.
 *
 * @custom:security TRUSTED EXECUTOR MODEL: SameChainArbiter is whitelisted as a trusted contract
 *                  in the IntentExecutor. This enables a critical gas optimization where target
 *                  operations can be executed without additional signature validation after
 *                  successful permit2/compact transfers. The signature validation occurs once
 *                  during the pre-claim phase, and subsequent target operation execution uses
 *                  executeOpsWithoutSignature to avoid a costly third signature check.
 *
 * @custom:security SIGNATURE VALIDATION FLOW: Pre-claim operations require full signature validation
 *                  against order data and metadata. After successful resource unlock (permit2 or
 *                  compact transfer), the arbiter's trusted status allows target operations to
 *                  execute without re-validating signatures, reducing gas costs while maintaining
 *                  security through the initial validation gate.
 *
 * @custom:gas Same-chain arbitration is optimized for lower gas costs compared to cross-chain
 *             alternatives, with single-transaction settlement and efficient validation.
 *
 * @custom:architecture The arbiter pattern separates validation/execution logic from adapter coordination,
 *                      enabling modular settlement flows and protocol-specific optimization.
 *
 * @custom:limitation EXOGENOUS CHAIN CLAIMS NOT IMPLEMENTED: This arbiter does not implement compact claims
 *                    for exogenous chains. For simplicity, when a multichain intent requires a same-chain
 *                    transaction, it is always executed as the notarized chain using handleCompact_NotarizedChain.
 */
contract SameChainArbiter is ArbiterBase {
    using SmartExecutionLib for Types.Operation;
    using SmartExecutionLib for SmartExecutionLib.SigMode;
    using EIP712TypeHashLib for uint256[2][];
    using EIP712TypeHashLib for bytes;
    using EIP712TypeHashLib for Types.Order;

    /// @notice Thrown when an order has expired based on its fillDeadline.
    error OrderExpired();

    /// @notice Emitted when target operations are not executed due to recipient/sponsor mismatch or emissary pattern
    event SameChainTargetOpsNotHandled();

    /**
     * @notice Initializes the SameChainArbiter with required protocol contracts.
     * @dev Sets up the arbiter for same-chain settlement validation and execution.
     *      The arbiter requires access to the Router for access control, the Compact contract
     *      for resource unlocking, and the AddressBook for protocol configuration.
     *
     * @param router The Router contract address that will call this arbiter.
     *               Used for access control to ensure only authorized settlement requests.
     * @param compact The Compact protocol contract address for resource unlocking and validation.
     *                Handles the core authorization and token claim logic for Compact orders.
     * @param addressBook The AddressBook contract containing protocol configuration and addresses.
     *                   Provides centralized configuration for protocol contracts and parameters.
     *
     * @custom:security All three addresses are stored as immutable to prevent malicious redirection.
     *                  The Router address specifically enforces that only authorized adapters can trigger settlement.
     */
    constructor(address router, address compact, address addressBook) ArbiterBase(router, compact, addressBook) { }

    /**
     * @notice Handles complete Compact protocol same-chain settlement with full feature support.
     * @dev Orchestrates the comprehensive 3-step Compact settlement process for same-chain orders:
     *
     *      **STEP 1: PRE-CLAIM VALIDATION AND EXECUTION**
     *      - Validates order signatures and metadata using _compactPreClaimOps
     *      - Executes any pre-claim operations (approvals, setup calls) with allocated gas stipend
     *      - Generates mandate hash for subsequent resource unlock validation
     *      - Ensures all prerequisites are met before resource claiming begins
     *
     *      **STEP 2: RESOURCE UNLOCK AND DEPOSITING**
     *      - Calls _unlockNotarizedChain to validate signatures against mandate hash
     *      - Unlocks user's input tokens from the Compact protocol contracts
     *      - Transfers input tokens to the specified relayer (solver's recipient address)
     *      - Returns claim hash for tracking and potential future reference
     *
     *      **STEP 3: TARGET OPERATION EXECUTION**
     *      - Executes user-specified target operations using SmartExecutionLib
     *      - Operations run without requiring additional signatures (mandate-based execution)
     *      - Typically includes swaps, transfers, or other token operations on user's behalf
     *      - Maintains atomic execution - if target ops fail, entire settlement reverts
     *      - **EXECUTION CONDITIONS**: Target operations are only executed when ALL of:
     *        1. Target operations are specified (non-empty)
     *        2. Recipient equals sponsor (self-execution pattern)
     *        3. Target operations are NOT using execution emissary pattern
     *        4. Signature mode match: target ops sig mode equals pre-claim ops sig mode,
     *           OR pre-claim ops are empty (allowing standalone target ops)
     *      - If conditions not met, target operations are silently skipped
     *
     * @param order Complete order specification including tokens, operations, deadlines, and metadata.
     *              Contains all information needed for settlement validation and execution.
     * @param sigs Container for required signatures including notarized claim sig and optional pre-claim sig.
     *             Used to validate user authorization for the settlement.
     * @param otherElements Array of additional order element hashes for complex multi-element orders.
     *                     Typically empty for single-element same-chain settlements.
     * @param allocatorData Protocol-specific data for the Compact allocator contract.
     *                     Contains parameters needed for resource allocation and validation.
     * @param relayer Address where input tokens will be deposited after successful unlock.
     *               Typically the solver's address or a solver-controlled withdrawal contract.
     *
     * @return sponsor The address of the order sponsor who authorized this settlement.
     * @return nonce The nonce value from the order used for replay protection and tracking.
     *
     * @custom:access Only callable by Router via SameChainAdapter (enforced by onlyRouter modifier).
     * @custom:security All signatures validated before any asset movements or operations occur.
     * @custom:security TRUSTED EXECUTION: Target operations execute without signature validation due to
     *                  SameChainArbiter's trusted status in IntentExecutor, saving gas after initial validation.
     * @custom:atomic If any step fails, the entire transaction reverts including any partial state changes.
     * @custom:gas Pre-claim gas stipend ensures complex setup operations don't run out of gas.
     */
    function handleCompact_NotarizedChain(
        Types.Order calldata order,
        Types.Signatures calldata sigs,
        bytes32[] calldata otherElements,
        bytes calldata allocatorData,
        address relayer
    )
        external
        onlyRouter
        returns (address sponsor, uint256 nonce)
    {
        sponsor = order.sponsor;
        nonce = order.nonce;
        // Ensure the fill operation hasn't expired
        require(order.fillDeadline >= block.timestamp, OrderExpired());

        // NOTE: This function assumes notarized chain execution for all multichain intents
        // that require same-chain settlement. Exogenous chain claims are not implemented
        // for simplicity - all compact same-chain transactions use notarized chain flow.

        // STEP 1: PRE-CLAIM VALIDATION AND SETUP
        // Generate mandate hash through comprehensive signature validation and pre-claim execution.
        // This validates the user's authorization and executes any required setup operations
        // (token approvals, contract configurations) before attempting resource unlock.
        // The mandate hash serves as cryptographic proof that all validation steps succeeded.
        bytes32 mandateHash = _compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        // STEP 2: RESOURCE UNLOCK AND DEPOSIT
        // Unlock user's input tokens from TheCompact protocol using the validated mandate hash.
        // The depositor (relayer) receives the tokens directly, avoiding intermediate transfers.
        // This step commits the user's resources to the settlement and returns a claim hash
        // that can be used for tracking and potential dispute resolution.
        _unlockNotarizedChain({
            order: order,
            otherElements: otherElements,
            originChainSig: sigs.notarizedClaimSig,
            allocatorData: allocatorData,
            // relayer's address is set as the direct beneficiary of TheCompact claim
            // this will trigger a compact withdrawal to the relayer address
            depositor: relayer,
            mandateHash: mandateHash
        });

        // STEP 3: TARGET OPERATION EXECUTION

        // Execute target operations only if ALL conditions are met:
        // 1. Target operations are specified (non-empty)
        // 2. Recipient equals sponsor (self-execution pattern for security)
        // 3. Target operations are NOT using execution emissary pattern
        //    - Emissary pattern delegates execution to a different contract
        // 4. Signature mode match: EITHER target ops sig mode matches pre-claim ops sig mode,
        //    OR pre-claim ops are empty (allowing standalone target ops execution)
        if (order.targetOps.data.length != 0) {
            address recipient = order.recipient;
            SmartExecutionLib.SigMode targetOpsSigMode = order.targetOps.extractSigMode();
            bool sigModeMatch = (order.preClaimOps.data.length == 0 || targetOpsSigMode == order.preClaimOps.extractSigMode());
            if (recipient == sponsor && !targetOpsSigMode.isExecutionEmissary() && sigModeMatch) {
                EXECUTOR.executeOpsWithoutSignature(recipient, order.targetOps);
            }
        }
    }

    /**
     * @notice Handles streamlined Permit2 protocol same-chain settlement with optimized efficiency.
     * @dev Orchestrates the simplified 3-step Permit2 settlement process for same-chain orders:
     *
     *      **STEP 1: PRE-CLAIM VALIDATION**
     *      - Validates order signatures using _permit2PreClaimOps for Permit2-specific requirements
     *      - Generates mandate hash for subsequent resource unlock without complex pre-claim operations
     *      - Skips gas stipend allocation and complex setup operations for efficiency
     *
     *      **STEP 2: RESOURCE UNLOCK AND DEPOSITING**
     *      - Calls _unlockPermit2 with simplified signature validation against mandate hash
     *      - Unlocks user's input tokens directly from Permit2 protocol contracts
     *      - Transfers input tokens to the specified relayer address without intermediate steps
     *      - More efficient than Compact due to Permit2's streamlined authorization model
     *
     *      **STEP 3: TARGET OPERATION EXECUTION**
     *      - Executes user-specified target operations using the same SmartExecutionLib as Compact
     *      - Operations typically simpler for Permit2 (direct transfers, basic swaps)
     *      - Maintains atomic execution guarantees despite simplified flow
     *      - Lower gas overhead due to reduced validation complexity
     *      - **EXECUTION CONDITIONS**: Target operations are only executed if:
     *        1. recipient equals sponsor AND
     *        2. target operations are NOT using execution emissary pattern
     *      - If conditions not met, execution is skipped to maintain security
     *
     *      The Permit2 flow is optimized for straightforward token operations where the complexity
     *      of pre-claim operations and gas stipends is unnecessary, providing significant gas savings
     *      for simple same-chain settlements.
     *
     * @param order Complete order specification including tokens, operations, and metadata.
     *              Same structure as Compact but typically with simpler target operations.
     * @param sigs Container for required signatures, primarily the notarized claim signature.
     *             Permit2 typically requires fewer signatures than full Compact protocol.
     * @param relayer Address where input tokens will be deposited after successful unlock.
     *               Receives tokens directly from Permit2 unlock without intermediate processing.
     *
     * @return sponsor The address of the order sponsor who authorized this settlement.
     * @return nonce The nonce value from the order used for replay protection and tracking.
     *
     * @custom:access Only callable by Router via SameChainAdapter (enforced by onlyRouter modifier).
     * @custom:efficiency More gas-efficient than Compact due to simplified validation and unlock process.
     * @custom:security TRUSTED EXECUTION: Target operations execute without signature validation due to
     *                  SameChainArbiter's trusted status in IntentExecutor, avoiding redundant validation.
     * @custom:atomic Maintains same atomic execution guarantees as Compact despite simplified flow.
     * @custom:scope Optimized for simple token operations rather than complex multi-step settlements.B
     */

    function handlePermit2(
        Types.Order calldata order,
        Types.Signatures calldata sigs,
        address relayer
    )
        external
        onlyRouter
        returns (address sponsor, uint256 nonce)
    {
        sponsor = order.sponsor;
        nonce = order.nonce;
        // Ensure the fill operation hasn't expired
        require(order.fillDeadline >= block.timestamp, OrderExpired());

        // STEP 1: PRE-CLAIM VALIDATION
        // Generate mandate hash through Permit2-specific signature validation.
        // This is simpler than Compact pre-claim as Permit2 doesn't support complex
        // pre-claim operations, but still validates user authorization for the settlement.
        bytes32 mandateHash = _permit2PreClaimOps(order, sigs);

        // STEP 2: RESOURCE UNLOCK AND DEPOSIT
        // Unlock user's input tokens from Permit2 protocol using the validated mandate hash.
        // Permit2 unlock is more streamlined than Compact, with direct token transfers
        // to the depositor (relayer) without intermediate processing steps.
        _unlockPermit2({ order: order, sig: sigs.notarizedClaimSig, depositor: relayer, mandateHash: mandateHash });

        // STEP 3: TARGET OPERATION EXECUTION

        // Only execute target operations if recipient equals sponsor (self-execution pattern).
        // This ensures the user is executing operations on their own behalf, maintaining
        // security and preventing unauthorized third-party execution of user operations.
        if (order.targetOps.data.length != 0) {
            address recipient = order.recipient;
            SmartExecutionLib.SigMode targetOpsSigMode = order.targetOps.extractSigMode();
            bool sigModeMatch = (order.preClaimOps.data.length == 0 || targetOpsSigMode == order.preClaimOps.extractSigMode());
            if (recipient == sponsor && !targetOpsSigMode.isExecutionEmissary() && sigModeMatch) {
                EXECUTOR.executeOpsWithoutSignature(recipient, order.targetOps);
            }
        }
    }
}
