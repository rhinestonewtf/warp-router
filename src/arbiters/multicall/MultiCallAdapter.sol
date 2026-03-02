// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AdapterBase, SemVer } from "../../base/adapter/AdapterBase.sol";
import { AdapterBasePrefund } from "../../base/adapter/AdapterBasePrefund.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { Caller, MultiCaller } from "../../router/utils/Caller.sol";
import { IAdapter } from "../../interfaces/IAdapter.sol";

/**
 * @title MultiCallAdapter
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Adapter for executing batched arbitrary calls through the Warp Routerr with solver compensation
 * @dev This adapter enables solvers to execute multiple calls on behalf of users while ensuring proper token
 *      transfers and fee collection. It supports various fill operations including standard fills, fills with
 *      fees, and fills with both fees and refunds. The adapter validates that solvers receive expected payment
 *      and handles the complexity of multi-step transactions.
 */
contract MultiCallAdapter is AdapterBasePrefund, Caller {
    /// @notice Using the IdLib library to handle token ID conversions.
    using IdLib for uint256;

    /// @notice Thrown if the solver does not receive the expected amount of input tokens after the multicall.
    error TokenNotPaidInMulticall();

    /**
     * @notice Encodes recipient addresses for solver context
     * @dev Helper function for off-chain components to construct relayerContext data
     * @param tokenInRecipient Address to receive input tokens from the multicall
     * @return Packed bytes containing both recipient addresses
     */
    function __encodeRelayerData(address tokenInRecipient) external pure returns (bytes memory) {
        return abi.encodePacked(tokenInRecipient);
    }

    /**
     * @notice Extracts the tokenIn recipient from solver context
     * @dev Reads the first 20 bytes of solver context data
     * @return Address designated to receive input tokens
     */
    function _tokenInRecipient() internal pure returns (address) {
        (uint256 relayerContextLength, bytes calldata relayerContext) = _loadRelayerContext();
        require(relayerContextLength == 20, InvalidRelayerContext());
        // The first 20 bytes of the solver context are the tokenIn recipient address.
        return address(bytes20(relayerContext[:20]));
    }

    /**
     * @notice Initializes the MultiCallAdapter with router and arbiter addresses
     * @param router Address of the Warp Routerr contract
     */
    constructor(address router) AdapterBasePrefund(router, address(0)) SemVer(0, 0) { }

    /**
     * @notice Data structure for multicall fill operations
     * @param tokenIn Array of [token_address, amount] pairs representing solver payment
     * @param tokenOut Array of [token_address, amount] pairs the solver transfers to user
     * @param multicalls Batch of execution calls to perform
     * @param account Target smart contract account for the operations
     */
    struct FillData {
        // What the solver is being paid back in.
        uint256[2][] tokenIn;
        // What the solver pays the account.
        uint256[2][] tokenOut;
        Execution[] multicalls;
        address account;
        // Value to send with the multicall
        uint256 value;
    }

    /**
     * @notice Data structure for Just-In-Time claim operations
     * @param tokenIn Array of [token_address, amount] pairs for solver compensation
     * @param multicalls Batch of execution calls for the JIT claim
     */
    struct JITClaimData {
        // What the solver is being paid back in.
        uint256[2][] tokenIn;
        Execution[] multicalls;
    }

    /**
     * @notice Handles Just-In-Time claim operations with multicall execution
     * @dev Executes multicalls and ensures solver receives specified tokenIn amounts
     * @param jitClaimData Contains tokenIn compensation and multicall executions
     * @return Function selector for verification
     * @custom:claim-adapter
     */
    function multicall_handleJITClaim(JITClaimData calldata jitClaimData) external onlyViaRouter returns (bytes4) {
        // Perform the multicall and assert the solver received payment.
        _multicallAssertTokenIn(jitClaimData.multicalls, jitClaimData.tokenIn, _tokenInRecipient(), 0);
        return this.multicall_handleJITClaim.selector;
    }

    /**
     * @notice Handles payable multicall operations with ETH value
     * @dev Forwards ETH value to arbiter for multicall execution
     * @param value Amount of ETH to send with the multicall
     * @param executions Array of calls to execute
     * @return Function selector for verification
     * @custom:fill-adapter
     */
    function multicall_handlePayable(uint256 value, Execution[] calldata executions) external payable onlyViaRouter returns (bytes4) {
        MultiCaller(payable(ARBITER)).multiCall{ value: value }(executions);
        return this.multicall_handlePayable.selector;
    }

    /**
     * @notice Executes a standard multicall fill operation
     * @dev Router-only function that extracts tokenIn recipient from context and processes fill
     * @param fillData Contains token transfers and multicall executions
     * @return Function selector for verification
     * @custom:fill-adapter
     */
    function multicall_handleFill(FillData calldata fillData) external payable onlyViaRouter returns (bytes4) {
        // Perform the multicall and assert the solver received payment.
        _handleMulticall(fillData, _tokenInRecipient());
        return this.multicall_handleFill.selector;
    }

    /**
     * @notice Internal handler for multicall fill operations
     * @dev Prefunds user account with tokenOut before executing multicalls
     * @param fillData Contains all data for the fill operation
     * @param tokenInReceiver Address to receive tokenIn payments
     */
    function _handleMulticall(FillData calldata fillData, address tokenInReceiver) internal {
        // First, send the output tokens from the solver (msg.sender) to the user's account.
        _prefundRecipient(msg.sender, fillData.account, fillData.tokenOut);
        _multicallAssertTokenIn(fillData.multicalls, fillData.tokenIn, tokenInReceiver, fillData.value);
    }

    /**
     * @notice Core multicall execution with token validation
     * @dev Executes multicalls through arbiter and ensures tokenIn is properly transferred
     * @param multicalls Array of calls to execute
     * @param tokenIn Expected token payments to solver
     * @param tokenInReceiver Address to receive the tokens
     * @param value ETH value to send with the multicall
     */

    function _multicallAssertTokenIn(
        Execution[] calldata multicalls,
        uint256[2][] calldata tokenIn,
        address tokenInReceiver,
        uint256 value
    )
        internal
    {
        // Execute the batch of arbitrary calls.
        MultiCaller(payable(ARBITER)).multiCallWithDrainToken{ value: value }(multicalls, tokenIn, tokenInReceiver);
    }

    /**
     * @notice Checks if adapter supports a given function selector
     * @dev Used for interface detection and compatibility checks
     * @param selector Function selector to check
     * @return True if the selector is supported by this adapter
     */
    function supportsInterface(bytes4 selector) public pure override(AdapterBase, Caller) returns (bool) {
        return selector == this.multicall_handleFill.selector || selector == this.multicall_handleJITClaim.selector
            || selector == this.multicall_handlePayable.selector || AdapterBase.supportsInterface(selector)
            || Caller.supportsInterface(selector) || selector == type(IAdapter).interfaceId;
    }
}
