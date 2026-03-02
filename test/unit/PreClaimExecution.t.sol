// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { PreClaimExecution } from "../../src/base/arbiter/lib/PreClaimExecution.sol";
import { MockIntentExecutor } from "../utils/mocks/MockIntentExecutor.sol";
import { IIntentExecutor } from "../../src/interfaces/IIntentExecutor.sol";
import { ICompactIntentExecutor } from "../../src/executor/interfaces/ICompactIntent.sol";
import { Types } from "../../src/types/OrderTypes.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { SmartExecutionLib } from "../../src/common/SmartExecutionLib.sol";
import { IAddressBook } from "../../src/common/AddressBook/IAddressBook.sol";
import { AddressBookLib } from "../../src/common/AddressBook/lib/AddressBookLib.sol";
import { Constants } from "../../src/types/Constants.sol";
import { ExcessivelySafeCall } from "@excessivelySafeCall/ExcessivelySafeCall.sol";
import { Caller, MultiCaller, SingleCaller } from "../../src/router/utils/Caller.sol";

/**
 * @title PreClaimExecutionTest
 * @notice Comprehensive unit tests for PreClaimExecution contract
 * @dev Tests all pre-claim execution scenarios including success, failure, gas limits, and edge cases
 */
contract PreClaimExecutionTest is Test {
    using SmartExecutionLib for Types.Operation;
    using ExcessivelySafeCall for address;

    // Test harness contract
    TestPreClaimExecution public testContract;

    // Test subjects
    MockIntentExecutor public mockExecutor;
    MockAddressBook public mockAddressBook;
    MockTarget public mockTarget;
    address public testAccount;
    address public testTarget;

    // Events
    event PreClaimExecutionCalled(address indexed account, uint256 gasProvided, uint256 gasConsumed, bool success);

    function setUp() public {
        // Deploy mock executor
        mockExecutor = new MockIntentExecutor();

        // Deploy mock address book
        mockAddressBook = new MockAddressBook();
        mockAddressBook.setExecutor(address(mockExecutor));

        // Deploy test contract
        testContract = new TestPreClaimExecution(address(mockAddressBook));

        // Deploy mock target
        mockTarget = new MockTarget();

        // Setup test accounts
        testAccount = makeAddr("testAccount");
        testTarget = address(mockTarget);
    }

    // Test successful pre-claim execution with ERC7579
    function test_handlePreClaimOpsCompactERC7579_Success() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        // Setup test data
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        // Call through test contract
        (bool success, bool validSig) = testContract.testHandlePreClaimOpsERC7579(
            testAccount,
            executions,
            hex"1234567890abcdef", // preClaimSig
            hex"fedcba0987654321", // notarizedClaimSig
            1_000_000 // gas stipend
        );

        assertTrue(success, "Execution should succeed");
        assertTrue(validSig, "Signature should be valid");
        assertEq(mockExecutor.executionCallCount(), 1, "Should have called executor once");
    }

    // Test pre-claim execution with revert (should not propagate)
    function test_handlePreClaimOpsCompactERC7579_RevertDoesNotPropagate() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.REVERT);

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", 1_000_000);

        assertFalse(success, "Execution should return false on revert");
    }

    // Test pre-claim execution with out of gas
    function test_handlePreClaimOpsCompactERC7579_OutOfGas() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.OUT_OF_GAS);
        mockExecutor.setShouldConsumeAllGas(true);

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) = testContract.testHandlePreClaimOpsERC7579(
            testAccount,
            executions,
            hex"1234567890abcdef",
            hex"fedcba0987654321",
            100_000 // Limited gas
        );

        assertFalse(success, "Execution should fail due to out of gas");
    }

    // Test signature selection logic (uses preClaimSig when available)
    function test_SignatureSelection_UsesPreClaimSig() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        bytes memory preClaimSig = hex"1234567890abcdef1234567890abcdef";
        bytes memory notarizedSig = hex"fedcba0987654321";

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) = testContract.testHandlePreClaimOpsERC7579(testAccount, executions, preClaimSig, notarizedSig, 1_000_000);

        assertTrue(success, "Execution should succeed");

        // Verify the correct signature was used
        MockIntentExecutor.ExecutionCall memory lastCall = mockExecutor.getLastExecutionCall();
        assertEq(lastCall.signature, preClaimSig, "Should use preClaimSig when available");
    }

    // Test signature selection logic (fallback to notarizedClaimSig)
    function test_SignatureSelection_FallbackToNotarizedSig() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        bytes memory notarizedSig = hex"fedcba0987654321fedcba0987654321";

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(
                testAccount,
                executions,
                "", // empty preClaimSig
                notarizedSig,
                1_000_000
            );

        assertTrue(success, "Execution should succeed");

        // Verify the fallback signature was used
        MockIntentExecutor.ExecutionCall memory lastCall = mockExecutor.getLastExecutionCall();
        assertEq(lastCall.signature, notarizedSig, "Should fallback to notarizedClaimSig");
    }

    // Test gas stipend enforcement
    function test_GasStipendEnforcement() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);
        mockExecutor.setGasToConsume(500_000);

        uint256 gasStipend = 200_000;
        uint256 gasBefore = gasleft();

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", gasStipend);

        uint256 gasUsed = gasBefore - gasleft();

        // Gas used should be limited by stipend
        assertLt(gasUsed, gasStipend + 100_000, "Should not exceed gas stipend significantly");
    }

    // Test with zero gas stipend
    function test_ZeroGasStipend() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) = testContract.testHandlePreClaimOpsERC7579(
            testAccount,
            executions,
            hex"1234567890abcdef",
            hex"fedcba0987654321",
            0 // Zero gas stipend
        );

        assertFalse(success, "Execution should fail with zero gas stipend");
    }

    // Test with empty operations
    function test_EmptyOperations() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        Execution[] memory executions = new Execution[](0);

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", 1_000_000);

        assertTrue(success, "Should handle empty operations gracefully");
    }

    // Test multiple sequential executions
    function test_MultipleSequentialExecutions() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        // First execution
        (bool success1,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", 1_000_000);

        // Second execution
        (bool success2,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"abcdef1234567890", hex"fedcba0987654321", 1_000_000);

        assertTrue(success1 && success2, "Both executions should succeed");
        assertEq(mockExecutor.executionCallCount(), 2, "Should have called executor twice");
    }

    // Fuzz test for gas stipend values
    function testFuzz_GasStipend(uint256 gasStipend) public {
        // Bound gas stipend to reasonable values (avoid edge cases with call overhead)
        gasStipend = bound(gasStipend, 500_000, 5_000_000);

        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);
        // Don't consume extra gas in the mock
        mockExecutor.setGasToConsume(0);

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", gasStipend);

        assertTrue(success, "Execution should handle various gas stipends");
    }

    // Test multicall functionality
    function test_HandlePreClaimOpsMulticall_Success() public {
        // Reset call count
        mockTarget.resetCallCount();

        // Create proper multicall data format
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });
        executions[1] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("anotherFunction()") });

        // Encode using SmartExecutionLib format: Type.MultiCall (4) + SigMode (0) + encoded executions
        bytes memory multicallData = abi.encodePacked(
            SmartExecutionLib.Type.MultiCall, // Type byte (4)
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            abi.encode(executions) // Encoded execution array
        );

        Types.Operation memory multicallOps = Types.Operation({ data: multicallData });

        bool success = testContract.testHandlePreClaimOpsMulticall(multicallOps, 1_000_000);

        assertTrue(success, "Multicall should succeed");
        assertEq(mockTarget.callCount(), 2, "Both functions should have been called");
    }

    // Test multicall with failing call (should not propagate failure)
    function test_HandlePreClaimOpsMulticall_WithFailingCall() public {
        // Make the target revert
        mockTarget.setShouldRevert(true);
        mockTarget.resetCallCount();

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        bytes memory multicallData = abi.encodePacked(
            SmartExecutionLib.Type.MultiCall, // Type byte (4)
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            abi.encode(executions) // Encoded execution array
        );

        Types.Operation memory multicallOps = Types.Operation({ data: multicallData });

        bool success = testContract.testHandlePreClaimOpsMulticall(multicallOps, 1_000_000);

        // Should fail because MultiCaller requires all calls to succeed
        assertFalse(success, "Multicall should fail when target reverts");

        // Reset for other tests
        mockTarget.setShouldRevert(false);
    }

    // Test multicall with empty operations
    function test_HandlePreClaimOpsMulticall_EmptyOps() public {
        Execution[] memory executions = new Execution[](0);

        bytes memory multicallData = abi.encodePacked(
            SmartExecutionLib.Type.MultiCall, // Type byte (4)
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            abi.encode(executions) // Encoded execution array
        );

        Types.Operation memory multicallOps = Types.Operation({ data: multicallData });

        bool success = testContract.testHandlePreClaimOpsMulticall(multicallOps, 1_000_000);

        assertTrue(success, "Empty multicall should succeed");
    }

    // Test single call functionality
    function test_HandlePreClaimOpsCallData_Success() public {
        mockTarget.resetCallCount();
        bytes memory callData = abi.encodeWithSignature("testFunction()");

        bool success = testContract.testHandlePreClaimOpsCallData(testTarget, callData, 1_000_000);

        assertTrue(success, "CallData execution should succeed");
        assertEq(mockTarget.callCount(), 1, "Function should have been called once");
    }

    // Test single call functionality with failing call
    function test_HandlePreClaimOpsCallData_WithFailingCall() public {
        mockTarget.setShouldRevert(true);
        mockTarget.resetCallCount();
        bytes memory callData = abi.encodeWithSignature("testFunction()");

        bool success = testContract.testHandlePreClaimOpsCallData(testTarget, callData, 1_000_000);

        assertFalse(success, "CallData execution should fail when target reverts");

        // Reset for other tests
        mockTarget.setShouldRevert(false);
    }

    // Test that return data is not propagated
    function test_ReturnDataNotPropagated() public {
        mockExecutor.setExecutionMode(MockIntentExecutor.ExecutionMode.SUCCESS);
        mockExecutor.setReturnData(hex"756e6578706563746564");
        mockExecutor.setReturnClaimHash(keccak256("test_claim_hash"));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: testTarget, value: 0, callData: abi.encodeWithSignature("testFunction()") });

        (bool success,) =
            testContract.testHandlePreClaimOpsERC7579(testAccount, executions, hex"1234567890abcdef", hex"fedcba0987654321", 1_000_000);

        assertTrue(success, "Execution should succeed");
        // The boolean return values are all we get, no claim hash returned
    }
}

// Test harness contract that exposes internal functions
contract TestPreClaimExecution is PreClaimExecution {
    constructor(address addressBook) PreClaimExecution(addressBook) { }

    // Expose multicall function for testing
    function testHandlePreClaimOpsMulticall(Types.Operation memory ops, uint256 gasStipend) external returns (bool) {
        // Use external call to convert to calldata
        return this.externalHandlePreClaimOpsMulticall(abi.encode(ops), gasStipend);
    }

    function externalHandlePreClaimOpsMulticall(bytes calldata opsData, uint256 gasStipend) external returns (bool) {
        Types.Operation memory ops = abi.decode(opsData, (Types.Operation));
        // Call through another external to get calldata
        return this.callInternalMulticall(ops, gasStipend);
    }

    function callInternalMulticall(Types.Operation calldata ops, uint256 gasStipend) external returns (bool) {
        return _handlePreClaimOpsMulticall(ops, gasStipend);
    }

    // Expose calldata function for testing
    function testHandlePreClaimOpsCallData(address target, bytes memory callData, uint256 gasStipend) external returns (bool) {
        return this.externalHandlePreClaimOpsCallData(target, callData, gasStipend);
    }

    function externalHandlePreClaimOpsCallData(address target, bytes calldata callData, uint256 gasStipend) external returns (bool) {
        return _handlePreClaimOpsCallData(target, callData, gasStipend);
    }

    // Test wrapper for _handlePreClaimOpsCompactERC7579
    function testHandlePreClaimOpsERC7579(
        address account,
        Execution[] memory executions,
        bytes memory preClaimSig,
        bytes memory notarizedClaimSig,
        uint256 preClaimGasStipend
    )
        external
        returns (bool success, bool validSig)
    {
        // Create test data structures
        Types.Operation memory preClaimOps = Types.Operation({ data: abi.encode(executions) });
        Types.Operation memory emptyTargetOps = Types.Operation({ data: "" });

        Types.Signatures memory signatures = Types.Signatures({ preClaimSig: preClaimSig, notarizedClaimSig: notarizedClaimSig });

        uint256[2][] memory emptyTokens = new uint256[2][](0);
        Types.Order memory order = Types.Order({
            sponsor: address(0),
            recipient: address(0),
            nonce: 1,
            expires: block.timestamp + 1000,
            fillDeadline: block.timestamp + 1000,
            notarizedChainId: 1,
            targetChainId: 1,
            tokenIn: emptyTokens,
            tokenOut: emptyTokens,
            packedGasValues: 0,
            preClaimOps: preClaimOps,
            targetOps: emptyTargetOps,
            qualifier: ""
        });

        bytes32[] memory otherElements = new bytes32[](0);
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = ICompactIntentExecutor.EIP712ElementStubOrigin({
            otherElements: otherElements,
            minGas: 0,
            elementOffset: 0,
            destOpsHash: keccak256("destOps"),
            tokenInHash: keccak256("tokenIn"),
            targetAttributesHash: keccak256("targetAttributes"),
            qHash: keccak256("qualifier")
        });

        uint256 notarizedChainId = 1;

        // Call through external function to convert to calldata
        return this.externalHandlePreClaimOpsERC7579(
            account, abi.encode(order), abi.encode(signatures), abi.encode(elementStub), notarizedChainId, preClaimGasStipend
        );
    }

    // External function that accepts encoded parameters and decodes them to calldata
    function externalHandlePreClaimOpsERC7579(
        address account,
        bytes calldata orderData,
        bytes calldata signaturesData,
        bytes calldata elementStubData,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend
    )
        external
        returns (bool success, bool validSig)
    {
        Types.Order memory order = abi.decode(orderData, (Types.Order));
        Types.Signatures memory signatures = abi.decode(signaturesData, (Types.Signatures));
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub =
            abi.decode(elementStubData, (ICompactIntentExecutor.EIP712ElementStubOrigin));

        // Now call the internal function with calldata parameters
        // We need to use an external call pattern to get proper calldata types
        bytes memory callData = abi.encodeCall(
            this.callInternalHandlePreClaimOpsERC7579, (account, order, signatures, elementStub, notarizedChainId, preClaimGasStipend)
        );

        (bool callSuccess, bytes memory returnData) = address(this).call(callData);
        require(callSuccess, "External call failed");
        return abi.decode(returnData, (bool, bool));
    }

    // Function that can be called externally to invoke the internal function
    function callInternalHandlePreClaimOpsERC7579(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signatures,
        ICompactIntentExecutor.EIP712ElementStubOrigin calldata elementStub,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend
    )
        external
        returns (bool success, bool sigOk, bool execOk)
    {
        ICompactIntentExecutor.EIP712CompactStub memory compactStub =
            ICompactIntentExecutor.EIP712CompactStub(order.nonce, order.expires, notarizedChainId);
        return _handlePreClaimOpsCompactERC7579(account, order, signatures, elementStub, compactStub, preClaimGasStipend);
    }
}

// Mock AddressBook for testing
contract MockAddressBook is IAddressBook {
    address public executor;

    function setExecutor(address _executor) external {
        executor = _executor;
    }

    function getAddress(AddressBookLib.ID id) external view returns (address) {
        if (AddressBookLib.ID.unwrap(id) == AddressBookLib.ID.unwrap(Constants.INTENT_EXECUTOR_ID)) {
            return executor;
        }
        return address(0);
    }

    function setAddress(AddressBookLib.ID, address) external {
        // Not implemented
    }

    function setAddresses(SetAddress[] calldata) external {
        // Not implemented
    }

    function getUint(AddressBookLib.ID) external view returns (uint256) {
        return 0;
    }

    function setUint(AddressBookLib.ID, uint256) external {
        // Not implemented
    }

    function setUints(SetUint[] calldata) external {
        // Not implemented
    }

    function getBytes32(AddressBookLib.ID) external view returns (bytes32) {
        return bytes32(0);
    }

    function setBytes32(AddressBookLib.ID, bytes32) external {
        // Not implemented
    }

    function setBytes32s(SetBytes32[] calldata) external {
        // Not implemented
    }

    function getBytes(AddressBookLib.ID) external view returns (bytes memory) {
        return "";
    }

    function setBytes(AddressBookLib.ID, bytes calldata) external {
        // Not implemented
    }

    function setBytess(SetBytess[] calldata) external {
        // Not implemented
    }

    function unsafeGetAddress(AddressBookLib.ID) external view returns (address) {
        return address(0);
    }
}

// Mock target contract for testing calls
contract MockTarget {
    bool public shouldRevert = false;
    uint256 public callCount = 0;

    function testFunction() external {
        if (shouldRevert) revert("MockTarget: testFunction reverted");
        callCount++;
    }

    function anotherFunction() external {
        if (shouldRevert) revert("MockTarget: anotherFunction reverted");
        callCount++;
    }

    function complexFunction(uint256) external {
        if (shouldRevert) revert("MockTarget: complexFunction reverted");
        callCount++;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function resetCallCount() external {
        callCount = 0;
    }
}
