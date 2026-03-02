// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { SemVer, AdapterBase } from "../../base/adapter/AdapterBase.sol";
import { SameChainArbiter, ArbiterBase } from "./SameChainArbiter.sol";
import { AdapterBasePrefund } from "../../base/adapter/AdapterBasePrefund.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Version } from "@rhinestone/compact-utils/src/Version.sol";

/**
 * @title SameChainAdapter
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Adapter for handling same-chain order settlement within the Warp Routerr ecosystem.
 *         This contract orchestrates the complete same-chain settlement flow where both order origin
 *         and execution occur on the same blockchain, eliminating cross-chain complexity while maintaining
 *         proper settlement guarantees through pre-funding and coordinated arbiter execution.
 *
 * @dev SAME-CHAIN SETTLEMENT ARCHITECTURE:
 *      Same-chain orders provide efficiency benefits by avoiding cross-chain coordination overhead.
 *      However, they still require proper settlement to ensure atomic execution and prevent MEV attacks.
 *      The settlement follows this critical 3-step process:
 *
 *      1. **PRE-FUNDING**: Solver pre-funds the recipient with output tokens before claiming input tokens
 *      2. **RESOURCE UNLOCK**: Arbiter validates signatures and unlocks user's input resources
 *      3. **TARGET EXECUTION**: Final operations (swaps, transfers) are executed on behalf of the user
 *
 * @dev DUAL PROTOCOL SUPPORT:
 *      This adapter supports both Compact and Permit2 protocols with different data requirements:
 *
 *      - **Compact Protocol**: Full featured with pre-claim operations, gas stipends, and allocator data
 *      - **Permit2 Protocol**: Streamlined flow with simplified signature requirements
 *
 *      Both protocols follow the same core settlement pattern but with protocol-specific validation.
 *
 * @dev SECURITY MODEL:
 *      - **Access Control**: Only Router can call fill functions (onlyViaRouter modifier)
 *      - **Pre-funding Safety**: Recipients receive output tokens before input tokens are unlocked
 *      - **Atomic Settlement**: If any step fails, the entire transaction reverts
 *      - **Signature Validation**: All user signatures validated by the arbiter before execution
 *      - **Nonce Protection**: Each order has unique nonce to prevent replay attacks
 *
 * @dev INTEGRATION PATTERNS:
 *      - Inherits from AdapterBase for Router integration and security patterns
 *      - Works exclusively with SameChainArbiter for settlement logic
 *      - Returns function selectors for Router's IERC165 interface detection
 *      - Emits Filled events for off-chain tracking and indexing
 *
 * @custom:relayer The relayer data must be encoded as abi.encodePacked(address(recipient))
 *                 where recipient is the address that should receive the tokenIn payment.
 *                 This address will be passed to the arbiter as the depositor for input tokens.
 *
 * @custom:security Pre-funding mechanism prevents order manipulation attacks where malicious actors
 *                  could front-run settlements to claim input tokens without providing outputs.
 *
 * @custom:gas Same-chain operations are optimized for lower gas costs compared to cross-chain
 *             alternatives, with efficient pre-funding and single-transaction settlement.
 */
contract SameChainAdapter is AdapterBasePrefund, SameChainArbiter {
    /**
     * @notice Data structure for Compact protocol same-chain order fills.
     * @dev Contains all necessary data for processing a Compact-based same-chain settlement.
     *      The Compact protocol provides full-featured order execution with pre-claim operations,
     *      gas stipends, and complex allocator interactions.
     *
     * @param order The complete order specification including tokens, operations, and metadata.
     *              Contains sponsor, recipient, nonce, deadlines, token amounts, and target operations.
     * @param userSigs Container for all required signatures (notarized claim sig and optional pre-claim sig).
     *                 Signatures are validated by the arbiter to ensure user authorization.
     * @param otherElements Array of hashes for multi-element orders (empty for single-element same-chain orders).
     *                      Used in complex multi-chain scenarios but typically empty for same-chain settlements.
     * @param allocatorData Protocol-specific data for the Compact allocator contract.
     *                      Contains parameters needed for resource allocation and validation.
     * @param preClaimGasStipend Gas amount allocated for pre-claim operations execution.
     *                          Ensures sufficient gas for any setup operations before main settlement.
     */
    struct FillDataCompact {
        Types.Order order;
        Types.Signatures userSigs;
        bytes32[] otherElements;
        bytes allocatorData;
    }

    /**
     * @notice Data structure for Permit2 protocol same-chain order fills.
     * @dev Simplified data structure for Permit2-based same-chain settlements.
     *      Permit2 protocol provides a streamlined flow without the complexity of
     *      pre-claim operations or gas stipends, making it more gas-efficient
     *      for simple token transfers and swaps.
     *
     * @param order The complete order specification including tokens, operations, and metadata.
     *              Same structure as Compact but typically with simpler target operations.
     * @param userSigs Container for required signatures, primarily the notarized claim signature.
     *                 Permit2 typically requires fewer signatures than full Compact protocol.
     */
    struct FillDataPermit2 {
        Types.Order order;
        Types.Signatures userSigs;
    }

    // solhint-disable max-line-length
    /**
     * @notice Decodes the tokenIn recipient address from the solver context.
     * @dev Extracts the solver's designated recipient for input tokens from the Router's solver context.
     *      The solver context is passed through the Router and contains solver-specific configuration
     *      for how input tokens should be handled after settlement. This address will receive the
     *      user's input tokens once the arbiter validates and unlocks them.
     *
     * @return tokenInRecipient The address where input tokens should be sent after arbiter processing.
     *                         This is typically the solver's address or a solver-controlled contract.
     *
     * @custom:security The solver context is validated by the Router before reaching this adapter,
     *                  ensuring the decoded address is from an authorized solver.
     */
    // solhint-enable max-line-length
    function _tokenInRecipient() internal pure returns (address tokenInRecipient) {
        (uint256 relayerContextLength, bytes calldata relayerContext) = _loadRelayerContext();
        require(relayerContextLength == 20, InvalidRelayerContext());
        // The first 20 bytes of the solver context are the tokenIn recipient address.
        return address(bytes20(relayerContext[:20]));
    }

    /**
     * @notice Initializes the SameChainAdapter with Router and Arbiter integration.
     * @dev Sets up the adapter for same-chain settlement operations within the Router ecosystem.
     *      The adapter works exclusively through delegatecall from the Router and coordinates
     *      with the specified arbiter for settlement validation and execution.
     *
     * @param router The Router contract address that will delegatecall this adapter.
     *               Must be a valid Router deployment with same-chain adapter support.
     * @param compact The Compact protocol contract address for handling Compact-based orders.
     *              Used for full-featured same-chain settlements with pre-claim operations.
     * @param arbiter The SameChainArbiter contract address that processes settlement logic.
     * @param addressBook The address book contract containing protocol addresses and configurations.
     * @custom:security The Router address is stored as immutable to prevent malicious redirection.
     *                  Only the specified Router can execute adapter functions via delegatecall.
     */
    constructor(
        address router,
        address compact,
        address arbiter,
        address addressBook
    )
        AdapterBasePrefund(router, arbiter)
        SemVer(Version.SAMECHAIN_VERSION_MINOR, Version.SAMECHAIN_VERSION_PATCH)
        SameChainArbiter(router, compact, addressBook)
    { }

    /**
     * @notice Handles a same-chain order fill using the Compact protocol.
     * @dev Entry point for Compact-based same-chain settlements called exclusively by the Router.
     *      Implements the complete same-chain settlement flow: pre-funding recipients, then
     *      coordinating with the arbiter to unlock resources and execute target operations.
     *
     *      The Compact protocol provides full-featured order execution including:
     *      - Pre-claim operations (approvals, setup calls)
     *      - Gas stipend allocation for complex operations
     *      - Allocator data for protocol-specific validation
     *      - Multi-signature support for complex authorization flows
     *
     * @param fillData Complete Compact protocol order data including signatures and metadata.
     *                 Contains all information needed for settlement validation and execution.
     *
     * @return selector This function's selector for Router IERC165 interface compliance.
     *                  Enables Router to verify adapter capabilities before execution.
     *
     * @custom:access Only callable by Router via delegatecall (enforced by onlyViaRouter modifier).
     * @custom:flow Pre-funds recipient → calls arbiter → emits Filled event → returns selector.
     * @custom:security All user signatures validated by arbiter before any token movements occur.
     * @custom:fill-adapter
     */

    function samechain_compact_handleFill(FillDataCompact calldata fillData) external payable onlyViaRouter returns (bytes4 selector) {
        // Load the solver context from the router.
        // Handle the fill with the full solver context.
        _handleCompactFill(fillData, _tokenInRecipient());
        return this.samechain_compact_handleFill.selector;
    }

    /**
     * @notice Handles a same-chain order fill using the Permit2 protocol.
     * @dev Entry point for Permit2-based same-chain settlements called exclusively by the Router.
     *      Implements a streamlined settlement flow optimized for simple token operations.
     *      Permit2 protocol provides gas-efficient settlement for straightforward token transfers
     *      and swaps without the overhead of pre-claim operations or complex allocator interactions.
     *
     *      The Permit2 protocol focuses on:
     *      - Simplified signature requirements
     *      - Lower gas costs for basic operations
     *      - Direct token authorization via Permit2 contract
     *      - Streamlined validation and execution flow
     *
     * @param fillData Permit2 protocol order data with essential signatures and order details.
     *                 Contains simplified data structure optimized for efficient processing.
     *
     * @return selector This function's selector for Router IERC165 interface compliance.
     *                  Enables Router to verify adapter capabilities before execution.
     *
     * @custom:access Only callable by Router via delegatecall (enforced by onlyViaRouter modifier).
     * @custom:flow Pre-funds recipient → calls arbiter → emits Filled event → returns selector.
     * @custom:gas More gas-efficient than Compact protocol for simple token operations.
     * @custom:fill-adapter
     */

    function samechain_permit2_handleFill(FillDataPermit2 calldata fillData) external payable onlyViaRouter returns (bytes4 selector) {
        // Load the solver context from the router.
        // Handle the fill with the full solver context.
        _handlePermit2Fill(fillData, _tokenInRecipient());
        return this.samechain_permit2_handleFill.selector;
    }

    /**
     * @notice Internal implementation of Compact protocol same-chain settlement.
     * @dev Orchestrates the critical 3-step same-chain settlement process for Compact orders:
     *
     *      1. **PRE-FUNDING PHASE**: Transfers output tokens from solver to recipient before any
     *         input token claims occur. This prevents manipulation attacks where malicious actors
     *         could claim input tokens without providing the promised outputs.
     *
     *      2. **ARBITER COORDINATION**: Calls SameChainArbiter with all necessary order data,
     *         signatures, and metadata. The arbiter validates user signatures, executes pre-claim
     *         operations, unlocks input resources, and coordinates final target operation execution.
     *
     *      3. **EVENT EMISSION**: Emits Filled event for off-chain tracking and order lifecycle management.
     *
     * @param fillData Complete Compact order data including signatures, allocator data, and gas stipend.
     * @param tokenInRecipient Address where input tokens will be sent after arbiter processes the unlock.
     *                        Typically the solver's address or a solver-controlled withdrawal contract.
     *
     * @custom:security Pre-funding occurs before any signature validation to ensure atomicity.
     *                  If arbiter validation fails, the entire transaction reverts including pre-funding.
     * @custom:flow _prefundRecipient → SameChainArbiter.handleCompact_NotarizedChain → emit Filled.
     */
    function _handleCompactFill(FillDataCompact calldata fillData, address tokenInRecipient) internal {
        // Pre-fund the recipient to ensure they have the output token before the arbiter acts.
        _prefundRecipient({ from: msg.sender, to: fillData.order.recipient, tokenOut: fillData.order.tokenOut });
        // Call the arbiter to claim the input assets and deposit them.
        (address sponsor, uint256 nonce) = SameChainArbiter(ARBITER)
            .handleCompact_NotarizedChain({
                order: fillData.order,
                sigs: fillData.userSigs,
                otherElements: fillData.otherElements,
                allocatorData: fillData.allocatorData,
                relayer: tokenInRecipient
            });

        emit RouterFilled(sponsor, nonce);
    }

    /**
     * @notice Internal implementation of Permit2 protocol same-chain settlement.
     * @dev Orchestrates the streamlined 3-step same-chain settlement process for Permit2 orders:
     *
     *      1. **PRE-FUNDING PHASE**: Transfers output tokens from solver to recipient using the same
     *         security model as Compact but with simplified token handling for Permit2 efficiency.
     *
     *      2. **ARBITER COORDINATION**: Calls SameChainArbiter.handlePermit2 with essential order data
     *         and signatures. The arbiter handles Permit2-specific validation, resource unlocking,
     *         and target operation execution without pre-claim complexity.
     *
     *      3. **EVENT EMISSION**: Emits Filled event for consistent off-chain tracking across protocols.
     *
     * @param fillData Permit2 order data with simplified structure focused on essential settlement info.
     * @param tokenInRecipient Address where input tokens will be deposited after successful validation.
     *                        Receives tokens directly from Permit2 unlock without intermediate steps.
     *
     * @custom:gas More efficient than Compact due to simplified arbiter interaction and fewer validations.
     * @custom:flow _prefundRecipient → SameChainArbiter.handlePermit2 → emit Filled.
     */
    function _handlePermit2Fill(FillDataPermit2 calldata fillData, address tokenInRecipient) internal {
        // Pre-fund the recipient to ensure they have the output token before the arbiter acts.
        _prefundRecipient({ from: msg.sender, to: fillData.order.recipient, tokenOut: fillData.order.tokenOut });
        // Call the arbiter to claim the input assets and deposit them.

        (address sponsor, uint256 nonce) =
            SameChainArbiter(ARBITER).handlePermit2({ order: fillData.order, sigs: fillData.userSigs, relayer: tokenInRecipient });

        emit RouterFilled(sponsor, nonce);
    }

    /**
     * @notice Checks if this adapter supports a specific function selector.
     * @dev Implements IERC165 interface detection for Router compatibility.
     *      The Router uses this function to verify adapter capabilities before
     *      delegating fill operations. This ensures only supported operations
     *      are attempted and provides clear capability discovery for off-chain systems.
     *
     * @param selector The function selector to check for support.
     *
     * @return supported True if the selector is supported by this adapter.
     *                   Returns true for both Compact and Permit2 same-chain fill functions,
     *                   plus any selectors supported by the parent AdapterBase contract.
     *
     * @custom:interface Part of IERC165 standard for interface detection and capability discovery.
     */
    function supportsInterface(bytes4 selector) public pure override(AdapterBase, ArbiterBase) returns (bool supported) {
        return selector == this.samechain_compact_handleFill.selector || selector == this.samechain_permit2_handleFill.selector
            || AdapterBase.supportsInterface(selector) || ArbiterBase.supportsInterface(selector);
    }
}
