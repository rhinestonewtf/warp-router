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
 * @title IntentExecutorAdapter
 * @notice Gas-optimized adapter contract for forwarding intent execution calls to an intent executor
 * @dev This adapter implements a transparent forwarding pattern that allows seamless routing of intent
 *      execution requests while minimizing gas overhead. It acts as a proxy between the router and
 *      the actual intent executor, handling three types of intent execution patterns:
 *      - Compact intent execution (ERC-7683 style)
 *      - Permit2 intent execution (with token approvals)
 *      - Standalone multichain intent execution
 *
 *      The adapter uses memory-safe assembly for calldata forwarding to achieve minimal gas overhead,
 *      typically saving 200-500 gas per call compared to high-level Solidity forwarding patterns.
 *
 * @custom:relayer This adapter does not consume any relayerContext data
 * @custom:security This contract uses assembly for performance but maintains memory safety through
 *                  proper free memory pointer management and bounds checking
 * @custom:gas Optimized for minimal forwarding overhead using direct calldata copying and
 *             pre-computed function selectors
 *
 * Example usage:
 * 1. Router receives intent execution request
 * 2. Router calls appropriate handleFill_* function on this adapter
 * 3. Adapter prepends correct selector and forwards calldata to executor using assembly
 * 4. Executor processes the intent and executes target operations
 */
contract IntentExecutorAdapter is AdapterBase {
    using AdapterTagLib for bytes12;
    using AdapterCalldataPassthroughLib for address;

    /// @dev The immutable address of the intent executor contract that handles actual execution
    address internal immutable EXECUTOR;

    /**
     * @notice Thrown when the forwarding call to the intent executor fails
     * @dev This error indicates that the underlying executor either reverted or ran out of gas.
     *      The original revert reason from the executor is not preserved to maintain gas efficiency.
     */
    error ForwardingToExecutorFailed();

    /// @dev Function selector for Permit2-based intent execution - cached for gas efficiency
    bytes4 internal constant PERMIT2_INTENT_SELECTOR = IPermit2IntentExecutor.executeTargetOpsWithPermit2Stub.selector;

    /// @dev Function selector for Compact-based intent execution - cached for gas efficiency
    bytes4 internal constant COMPACT_INTENT_SELECTOR = ICompactIntentExecutor.executeTargetOpsWithCompactStub.selector;

    /// @dev Function selector for standalone multichain intent execution - cached for gas efficiency
    bytes4 internal constant STANDALONE_INTENT_SELECTOR = IStandaloneIntentExecutor.executeMultichainOps.selector;

    /// @dev Function selector for standalone single-chain intent execution - cached for gas efficiency
    bytes4 internal constant STANDALONE_SINGLE_CHAIN_INTENT_SELECTOR = IStandaloneIntentExecutor.executeSinglechainOps.selector;

    /**
     * @notice Initializes the IntentExecutorAdapter with router and executor addresses
     * @dev Sets up the adapter to forward calls from the specified router to the intent executor.
     *      The adapter is initialized with version 0.0 as per SemVer convention.
     * @param router The address of the router contract that will call this adapter
     * @param executor The address of the intent executor contract that will handle forwarded calls
     */
    constructor(address router, address executor) AdapterBase(router, address(0)) SemVer(0, 0) {
        EXECUTOR = executor;
    }

    /**
     * @notice Handles compact intent execution by forwarding to the executor
     * @dev This function is called by the router to execute compact-style intents. It forwards
     *      the call to the executor's executeTargetOpsWithCompactStub function using optimized
     *      assembly forwarding to minimize gas overhead.
     *
     *      Compact intents follow the ERC-7683 standard for cross-chain intent execution,
     *      typically involving token transfers and arbitrary contract calls.
     *
     * @param executorCalldata The ABI-encoded parameters for the compact intent execution,
     *                        typically containing target operations, token amounts, and execution context
     * @return bytes4 The function selector of this function to confirm successful handling
     *
     * @custom:gas Optimized forwarding saves gas compared to traditional proxy patterns
     * @custom:fill-adapter
     *
     * Example flow:
     * 1. Router receives compact intent execution request
     * 2. Router calls this function with encoded parameters
     * 3. Function forwards to executor.executeTargetOpsWithCompactStub(parameters)
     * 4. Executor processes compact intent and executes target operations
     */
    function handleFill_intentExecutor_handleCompactTargetOps(bytes calldata executorCalldata)
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        EXECUTOR.passthrough(COMPACT_INTENT_SELECTOR, executorCalldata);
        return this.handleFill_intentExecutor_handleCompactTargetOps.selector;
    }

    /**
     * @notice Handles Permit2-based intent execution by forwarding to the executor
     * @dev This function is called by the router to execute intents that use Permit2 for token
     *      approvals. It forwards the call to the executor's executeTargetOpsWithPermit2Stub
     *      function, which handles the Permit2 signature verification and token transfers.
     *
     *      Permit2 intents allow gasless token approvals through signed permits, enabling
     *      users to authorize token transfers without prior on-chain approval transactions.
     *
     * @param executorCalldata The ABI-encoded parameters for the Permit2 intent execution,
     *                        including permit signatures, token details, and target operations
     * @return bytes4 The function selector of this function to confirm successful handling
     *
     * @custom:security Permit2 signature validation is handled by the executor, not this adapter
     * @custom:gas Optimized forwarding reduces gas overhead for Permit2 workflows
     * @custom:fill-adapter
     *
     * Example flow:
     * 1. User signs Permit2 permit for token transfer
     * 2. Router receives intent execution request with permit signature
     * 3. Router calls this function with encoded permit and parameters
     * 4. Function forwards to executor.executeTargetOpsWithPermit2Stub(parameters)
     * 5. Executor validates permit signature and executes target operations
     */
    function handleFill_intentExecutor_handlePermit2TargetOps(bytes calldata executorCalldata)
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        EXECUTOR.passthrough(PERMIT2_INTENT_SELECTOR, executorCalldata);
        return this.handleFill_intentExecutor_handlePermit2TargetOps.selector;
    }

    /**
     * @notice Handles standalone multichain intent execution by forwarding to the executor
     * @dev This function is called by the router to execute standalone multichain operations
     *      that don't require Compact or Permit2 patterns. It forwards the call to the
     *      executor's executeMultichainOps function for processing cross-chain operations.
     *
     *      Standalone intents typically involve direct cross-chain operations without
     *      the additional abstractions of Compact or Permit2 patterns.
     *
     * @param executorCalldata The ABI-encoded parameters for the multichain operation execution,
     *                        containing cross-chain operation details and execution parameters
     * @return bytes4 The function selector of this function to confirm successful handling
     *
     * @custom:gas Optimized forwarding maintains performance for multichain operations
     * @custom:fill-adapter
     *
     * Example flow:
     * 1. Router receives multichain operation request
     * 2. Router calls this function with encoded operation parameters
     * 3. Function forwards to executor.executeMultichainOps(parameters)
     * 4. Executor processes multichain operations across target chains
     */
    function handleFill_intentExecutor_executeMultichainOps(bytes calldata executorCalldata)
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        EXECUTOR.passthrough(STANDALONE_INTENT_SELECTOR, executorCalldata);
        return this.handleFill_intentExecutor_executeMultichainOps.selector;
    }

    /**
     * @notice Handles standalone single-chain intent execution by forwarding to the executor
     * @dev This function is called by the router to execute standalone single-chain operations
     *      that are limited to a single chain. It forwards the call to the executor's
     *      executeSinglechainOps function for processing operations on the current chain.
     *
     *      Single-chain intents are simpler than multichain intents as they only require
     *      chain-specific signature validation without cross-chain coordination.
     *
     * @param executorCalldata The ABI-encoded parameters for the single-chain operation execution,
     *                        containing operation details and execution parameters
     * @return bytes4 The function selector of this function to confirm successful handling
     *
     * @custom:gas Optimized forwarding maintains performance for single-chain operations
     * @custom:fill-adapter
     *
     * Example flow:
     * 1. Router receives single-chain operation request
     * 2. Router calls this function with encoded operation parameters
     * 3. Function forwards to executor.executeSinglechainOps(parameters)
     * 4. Executor processes operations on the current chain
     */
    function handleFill_intentExecutor_executeSinglechainOps(bytes calldata executorCalldata)
        external
        payable
        onlyViaRouter
        returns (bytes4)
    {
        EXECUTOR.passthrough(STANDALONE_SINGLE_CHAIN_INTENT_SELECTOR, executorCalldata);
        return this.handleFill_intentExecutor_executeSinglechainOps.selector;
    }

    /**
     * @notice Checks if this contract supports a given interface selector
     * @dev Implements ERC-165 interface detection to declare support for the four intent
     *      execution handlers plus any interfaces supported by the parent AdapterBase.
     *      This allows the router and other contracts to query supported functionality.
     *
     * @param selector The 4-byte interface selector to check for support
     * @return supported True if the selector is supported by this contract, false otherwise
     *
     * Supported selectors:
     * - handleFill_intentExecutor_handleCompactTargetOps: Compact intent execution
     * - handleFill_intentExecutor_handlePermit2TargetOps: Permit2 intent execution
     * - handleFill_intentExecutor_executeMultichainOps: Standalone multichain execution
     * - handleFill_intentExecutor_executeSinglechainOps: Standalone single-chain execution
     * - Any selectors supported by AdapterBase (isAdapter, etc.)
     */
    function supportsInterface(bytes4 selector) public pure override returns (bool supported) {
        return selector == this.handleFill_intentExecutor_handleCompactTargetOps.selector
            || selector == this.handleFill_intentExecutor_handlePermit2TargetOps.selector
            || selector == this.handleFill_intentExecutor_executeMultichainOps.selector
            || selector == this.handleFill_intentExecutor_executeSinglechainOps.selector || super.supportsInterface(selector);
    }

    function ADAPTER_TAG() external pure override returns (bytes12) {
        return Constants.DEFAULT_ADAPTER_TAG.setSkipRelayerContext();
    }
}
