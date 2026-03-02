// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AdapterBase, SemVer } from "../base/adapter/AdapterBase.sol";
import { AdapterCalldataPassthroughLib } from "../base/adapter/AdapterCalldataPassthroughLib.sol";
import { ICompactIntentExecutor } from "../executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "../executor/interfaces/IPermit2Intent.sol";
import { IStandaloneIntentExecutor } from "../executor/interfaces/IStandaloneIntent.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";

/**
 * @title IntentExecutorAdapterGasRefund
 * @notice Adapter contract for forwarding intent execution calls with gas refund support
 * @dev This adapter handles intent execution requests that include gas refund functionality.
 *      It acts as a proxy between the router and the standalone intent executor, supporting:
 *      - Multichain intent execution with gas refund
 *      - Single-chain intent execution with gas refund
 *
 *      The gas refund recipient address is extracted from the relayer context (20 bytes).
 *      Users must sign the gas refund terms in their signature to authorize the refund.
 *
 * @custom:relayer This adapter expects 20 bytes of relayer context containing the gas refund recipient
 * @custom:security Gas refund terms are included in the user's signature to prevent manipulation
 *
 * Example usage:
 * 1. Router receives intent execution request with gas refund
 * 2. Router calls handleFill_intentExecutor_execute*_gasRefund on this adapter
 * 3. Adapter extracts gas refund recipient from relayer context
 * 4. Adapter calls executor with gas refund parameters
 * 5. Executor processes the intent and transfers gas refund to recipient
 */
contract IntentExecutorAdapterGasRefund is AdapterBase {
    using AdapterTagLib for bytes12;
    using AdapterCalldataPassthroughLib for address;

    /// @dev The immutable address of the intent executor contract that handles actual execution
    address internal immutable EXECUTOR;

    /**
     * @notice Initializes the IntentExecutorAdapterGasRefund with router and executor addresses
     * @dev Sets up the adapter to forward gas-refund intent calls from the specified router to the executor.
     *      The adapter is initialized with version 0.0 as per SemVer convention.
     *      Note: The second parameter to AdapterBase is address(0) since this adapter does not use
     *      a separate arbiter - the executor handles validation internally.
     * @param router The address of the router contract that will call this adapter
     * @param executor The address of the standalone intent executor contract
     */
    constructor(address router, address executor) AdapterBase(router, address(0)) SemVer(0, 0) {
        EXECUTOR = executor;
    }

    /**
     * @notice Extracts the gas refund recipient address from relayer context
     * @dev The relayer context must contain exactly 20 bytes representing the recipient address.
     *      This address receives the gas refund tokens after successful execution.
     * @return gasRefundRecipient The address that will receive gas refund tokens
     * @custom:security Validates relayer context length to prevent malformed data
     */
    function _gasRefundRecipient() internal pure returns (address gasRefundRecipient) {
        (uint256 relayerContextLength, bytes calldata relayerContext) = _loadRelayerContext();
        require(relayerContextLength == 20, InvalidRelayerContext());
        // The first 20 bytes of the solver context are the tokenIn recipient address.
        return address(bytes20(relayerContext[:20]));
    }

    /**
     * @notice Handles multichain intent execution with gas refund
     * @dev This function executes multichain operations and settles gas refund to the relayer.
     *      The gas refund recipient is extracted from the relayer context, which must contain
     *      a 20-byte address. The user must have signed the gas refund terms in their signature.
     * @param ops The MultiChainOps struct containing account, operations, nonce, and signature
     * @param gasRefund The gas refund terms (token and amount) authorized by the user
     * @return bytes4 The function selector to confirm successful handling
     * @custom:security Gas refund terms must be included in the user's signature to prevent manipulation
     * @custom:fill-adapter
     */
    function handleFill_intentExecutor_executeMultichainOps_gasRefund(
        IStandaloneIntentExecutor.MultiChainOps calldata ops,
        IStandaloneIntentExecutor.GasRefund calldata gasRefund
    )
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        if (gasRefund.token == Constants.NATIVE_TOKEN) {
            IStandaloneIntentExecutor(EXECUTOR).executeMultichainOpsWithGasRefund_ETH(ops, gasRefund.overhead, _gasRefundRecipient());
        } else {
            IStandaloneIntentExecutor(EXECUTOR).executeMultichainOpsWithGasRefund_ERC20(ops, gasRefund, _gasRefundRecipient());
        }
        return this.handleFill_intentExecutor_executeMultichainOps_gasRefund.selector;
    }

    /**
     * @notice Handles single-chain intent execution with gas refund
     * @dev This function executes single-chain operations and settles gas refund to the relayer.
     *      The gas refund recipient is extracted from the relayer context, which must contain
     *      a 20-byte address. The user must have signed the gas refund terms in their signature.
     * @param ops The SingleChainOps struct containing account, operations, nonce, and signature
     * @param gasRefund The gas refund terms (token and amount) authorized by the user
     * @return bytes4 The function selector to confirm successful handling
     * @custom:security Gas refund terms must be included in the user's signature to prevent manipulation
     * @custom:fill-adapter
     */
    function handleFill_intentExecutor_executeSinglechainOps_gasRefund(
        IStandaloneIntentExecutor.SingleChainOps calldata ops,
        IStandaloneIntentExecutor.GasRefund calldata gasRefund
    )
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        if (gasRefund.token == Constants.NATIVE_TOKEN) {
            IStandaloneIntentExecutor(EXECUTOR).executeSinglechainOpsWithGasRefund_ETH(ops, gasRefund.overhead, _gasRefundRecipient());
        } else {
            IStandaloneIntentExecutor(EXECUTOR).executeSinglechainOpsWithGasRefund_ERC20(ops, gasRefund, _gasRefundRecipient());
        }
        return this.handleFill_intentExecutor_executeSinglechainOps_gasRefund.selector;
    }

    /**
     * @notice Checks if this contract supports a given interface selector
     * @dev Implements ERC-165 interface detection to declare support for the gas refund
     *      intent execution handlers plus any interfaces supported by the parent AdapterBase.
     *      This allows the router and other contracts to query supported functionality.
     *
     * @param selector The 4-byte interface selector to check for support
     * @return supported True if the selector is supported by this contract, false otherwise
     *
     * Supported selectors:
     * - handleFill_intentExecutor_executeMultichainOps_gasRefund: Multichain execution with gas refund
     * - handleFill_intentExecutor_executeSinglechainOps_gasRefund: Single-chain execution with gas refund
     * - Any selectors supported by AdapterBase (isAdapter, etc.)
     */
    function supportsInterface(bytes4 selector) public pure override returns (bool supported) {
        return selector == this.handleFill_intentExecutor_executeSinglechainOps_gasRefund.selector
            || selector == this.handleFill_intentExecutor_executeMultichainOps_gasRefund.selector || super.supportsInterface(selector);
    }

    function ADAPTER_TAG() external pure override returns (bytes12) {
        return Constants.DEFAULT_ADAPTER_TAG;
    }
}
