// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Component, BatchClaimComponent } from "the-compact/types/Components.sol";
import { TokenIdLib } from "@rhinestone/compact-utils/src/common/TokenIdLib.sol";

/**
 * @title SplitLib
 * @notice Utility library for TheCompact protocol integration that converts order token data
 *         into TheCompact-compatible claim component structures for cross-chain resource allocation
 * @dev This library serves as a critical bridge between Rhinestone's internal order representation
 *      and TheCompact protocol's claim component requirements. It handles the transformation of
 *      token ID/amount pairs into structured claims that can be processed by TheCompact's
 *      batch and multichain claiming mechanisms.
 *
 *      Key responsibilities:
 *      - Converting internal token data to TheCompact BatchClaimComponent arrays
 *      - Resource allocation and splitting for multiple claimants
 *      - Address-to-claimant ID conversion using TokenIdLib
 *      - Optimized batch processing for gas efficiency
 *
 *      Integration points:
 *      - Used by CompactArbiter for cross-chain and batch claim operations
 *      - Interfaces with TheCompact's claiming infrastructure
 *      - Supports both single and multi-token batch operations
 *
 * @custom:security This library performs pure transformations without external calls or state changes,
 *                  making it inherently safe from reentrancy and state manipulation attacks.
 */
library SplitLib {
    /**
     * @notice Enables address-to-claimant ID conversion using TokenIdLib functionality
     * @dev This using statement provides access to the toClaimant function which converts
     *      Ethereum addresses to uint256 claimant IDs required by TheCompact protocol.
     *      The conversion uses assembly to efficiently cast the address to uint256.
     */
    using TokenIdLib for address;

    /**
     * @notice Converts an array of token ID/amount pairs into TheCompact BatchClaimComponent structures
     *         for batch claim operations across multiple tokens
     * @dev This function is the primary interface for transforming Rhinestone order data into
     *      TheCompact's batch claim format. Each input token becomes a separate BatchClaimComponent
     *      with the settlement layer depositor as the sole claimant for the full allocated amount.
     *
     *      Algorithm:
     *      1. Pre-allocates result array to avoid dynamic resizing (gas optimization)
     *      2. Iterates through input tokens, extracting ID and amount from each pair
     *      3. Creates BatchClaimComponent with:
     *         - id: The token identifier from TheCompact protocol
     *         - allocatedAmount: Total amount available for claiming
     *         - portions: Array containing single Component for the depositor
     *
     *      This structure supports TheCompact's resource allocation model where:
     *      - Each token has a total allocated amount
     *      - Portions define how that amount is distributed among claimants
     *      - Current implementation allocates 100% to settlement depositor
     *
     * @param tokenIn Array of [tokenId, amount] pairs representing the tokens and amounts
     *                to be converted into claim components. Each inner array must have exactly
     *                2 elements: [0] = token ID, [1] = amount
     * @param settlementLayerDepositor The address that will receive all allocated tokens as the
     *                                 designated claimant. This is typically the depositor on
     *                                 the settlement layer who provided the initial resources.
     * @return split Array of BatchClaimComponent structures ready for TheCompact batch operations.
     *               Each component represents one token with its allocation and claimant information.
     * @custom:gas Pre-allocates the result array to minimize gas costs from dynamic array resizing.
     *             Uses unchecked loop increment as length bounds are verified by Solidity.
     * @custom:security Input validation is minimal as this is a pure transformation function.
     *                  Callers must ensure tokenIn arrays are properly formatted with valid token IDs.
     */
    function toSplit(
        uint256[2][] calldata tokenIn,
        address settlementLayerDepositor
    )
        internal
        pure
        returns (BatchClaimComponent[] memory split)
    {
        // Cache array length to avoid repeated CALLDATALOAD operations
        uint256 length = tokenIn.length;

        // Pre-allocate result array to exact size for gas efficiency
        split = new BatchClaimComponent[](length);

        // Transform each token ID/amount pair into a BatchClaimComponent
        for (uint256 i; i < length; i++) {
            // Extract token identifier and amount from the input pair
            uint256 tokenId = tokenIn[i][0];
            uint256 amountIn = tokenIn[i][1];

            // Create BatchClaimComponent with settlement depositor as sole claimant
            split[i] =
                BatchClaimComponent({ id: tokenId, allocatedAmount: amountIn, portions: toComponents(settlementLayerDepositor, amountIn) });
        }
    }

    /**
     * @notice Creates a single-element Component array for a specific depositor and amount
     * @dev This function encapsulates the conversion of an Ethereum address to a TheCompact
     *      claimant ID and wraps it in the Component structure required for claim operations.
     *      It serves both single-token operations and as a building block for batch operations.
     *
     *      The function performs two key transformations:
     *      1. Address → Claimant ID: Uses TokenIdLib.toClaimant() to convert the Ethereum
     *         address to a uint256 claimant identifier via assembly casting
     *      2. Data → Component: Wraps the claimant ID and amount in TheCompact's Component struct
     *
     *      Why single-element array:
     *      - TheCompact protocol expects Component[] for portions allocation
     *      - Current use case allocates 100% to single depositor
     *      - Structure supports future multi-claimant scenarios
     *      - Maintains consistency with TheCompact's batch processing model
     *
     * @param settlementLayerDepositor The Ethereum address of the entity that will claim the tokens.
     *                                 This is converted to a claimant ID using assembly for efficiency.
     * @param amountIn The exact amount of tokens allocated to this claimant.
     *                 Must match the allocated amount in parent BatchClaimComponent.
     * @return components Single-element array containing the Component with claimant ID and amount.
     *                    Ready for use in both individual and batch TheCompact operations.
     * @custom:gas Creates minimal single-element array. Assembly conversion in toClaimant() is
     *             more gas-efficient than standard Solidity address-to-uint256 casting.
     * @custom:security Pure function with no external calls or state dependencies.
     *                  Address conversion is deterministic and reversible.
     */

    function toComponents(address settlementLayerDepositor, uint256 amountIn) internal pure returns (Component[] memory components) {
        // Create single-element array for the sole claimant
        components = new Component[](1);

        // Convert address to claimant ID and create Component structure
        components[0] = Component({ claimant: settlementLayerDepositor.toClaimant(), amount: amountIn });
    }
}
