// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IIntentExecutor } from "../../../interfaces/IIntentExecutor.sol";
import { ICompactIntentExecutor } from "../../../executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "../../../executor/interfaces/IPermit2Intent.sol";
import { SmartExecutionLib } from "../../../common/SmartExecutionLib.sol";
import { ExcessivelySafeCall } from "@excessivelySafeCall/ExcessivelySafeCall.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IAddressBook } from "../../../common/AddressBook/IAddressBook.sol";
import { Constants } from "../../../types/Constants.sol";
import { Caller, MultiCaller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";

/**
 * @title PreClaimExecution
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Abstract contract enabling arbiters to execute pre-claim operations on ERC7579 accounts
 *         before TheCompact's claim function is called. This allows using a single user signature
 *         to authorize both pre-claim operations (like topping up locked assets) and the main claim.
 *
 * @dev CRITICAL DESIGN FEATURE: Pre-claim operations are designed to be failure-tolerant.
 *      This prevents "fill first, claim later" flows from being broken by failed pre-claim executions,
 *      which would void the claim and could lead to double-spend attacks.
 *
 * @dev SECURITY WARNING: Claims requiring pre-claim executions to top up TheCompact's resource lock
 *      MUST NOT be processed in "fill first, claim later" flows. They must use Just-In-Time (JIT) flows
 *      to prevent double spend and ensure atomic execution.
 *
 * @dev KEY BENEFITS:
 *      - Single signature workflow: Users sign once to authorize multiple operations
 *      - Flexible execution: Supports arbitrary ERC7579 operations on the origin chain
 *      - Atomic settlement: Pre-claim ops and claims happen in the same transaction (JIT flow)
 *      - Resource management: Enables dynamic topping up of TheCompact's locked assets
 */
abstract contract PreClaimExecution {
    using IdLib for uint256;
    using SmartExecutionLib for Types.Operation;
    using ExcessivelySafeCall for address;

    /**
     * @notice The IIntentExecutor instance used for executing pre-claim operations on ERC7579 accounts
     * @dev This executor handles the actual execution of operations signed over by TheCompact claimHash.
     *      The executor validates signatures and executes operations on ERC7579 modular smart accounts.
     */
    IIntentExecutor public immutable EXECUTOR;

    /**
     * @notice Universal caller contract used for executing multicall and direct call operations
     * @dev This caller is used for non-ERC7579 execution modes (Multicall and CallData modes).
     *      It provides a neutral execution context separate from the arbiter's address.
     * @custom:security CRITICAL ISOLATION: The Caller contract isolates SameChainArbiter from
     *                  multicall/singlecall execution contexts. Without this isolation, malicious
     *                  pre-claim operations could potentially call executeWithoutSignature on the
     *                  IntentExecutor using the arbiter's trusted status, bypassing signature validation.
     */
    Caller internal immutable CALLER;

    /**
     * @notice Emitted when a pre-claim operation execution fails
     * @dev This event is logged when pre-claim operations fail but do not revert the transaction.
     *      Failure tolerance is a critical design feature to prevent double-spend attacks in
     *      "fill first, claim later" workflows.
     */
    event PreClaimExecutionFailed();

    /**
     * @notice Thrown when insufficient gas is available to satisfy the minGas requirement
     * @dev This error prevents EIP-150 63/64 rule exploitation where deep call stacks
     *      reduce available gas below the user's signed minGas requirement
     * @param required The amount of gas required (including EIP-150 buffer)
     * @param available The actual gas available at execution time
     */
    error InsufficientGasForMinGas(uint256 required, uint256 available);

    /**
     * @notice Initializes the PreClaimExecution contract with required execution infrastructure
     * @dev Sets up both ERC7579 and general-purpose execution capabilities by initializing:
     *      1. EXECUTOR: Retrieved from AddressBook for ERC7579 smart account operations
     *      2. CALLER: New instance for multicall and direct call operations
     *
     * @param addressBook The AddressBook contract containing protocol addresses
     * @custom:security The AddressBook must be trusted as it provides the IIntentExecutor address
     * @custom:gas Creates a new Caller contract instance, consuming ~200k gas during deployment
     */
    constructor(address addressBook) {
        // Retrieve the IIntentExecutor from the trusted AddressBook registry
        // This executor handles ERC7579 operations with signature validation
        EXECUTOR = IIntentExecutor(IAddressBook(addressBook).getAddress(Constants.INTENT_EXECUTOR_ID));

        // Deploy a new Caller contract for non-ERC7579 execution modes
        // This provides a neutral execution context for multicall and direct operations
        CALLER = new Caller();
    }

    /**
     * @notice Validates that sufficient gas is available to satisfy the minGas requirement
     * @dev Accounts for EIP-150's 63/64 rule: when making a call, only 63/64 of remaining gas
     *      is forwarded. To ensure `minGas` is available in the subcall, we need:
     *      requiredGas = minGas + (minGas / 63) + buffer
     *
     *      The 10k buffer covers execution overhead between the check and the actual call.
     *      This protects against griefing attacks where callers provide just enough gas to
     *      pass validation but not enough to execute the operation.
     * @param gasStipend The minimum gas that must be available for the subcall
     * @custom:security Reverts with InsufficientGasForMinGas if gas requirement is not met
     */
    function _requireValidGasLeft(uint256 gasStipend) private view {
        if (gasStipend > 0) {
            uint256 requiredGas = gasStipend + (gasStipend / 63) + 10_000;
            if (gasleft() < requiredGas) {
                revert InsufficientGasForMinGas(requiredGas, gasleft());
            }
        }
    }

    /**
     * @notice Wrapper function that executes pre-claim operations with signature mode-specific success logic
     * @dev This function validates gas requirements, executes pre-claim operations, and applies
     *      mode-specific success criteria based on the signature validation mode.
     *
     * @dev REVERT CONDITIONS:
     *      This function CAN revert via _requireValidGasLeft() if there is insufficient gas to
     *      safely execute the operation. This affects ALL modes including EMISSARY.
     *      Required gas = preClaimGasStipend + (preClaimGasStipend / 63) + 10_000
     *
     * @dev SUCCESS LOGIC BY MODE:
     *
     *      EMISSARY (Fill-First) Mode: success = !okGas || okSig
     *      ┌─────────┬─────────┬──────────────────────────────────────────────────┐
     *      │ okGas   │ okSig   │ Result                                           │
     *      ├─────────┼─────────┼──────────────────────────────────────────────────┤
     *      │ true    │ true    │ ✅ true (call succeeded, sig valid)              │
     *      │ true    │ false   │ ❌ false (call succeeded, sig invalid)           │
     *      │ false   │ any     │ ✅ true (call failed/OOG, skip pre-claim)        │
     *      └─────────┴─────────┴──────────────────────────────────────────────────┘
     *      In fill-first mode, if the call fails (revert/OOG), we skip pre-claim
     *      validation and proceed. This prevents pre-claim failures from breaking
     *      the fill. However, if the call succeeds but signature is invalid, we FAIL.
     *
     *      Claim-First Mode: success = okGas && okSig
     *      ┌─────────┬─────────┬──────────────────────────────────────────────────┐
     *      │ okGas   │ okSig   │ Result                                           │
     *      ├─────────┼─────────┼──────────────────────────────────────────────────┤
     *      │ true    │ true    │ ✅ true (call succeeded, sig valid)              │
     *      │ true    │ false   │ ❌ false (call succeeded, sig invalid)           │
     *      │ false   │ any     │ ❌ false (call failed/OOG)                       │
     *      └─────────┴─────────┴──────────────────────────────────────────────────┘
     *      In claim-first mode, both the gas check and signature must succeed.
     *
     * @param account The ERC7579 smart account to execute operations on
     * @param order The order containing nonce, expires, and preClaimOps
     * @param signature Container with preClaimSig and notarizedClaimSig
     * @param elementStub EIP-712 element stub containing element hashes for cross-chain validation
     * @param notarizedChainId The chain ID for the notarized chain (used in compact stub)
     * @param preClaimGasStipend Gas limit for pre-claim execution (also triggers gas validation)
     * @param sigMode Signature validation mode (EMISSARY for fill-first, others for claim-first)
     * @return success Mode-specific success result (see SUCCESS LOGIC table above)
     * @custom:security REVERTS on insufficient gas via _requireValidGasLeft() for ALL modes
     */
    function _handlePreClaimOpsCompactERC7579(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signature,
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend,
        SmartExecutionLib.SigMode sigMode
    )
        internal
        returns (bool success)
    {
        ICompactIntentExecutor.EIP712CompactStub memory compactStub =
            ICompactIntentExecutor.EIP712CompactStub(order.nonce, order.expires, notarizedChainId);
        _requireValidGasLeft(preClaimGasStipend);
        (bool okGas, bool okSig, bool okExec) =
            _handlePreClaimOpsCompactERC7579(account, order, signature, elementStub, compactStub, preClaimGasStipend);

        // fill first mode: pass if no gas (skip pre-claim) or if sig valid
        // claim first mode: require both gas stipend and sig validation to pass
        success = (sigMode == SmartExecutionLib.SigMode.EMISSARY) ? (!okGas || okSig) : (okGas && okSig);
    }

    /**
     * @notice Executes pre-claim ERC7579 operations on a smart account with detailed return values
     * @dev This function is FULLY FAILURE-TOLERANT. It NEVER reverts - all failures are captured
     *      in return values. This design prevents "fill first, claim later" flows from being broken
     *      by execution failures that could lead to double-spend attacks.
     *
     * @dev EXECUTION FLOW:
     *      1. Calls IIntentExecutor.executePreClaimOpsWithCompactStub via excessivelySafeCall
     *      2. Enforces strict gas limit (preClaimGasStipend) to prevent griefing attacks
     *      3. Uses preClaimSig if available, otherwise falls back to notarizedClaimSig
     *      4. Decodes two boolean return values: sigOk and execOk
     *      5. Returns all results without reverting, even on total failure
     *
     * @dev RETURN VALUE SEMANTICS:
     *      - success (okGas): True if excessivelySafeCall succeeded (no revert/OOG)
     *      - sigOk: True if signature validation passed (only valid if success=true)
     *      - execOk: True if pre-claim operations executed successfully (only valid if success=true)
     *
     *      Return Value Scenarios:
     *      ┌─────────┬─────────┬─────────┬───────────────────────────────────────┐
     *      │ success │ sigOk   │ execOk  │ Meaning                               │
     *      ├─────────┼─────────┼─────────┼───────────────────────────────────────┤
     *      │ true    │ true    │ true    │ ✅ Everything succeeded               │
     *      │ true    │ true    │ false   │ ⚠️ Sig valid, but execution failed    │
     *      │ true    │ false   │ false   │ ❌ Signature validation failed        │
     *      │ false   │ false   │ false   │ ❌ Call reverted or ran out of gas    │
     *      └─────────┴─────────┴─────────┴───────────────────────────────────────┘
     *
     * @dev GAS PROTECTION:
     *      - preClaimGasStipend enforces strict gas limit via excessivelySafeCall
     *      - Prevents infinite loops, excessive gas consumption, and griefing attacks
     *      - Failed operations due to gas limits are captured in return values
     *
     * @dev SIGNATURE SELECTION:
     *      Uses preClaimSig if present (length > 0), otherwise falls back to notarizedClaimSig.
     *      This allows flexible signature management while maintaining EIP-712 security.
     *
     * @param account The ERC7579 smart account to execute operations on
     * @param order The order containing nonce, expires, and preClaimOps
     * @param signature Container with preClaimSig and notarizedClaimSig
     * @param elementStub EIP-712 element stub containing element hashes for cross-chain validation
     * @param compactStub EIP-712 compact stub containing nonce, expires, and notarizedChainId
     * @param preClaimGasStipend Gas limit for pre-claim execution
     * @return success True if the call completed without revert/OOG (does NOT mean execution succeeded)
     * @return sigOk True if signature validation passed (only meaningful if success=true)
     * @return execOk True if pre-claim operations executed successfully (only meaningful if success=true)
     * @custom:security NEVER REVERTS - all failures are captured in return values
     * @custom:security Enforces gas limit to prevent griefing and runaway execution
     */
    function _handlePreClaimOpsCompactERC7579(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signature,
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        ICompactIntentExecutor.EIP712CompactStub memory compactStub,
        uint256 preClaimGasStipend
    )
        internal
        returns (bool success, bool sigOk, bool execOk)
    {
        // Execute pre-claim operations using excessivelySafeCall for gas-limited, failure-tolerant execution
        // This prevents griefing attacks where malicious operations consume all available gas
        // or cause reverts that would break the entire claim process

        // Validate sufficient gas before executing pre-claim operations
        // Prevents EIP-150 griefing where callers starve subcalls of gas
        bytes memory ret;
        (success, ret) = address(EXECUTOR)
            .excessivelySafeCall({
                _gas: preClaimGasStipend, // Strict gas limit prevents griefing and ensures bounded execution
                _value: 0, // No ETH transfer required for pre-claim operations
                _maxCopy: 64, // Copy return data to retrieve both sigOk and execOk booleans
                _calldata: abi.encodeCall(
                    ICompactIntentExecutor.executePreClaimOpsWithCompactStub,
                    (
                        account, // The ERC7579 smart account to execute operations on
                        compactStub, // EIP-712 compact stub for signature validation context
                        elementStub, // EIP-712 element stub for cross-chain operation validation
                        order.preClaimOps, // The actual operations to execute (approvals, transfers, etc.)
                        // SIGNATURE SELECTION LOGIC: Use dedicated preClaimSig if available,
                        // otherwise fall back to notarizedClaimSig. This allows flexibility in
                        // signature management while maintaining security through EIP-712 validation.
                        (signature.preClaimSig.length != 0) ? signature.preClaimSig : signature.notarizedClaimSig
                    )
                )
            });

        // Decode both return values (sigOk, execOk) if call succeeded and returned data
        if (success && ret.length >= 64) {
            assembly ("memory-safe") {
                sigOk := mload(add(ret, 32)) // sigOk at first 32 bytes
                execOk := mload(add(ret, 64)) // execOk at second 32 bytes
            }
        }
    }

    /**
     * @notice Executes pre-claim ERC7579 operations on a smart account before Permit2 claim
     * @dev This function is DESIGNED TO BE FAILURE-TOLERANT. Failed pre-claim operations do not
     *     revert the entire transaction.
     *
     * @dev EXECUTION FLOW:
     *     1. Converts preClaimOps to ERC7579 execution format
     *     2. Calls IPermit2IntentExecutor with gas-limited execution via excessivelySafeCall
     *     3. Uses Permit2 EIP-712 signature for authorization
     *    4. Returns success status without reverting on failure
     * @dev GAS CONSIDERATIONS:
     *    - preClaimGasStipend limits execution gas to prevent griefing
     *   - Gas-limited execution prevents infinite loops or excessive gas consumption
     *  - Failed operations due to gas limits do not affect the main claim process
     * @param account The ERC7579 smart account to execute operations on
     * @param permit2Stub The Permit2 EIP-712 stub with nonce and expiration
     * @param mandateStub The Permit2 mandate stub with operation and token hashes
     * @param preClaimOps The operations to execute (approvals, transfers, etc.)
     * @param signature The Permit2 EIP-712 signature authorizing the operations
     * @param preClaimGasStipend Maximum gas allowed for pre-claim execution
     * @return success True if execution succeeded, false if it failed (does not revert)
     */
    function _handlePreClaimOpsPermit2ERC7579(
        address account,
        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature,
        uint256 preClaimGasStipend
    )
        internal
        returns (bool success)
    {
        // Validate sufficient gas before executing pre-claim operations
        // Prevents EIP-150 griefing where callers starve subcalls of gas
        _requireValidGasLeft(preClaimGasStipend);
        // Execute pre-claim operations using excessivelySafeCall for gas-limited, failure-tolerant execution
        // This prevents griefing attacks where malicious operations consume all available gas
        // or cause reverts that would break the entire claim process
        (success,) = address(EXECUTOR)
            .excessivelySafeCall({
                _gas: preClaimGasStipend, // Strict gas limit prevents griefing and ensures bounded execution
                _value: 0, // No ETH transfer required for pre-claim operations
                _maxCopy: 0, // Don't copy return data to save gas (we only care about success)
                _calldata: abi.encodeCall(
                    IPermit2IntentExecutor.executePreClaimOpsWithPermit2Stub,
                    (
                        account, // The ERC7579 smart account to execute operations on
                        permit2Stub, // EIP-712 Permit2 stub for signature validation context
                        mandateStub, // EIP-712 Mandate stub for operation and token hashes
                        preClaimOps, // The actual operations to execute (approvals, transfers, etc.)
                        signature // The Permit2 EIP-712 signature authorizing the operations
                    )
                )
            });

        // Log execution failure for monitoring and debugging purposes
        // This does NOT revert the transaction - failure tolerance is intentional
        if (!success) emit PreClaimExecutionFailed();
    }

    /**
     * @notice Executes pre-claim operations using multicall pattern for batch operations
     * @dev This execution mode is used for non-ERC7579 accounts or when batch operations
     *      need to be executed in a single transaction without smart account infrastructure.
     *
     * @dev MULTICALL EXECUTION FLOW:
     *      1. Extracts multicall data from preClaimOps.data (skipping first 2 bytes)
     *      2. Prepends MultiCaller.multiCall selector to create valid calldata
     *      3. Executes via CALLER contract with gas limit protection
     *      4. Returns success status without reverting on failure
     *
     * @dev DATA ENCODING: The preClaimOps.data format is:
     *      - Bytes 0-1: Operation type identifier (skipped with [2:])
     *      - Bytes 2+: Actual multicall data (target addresses, values, calldata)
     *
     * @param preClaimOps The operation containing multicall data to execute
     * @param preClaimGasStipend Maximum gas allowed for multicall execution
     * @return success True if execution succeeded, false if it failed (does not revert)
     * @custom:security EXECUTION ISOLATION: Uses CALLER contract to isolate execution context
     *                  from the arbiter. This prevents malicious operations from exploiting the
     *                  arbiter's trusted status to call executeWithoutSignature on IntentExecutor.
     * @custom:gas Gas stipend prevents unbounded execution and griefing attacks
     */
    function _handlePreClaimOpsMulticall(Types.Operation calldata preClaimOps, uint256 preClaimGasStipend) internal returns (bool success) {
        // Validate sufficient gas before executing pre-claim operations
        // Prevents EIP-150 griefing where callers starve subcalls of gas
        _requireValidGasLeft(preClaimGasStipend);
        // Execute multicall operations using the neutral CALLER contract
        // This provides isolation from the arbiter's address and state
        (success,) = address(CALLER)
            .excessivelySafeCall({
                _gas: preClaimGasStipend, // Enforce gas limit to prevent griefing
                _value: 0, // No ETH transfer for multicall operations
                _maxCopy: 0, // Don't copy return data to save gas
                // Construct multicall by prepending selector to operation data (skipping type bytes)
                // Format: MultiCaller.multiCall.selector + preClaimOps.data[2:]
                _calldata: abi.encodePacked(MultiCaller.multiCall.selector, preClaimOps.onlyExecutionData())
            });

        // Log failure for monitoring without reverting the transaction
        if (!success) emit PreClaimExecutionFailed();
    }

    /**
     * @notice Executes a single pre-claim operation using direct calldata execution
     * @dev This execution mode provides the most direct way to execute arbitrary contract calls
     *      during the pre-claim phase. It's typically used for simple operations like token
     *      approvals, transfers, or single contract interactions.
     *
     * @dev CALLDATA EXECUTION FLOW:
     *      1. Combines target address with calldata to create executable payload
     *      2. Executes via CALLER contract with gas limit protection
     *      3. Returns success status without reverting on failure
     *      4. Provides maximum flexibility for arbitrary contract interactions
     *
     * @dev ENCODING FORMAT: The execution payload is constructed as:
     *      abi.encodePacked(target, callData)
     *      Where target is the 20-byte contract address and callData is the function call data
     *
     * @dev USE CASES:
     *      - Token approvals before claim execution
     *      - Balance transfers to meet claim requirements
     *      - State updates on external contracts
     *      - Simple contract interactions without batch requirements
     *
     * @param target The contract address to call during pre-claim execution
     * @param callData The function selector and encoded parameters for the contract call
     * @param preClaimGasStipend Maximum gas allowed for the contract call
     * @return success True if execution succeeded, false if it failed (does not revert)
     * @custom:security EXECUTION ISOLATION: Uses CALLER contract to isolate execution context
     *                  from the arbiter. This prevents malicious operations from exploiting the
     *                  arbiter's trusted status to call executeWithoutSignature on IntentExecutor.
     * @custom:security Target contract must be trusted as it receives arbitrary calldata
     * @custom:gas Gas stipend prevents runaway execution and ensures bounded gas usage
     */
    function _handlePreClaimOpsCallData(
        address target,
        bytes calldata callData,
        uint256 preClaimGasStipend
    )
        internal
        returns (bool success)
    {
        // Validate sufficient gas before executing pre-claim operations
        // Prevents EIP-150 griefing where callers starve subcalls of gas
        _requireValidGasLeft(preClaimGasStipend);
        // Execute direct contract call using the neutral CALLER contract
        // This isolates the execution context from the arbiter contract
        (success,) = address(CALLER)
            .excessivelySafeCall({
                _gas: preClaimGasStipend, // Strict gas limit to prevent griefing attacks
                _value: 0, // No ETH transfer for direct calls
                _maxCopy: 0, // Don't copy return data to optimize gas usage
                // Encode target address with calldata to create executable payload
                // Format: [20 bytes target][N bytes callData]
                _calldata: abi.encodePacked(target, callData)
            });

        // Log execution failure for monitoring and debugging purposes
        // Failure does NOT revert to maintain failure-tolerant design
        if (!success) emit PreClaimExecutionFailed();
    }
}
