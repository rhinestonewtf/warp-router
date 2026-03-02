// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { CompactArbiter } from "./CompactArbiter/CompactArbiter.sol";
import { Constants } from "../../types/Constants.sol";
import { EIP712TypeHashLib } from "../../types/EIP712TypeHashLib.sol";
import { ICompactIntentExecutor } from "../../executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "../../executor/interfaces/IPermit2Intent.sol";
import { Permit2Arbiter } from "./Permit2Arbiter/Permit2Arbiter.sol";
import { PreClaimExecution } from "./lib/PreClaimExecution.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IArbiter } from "../../interfaces/IArbiter.sol";

/**
 * @title ArbiterBase
 * @notice Base arbiter contract that enables unlocking funds from user accounts or resource locks
 * @dev This contract serves as a critical component in the Warp Routerr ecosystem, acting as
 *      an arbiter that can unlock and manage funds on behalf of users. It provides dual protocol
 *      support for both TheCompact and Permit2 standards, enabling flexible settlement mechanisms.
 *
 *      Key responsibilities:
 *      - Executes pre-claim operations before settlement
 *      - Computes mandate hashes for protocol validation
 *      - Maintains Router-only access control for security
 *      - Orchestrates the settlement flow for both Compact and Permit2 protocols
 *
 *      Security model: Only the Router can call settlement functions, preventing unauthorized
 *      access to user funds and ensuring proper validation of all operations.
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 */
contract ArbiterBase is CompactArbiter, Permit2Arbiter, PreClaimExecution, IArbiter {
    using EIP712TypeHashLib for *;
    using SmartExecutionLib for Types.Operation;
    using SmartExecutionLib for bytes;
    using SmartExecutionLib for SmartExecutionLib.SigMode;
    using Types for uint256;

    /// @dev The Router address that has exclusive access to settlement functions
    address internal immutable ROUTER;

    /**
     * @notice Thrown when a function is called by an address other than the authorized Router
     * @dev This error enforces the critical security boundary that prevents unauthorized entities
     *      from executing settlement operations or accessing user funds through the arbiter
     */
    error OnlyRouter();

    /**
     * @notice Thrown when a claim includes operations but the arbiter requires none
     * @dev This error is raised when the operation hash does not match the NO_OPS constant,
     *      indicating that executable operations are present where they should not be.
     *      Used by the requireNoOps modifier to enforce operation-free claim flows.
     */
    error NoOperationsAllowed();

    /**
     * @notice Initializes the ArbiterBase with protocol addresses and access control
     * @dev Sets up the inheritance chain for Compact, Permit2, and PreClaim functionality.
     *      The router address is stored as immutable for gas efficiency and security.
     * @param router The Router contract address that will have exclusive access to settlement functions
     * @param compact The TheCompact protocol contract address for Compact-based settlements
     * @param addressBook The addressbook for lookup
     */
    constructor(
        address router,
        address compact,
        address addressBook
    )
        CompactArbiter(compact)
        Permit2Arbiter(address(Constants.PERMIT2))
        PreClaimExecution(addressBook)
    {
        ROUTER = router;
    }

    /**
     * @notice Modifier to enforce that a claim function does not include any operations
     * @dev Use this modifier when arbiters want to restrict claim functions to pure token transfers
     *      without any additional pre-claim or destination operations. This is useful for:
     *      - Simple settlement flows that only require token movement
     *      - Security-sensitive contexts where operation execution should be prohibited
     *      - Gas-optimized paths that skip operation processing overhead
     *
     *      The modifier validates that the operation hash equals the NO_OPS constant,
     *      which represents an empty operation set.
     * @param ops The operation to validate as empty
     * @custom:security Reverts with NoOperationsAllowed if any operations are present
     */
    modifier requireNoOps(Types.Operation calldata ops) {
        _requireNoOps(ops);
        _;
    }

    /**
     * @notice Internal function to validate that an operation set is empty
     * @dev Computes the hash of the provided operations and compares against the NO_OPS constant.
     *      This check ensures no executable operations are included in the claim, preventing
     *      any code execution beyond the base settlement logic.
     * @param ops The operation to validate as empty
     */
    function _requireNoOps(Types.Operation calldata ops) private pure {
        require(ops.hashOps() == Constants.NO_OPS, NoOperationsAllowed());
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
     * @param minGas The minimum gas that must be available for the subcall
     */
    function _requireValidGasLeft(uint128 minGas) private view {
        if (minGas > 0) {
            uint256 requiredGas = uint256(minGas) + (uint256(minGas) / 63) + 10_000;
            if (gasleft() < requiredGas) {
                revert InsufficientGasForMinGas(requiredGas, gasleft());
            }
        }
    }

    /**
     * @notice Handles pre-claim operations and computes the mandate hash for TheCompact integration
     * @dev This function orchestrates the pre-settlement validation and execution flow:
     *      1. Computes various EIP-712 hashes for order components
     *      2. Executes pre-claim operations if they exist and are ERC7579 type
     *      3. Returns the mandate hash needed for TheCompact claims
     * @param order The order containing all settlement data
     * @param sigs The signatures required for validation
     * @param otherElements Additional elements for cross-chain validation
     * @param elementOffset The offset for element processing
     * @param notarizedChainId The chain ID where the order was notarized
     * @return mandateHash The computed mandate hash for TheCompact claim operations
     */
    function _compactPreClaimOps(
        Types.Order calldata order,
        Types.Signatures calldata sigs,
        bytes32[] calldata otherElements,
        uint256 elementOffset,
        uint256 notarizedChainId
    )
        internal
        returns (bytes32 mandateHash)
    {
        // using malloc here to avoid stack too deep
        bytes32 targetAttributesHash = order.hashTargetAttributes();
        bytes32 qHash = order.qualifier.hashQualifierData();
        (uint128 preClaimGasStipend, uint128 minGas) = Types.splitGasStipend(order.packedGasValues);

        // Compute EIP-712 hashes for all order components
        bytes32 destOpsHash = order.targetOps.hashOps();

        // Determine if pre-claim operations need to be executed
        // Returns the type of operation and its hash for validation

        (SmartExecutionLib.Type opsType, bytes32 preClaimOpsHash) = order.preClaimOps.decodeAll();

        // Execute pre-claim operations if they exist and are ERC7579 type
        // Check 1: preClaimOpsHash != NO_OPS ensures there are actual operations to execute
        if (preClaimOpsHash != Constants.NO_OPS) {
            // Check 2: opsType == ERC7579 ensures operations follow the ERC7579 smart account standard
            if (opsType == SmartExecutionLib.Type.ERC7579) {
                // Execute ERC7579 operations for Compact protocol
                // Uses sponsor account, pre-claim operations, and signature validation
                bool success = _handlePreClaimOpsCompactERC7579({
                    account: order.sponsor,
                    order: order,
                    signature: sigs,
                    elementStub: ICompactIntentExecutor.EIP712ElementStubOrigin({
                        otherElements: otherElements,
                        minGas: minGas,
                        elementOffset: elementOffset,
                        destOpsHash: destOpsHash,
                        tokenInHash: order.tokenIn.hashTokenIn(),
                        targetAttributesHash: targetAttributesHash,
                        qHash: qHash
                    }),
                    notarizedChainId: notarizedChainId,
                    preClaimGasStipend: preClaimGasStipend,
                    sigMode: order.preClaimOps.extractSigMode()
                });
                require(success);
            }
            // Check 2: opsType == MultiCall handles batched operations
            else if (opsType == SmartExecutionLib.Type.MultiCall) {
                // Handle batched operations through multicall pattern
                // Allows multiple contract calls in a single transaction
                _handlePreClaimOpsMulticall({ preClaimOps: order.preClaimOps, preClaimGasStipend: preClaimGasStipend });
            }
            // Check 2: opsType == Calldata handles raw calldata execution
            else if (opsType == SmartExecutionLib.Type.Calldata) {
                // Handle raw calldata execution for simple contract calls
                // Extract target address and calldata from the operation

                (address target, bytes calldata callData) = SmartExecutionLib.toCalldata(order.preClaimOps.onlyExecutionData());
                _handlePreClaimOpsCallData({ target: target, callData: callData, preClaimGasStipend: preClaimGasStipend });
            }
        }

        // Construct the mandate hash that TheCompact will use for validation
        // This hash uniquely identifies the entire order and its operations
        mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttributesHash, minGas: minGas, preClaimOpsHash: preClaimOpsHash, destOpsHash: destOpsHash, qHash: qHash
        });
    }

    /**
     * @notice Handles pre-claim operations and computes the mandate hash for Permit2 integration
     * @dev This function orchestrates the pre-settlement validation and execution flow for Permit2:
     *      1. Computes EIP-712 hashes for all order components (target attributes, operations, qualifier)
     *      2. Executes pre-claim operations if they exist and are ERC7579 type
     *      3. Returns the mandate hash needed for Permit2 claims
     *
     *      Unlike Compact integration, Permit2 uses a different stub structure and execution path
     *      but maintains the same core validation and mandate hash computation logic.
     * @param order The order containing all settlement data including sponsor, operations, and tokens
     * @param sigs The signatures required for validation, specifically uses notarizedClaimSig for Permit2
     * @return mandateHash The computed mandate hash that Permit2 will use for settlement validation
     * @custom:security Pre-claim operations are executed with proper signature validation through Permit2 stub
     * @custom:gas Operations are only executed if preClaimOpsHash != NO_EXEC to avoid unnecessary gas costs
     */

    function _permit2PreClaimOps(Types.Order calldata order, Types.Signatures calldata sigs) internal returns (bytes32 mandateHash) {
        (uint128 preClaimGasStipend, uint128 minGas) = Types.splitGasStipend(order.packedGasValues);

        // Compute EIP-712 hashes for all order components
        bytes32 targetAttributesHash = order.hashTargetAttributes();
        bytes32 destOpsHash = order.targetOps.hashOps();
        bytes32 qHash = order.qualifier.hashQualifierData();

        // Determine if pre-claim operations need to be executed
        // Returns the type of operation and its hash for validation
        (SmartExecutionLib.Type opsType, bytes32 preClaimOpsHash) = order.preClaimOps.decodeAll();

        // Execute pre-claim operations if they exist and are ERC7579 type
        // Check 1: preClaimOpsHash != NO_OPS ensures there are actual operations to execute
        if (preClaimOpsHash != Constants.NO_OPS) {
            // Execute pre-claim operations if they exist and are ERC7579 type
            // Check 1: preClaimOpsHash != NO_OPS ensures there are actual operations to execute
            // Check 2: opsType == ERC7579 ensures operations follow the ERC7579 smart account standard
            if (opsType == SmartExecutionLib.Type.ERC7579) {
                // Execute ERC7579 operations for Permit2 protocol
                // Uses sponsor account, pre-claim operations, and notarized claim signature
                _handlePreClaimOpsPermit2ERC7579({
                    account: order.sponsor,
                    preClaimOps: order.preClaimOps,
                    signature: sigs.preClaimSig.length != 0 ? sigs.preClaimSig : sigs.notarizedClaimSig,
                    permit2Stub: IPermit2IntentExecutor.EIP712Permit2Stub(order.nonce, order.expires),
                    mandateStub: IPermit2IntentExecutor.EIP712Permit2MandateStub(
                        order.tokenIn.hashTokenPermissions(), minGas, targetAttributesHash, destOpsHash, qHash
                    ),
                    preClaimGasStipend: preClaimGasStipend
                });
            } else if (opsType == SmartExecutionLib.Type.MultiCall) {
                // Handle batched operations through multicall pattern
                // Allows multiple contract calls in a single transaction

                _handlePreClaimOpsMulticall({ preClaimOps: order.preClaimOps, preClaimGasStipend: preClaimGasStipend });
            } else if (opsType == SmartExecutionLib.Type.Calldata) {
                // Handle raw calldata execution for simple contract calls
                // Extract target address and calldata from the operation

                (address target, bytes calldata callData) = SmartExecutionLib.toCalldata(order.preClaimOps.onlyExecutionData());
                _handlePreClaimOpsCallData({ target: target, callData: callData, preClaimGasStipend: preClaimGasStipend });
            }
        }

        // Construct the mandate hash that Permit2 will use for validation
        // This hash uniquely identifies the entire order and its operations
        mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttributesHash, minGas: minGas, preClaimOpsHash: preClaimOpsHash, destOpsHash: destOpsHash, qHash: qHash
        });
    }

    /**
     * @notice Restricts function access to only the authorized Router contract
     * @dev This modifier is critical for maintaining the security model of the arbiter system.
     *      It ensures that only the Router can execute settlement operations, preventing:
     *      - Unauthorized access to user funds
     *      - Bypass of Router's validation logic
     *      - Direct manipulation of arbiter state
     * @custom:security This is the primary access control mechanism for all settlement functions
     */
    modifier onlyRouter() {
        _onlyRouter();
        _;
    }

    /**
     * @notice Internal function to validate Router-only access
     * @dev Ensures that settlement operations maintain proper access control within the Router ecosystem
     */
    function _onlyRouter() internal virtual {
        // Verify caller is the authorized Router - critical security check
        // This prevents unauthorized entities from executing settlement operations
        require(msg.sender == ROUTER, OnlyRouter());
    }

    /**
     * @notice Returns the hash of the qualifier data for mandate validation
     * @param data The qualifier data to hash
     */
    function qualificationHash(bytes calldata data) external pure virtual returns (bytes32 result) {
        return data.hashQualifierData();
    }

    function supportsInterface(bytes4 selector) public pure virtual returns (bool) {
        return selector == this.supportsInterface.selector || selector == type(IArbiter).interfaceId;
    }
}
