// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IIntentExecutor } from "../../../src/interfaces/IIntentExecutor.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Types } from "../../../src/types/OrderTypes.sol";
import { SmartExecutionLib } from "../../../src/common/SmartExecutionLib.sol";
import { IPermit2IntentExecutor } from "../../../src/executor/interfaces/IPermit2Intent.sol";

/**
 * @title MockIntentExecutor
 * @notice Mock implementation of IIntentExecutor for testing PreClaimExecution
 * @dev Provides configurable success/failure modes, gas consumption simulation,
 *      and detailed execution tracking for comprehensive testing
 */
contract MockIntentExecutor is IIntentExecutor {
    // Execution modes
    enum ExecutionMode {
        SUCCESS,
        REVERT,
        OUT_OF_GAS,
        RETURN_FALSE
    }

    // Configuration
    ExecutionMode public executionMode = ExecutionMode.SUCCESS;
    uint256 public gasToConsume = 0;
    bytes32 public returnClaimHash = keccak256("mock_claim_hash");
    bytes public returnData = "";
    bool public shouldConsumeAllGas = false;

    // Tracking
    struct ExecutionCall {
        address account;
        EIP712CompactStub compactStub;
        EIP712ElementStubOrigin elementStub;
        Execution[] preClaimOps;
        bytes signature;
        uint256 gasProvided;
    }

    ExecutionCall[] public executionCalls;
    uint256 public executionCallCount;

    // Events for testing
    event PreClaimExecutionCalled(address indexed account, uint256 gasProvided, uint256 gasConsumed, bool success);

    // Configuration functions
    function setExecutionMode(ExecutionMode _mode) external {
        executionMode = _mode;
    }

    function setGasToConsume(uint256 _gas) external {
        gasToConsume = _gas;
    }

    function setReturnClaimHash(bytes32 _hash) external {
        returnClaimHash = _hash;
    }

    function setReturnData(bytes calldata _data) external {
        returnData = _data;
    }

    function setShouldConsumeAllGas(bool _consume) external {
        shouldConsumeAllGas = _consume;
    }

    // Reset function for test isolation
    function reset() external {
        executionMode = ExecutionMode.SUCCESS;
        gasToConsume = 0;
        returnClaimHash = keccak256("mock_claim_hash");
        returnData = "";
        shouldConsumeAllGas = false;
        delete executionCalls;
        executionCallCount = 0;
    }

    // IIntentExecutor implementation
    function executePreClaimOpsWithCompactStub(
        address account,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubOrigin calldata elementStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        returns (bool sigOk, bool execOk)
    {
        uint256 gasStart = gasleft();

        // Store execution call for verification (simplified to avoid gas issues)
        executionCallCount++;

        // Store only essential data to avoid expensive array operations
        if (executionCalls.length < executionCallCount) {
            ExecutionCall memory call = ExecutionCall({
                account: account,
                compactStub: compactStub,
                elementStub: elementStub,
                preClaimOps: new Execution[](0), // Don't copy operations to save gas
                signature: signature,
                gasProvided: gasStart
            });
            executionCalls.push(call);
        }

        // Simulate gas consumption only if configured
        if (shouldConsumeAllGas) {
            // Consume all available gas
            uint256 gasLeft = gasleft();
            if (gasLeft > 10_000) {
                _consumeGas(gasLeft - 10_000);
            }
        } else if (gasToConsume > 0 && gasToConsume < gasleft() - 5000) {
            // Only consume gas if we have enough left
            _consumeGas(gasToConsume);
        }

        uint256 gasConsumed = gasStart - gasleft();

        // Handle execution mode
        if (executionMode == ExecutionMode.REVERT) {
            revert("MockIntentExecutor: Simulated revert");
        } else if (executionMode == ExecutionMode.OUT_OF_GAS) {
            // Consume remaining gas to simulate out of gas
            _consumeGas(gasleft());
        }

        bool success = executionMode == ExecutionMode.SUCCESS;

        emit PreClaimExecutionCalled(account, gasStart, gasConsumed, success);

        // Return signature validation result and execution result
        sigOk = success; // Signature validation succeeds if execution mode is SUCCESS
        execOk = success; // Execution succeeds if execution mode is SUCCESS
    }

    function executeTargetOpsWithCompactStub(
        address recipient,
        address notarizedArbiter,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubDestination calldata elementStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        returns (bytes32 claimHash)
    {
        // Not used in PreClaimExecution tests
        return returnClaimHash;
    }

    function executePreClaimOpsWithPermit2Stub(
        address account,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateStub calldata mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        returns (bytes32 permit2Hash)
    {
        return returnClaimHash;
    }

    function execute(address account, Execution[] calldata ops) external {
        // Not used in PreClaimExecution tests
    }

    // IStandaloneIntentExecutor implementation
    function executeMultichainOps(MultiChainOps calldata signedOps) external {
        // Not used in PreClaimExecution tests
    }

    /// @notice Mock implementation of executeSinglechainOps for testing
    /// @dev Mock implementation without return value per interface specification
    function executeSinglechainOps(SingleChainOps calldata signedOps) external {
        // Not used in PreClaimExecution tests
    }

    function executeMultichainOpsWithGasRefund_ERC20(
        MultiChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        // Not used in PreClaimExecution tests
        return (signedOps.account, signedOps.nonce);
    }

    function executeMultichainOpsWithGasRefund_ETH(
        MultiChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        // Not used in PreClaimExecution tests
        return (signedOps.account, signedOps.nonce);
    }

    function executeSinglechainOpsWithGasRefund_ERC20(
        SingleChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        // Not used in PreClaimExecution tests
        return (signedOps.account, signedOps.nonce);
    }

    function executeSinglechainOpsWithGasRefund_ETH(
        SingleChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        // Not used in PreClaimExecution tests
        return (signedOps.account, signedOps.nonce);
    }

    function isPermit2IntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        // Mock implementation - always returns false for testing
        return false;
    }

    function isStandaloneIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        // Mock implementation - always returns false for testing
        return false;
    }

    function executeTargetOpsWithPermit2Stub(
        address account,
        IPermit2IntentExecutor.EIP712Permit2Stub calldata permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub calldata mandateStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        returns (bytes32 permit2Hash)
    {
        // Mock implementation - returns a simple hash for testing
        return keccak256(abi.encode(account, permit2Stub.nonce, permit2Stub.expires));
    }

    // ITrustedExecution implementation
    function executeWithoutSignature(address account, Execution[] calldata executions) external {
        // Not used in PreClaimExecution tests
    }

    function executeOpsWithoutSignature(address account, Types.Operation calldata ops) external { }

    // ERC7579 Module functions
    function isInitialized(address smartAccount) external view returns (bool) {
        return true; // Mock always returns true
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == 2; // MODULE_TYPE_EXECUTOR = 2
    }

    function onInstall(bytes calldata data) external {
        // Mock installation - no action needed
    }

    function onUninstall(bytes calldata data) external {
        // Mock uninstallation - no action needed
    }

    // Helper function to consume gas
    function _consumeGas(uint256 gasAmount) internal view {
        uint256 i = 0;
        uint256 target = gasAmount / 100; // Much smaller per iteration to avoid OOG
        while (i < target && gasleft() > 5000) {
            i++;
        }
    }

    // View functions for test verification
    function getLastExecutionCall() external view returns (ExecutionCall memory) {
        if (executionCallCount == 0) {
            revert("No execution calls recorded");
        }
        return executionCalls[executionCallCount - 1];
    }

    function getExecutionCall(uint256 index) external view returns (ExecutionCall memory) {
        if (index >= executionCallCount) {
            revert("Index out of bounds");
        }
        return executionCalls[index];
    }

    function isCompactIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        // Mock implementation - always returns false for testing
        return false;
    }
}
