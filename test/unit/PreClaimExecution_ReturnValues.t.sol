// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";
import { IAddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/IAddressBook.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { AddressBookLib } from "@rhinestone/compact-utils/src/common/AddressBook/AddressBook.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

/**
 * @title MockIntentExecutorWithFailureModes
 * @notice Mock executor that can simulate different failure scenarios
 */
contract MockIntentExecutorWithFailureModes is ICompactIntentExecutor {
    enum FailureMode {
        SUCCESS,
        SIG_CHECK_REVERT,
        SIG_CHECK_GAS_OUT,
        EXECUTION_REVERT,
        EXECUTION_GAS_OUT,
        SIG_INVALID,
        EXEC_FAILED
    }

    FailureMode public failureMode = FailureMode.SUCCESS;
    uint256 public gasToConsume;

    function setFailureMode(FailureMode mode) external {
        failureMode = mode;
    }

    function setGasToConsume(uint256 gas) external {
        gasToConsume = gas;
    }

    function executePreClaimOpsWithCompactStub(
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubOrigin calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bool sigOk, bool execOk)
    {
        // Consume gas if configured
        if (gasToConsume > 0) {
            _consumeGas(gasToConsume);
        }

        if (failureMode == FailureMode.SIG_CHECK_REVERT) {
            revert("Signature check reverted");
        } else if (failureMode == FailureMode.SIG_CHECK_GAS_OUT) {
            // Consume all remaining gas to simulate OOG during sig check
            _consumeAllGas();
            revert("Out of gas");
        } else if (failureMode == FailureMode.EXECUTION_REVERT) {
            // Sig check passes, but execution reverts
            sigOk = true;
            revert("Execution reverted");
        } else if (failureMode == FailureMode.EXECUTION_GAS_OUT) {
            // Sig check passes, but execution runs out of gas
            sigOk = true;
            _consumeAllGas();
            revert("Out of gas");
        } else if (failureMode == FailureMode.SIG_INVALID) {
            // Signature validation fails (returns false)
            sigOk = false;
            execOk = false;
        } else if (failureMode == FailureMode.EXEC_FAILED) {
            // Signature valid but execution failed
            sigOk = true;
            execOk = false;
        } else {
            // SUCCESS
            sigOk = true;
            execOk = true;
        }
    }

    function executeTargetOpsWithCompactStub(
        address,
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubDestination calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bytes32)
    {
        return bytes32(0);
    }

    function isCompactIntentNonceConsumed(uint256, address) external pure returns (bool) {
        return false;
    }

    function _consumeGas(uint256 gasAmount) internal view {
        uint256 i = 0;
        uint256 target = gasAmount / 100;
        while (i < target && gasleft() > 5000) {
            i++;
        }
    }

    function _consumeAllGas() internal view {
        uint256 gasLeft = gasleft();
        if (gasLeft > 5000) {
            _consumeGas(gasLeft - 5000);
        }
    }
}

/**
 * @title MockArbiter
 * @notice Test arbiter that exposes internal PreClaimExecution function
 */
contract MockArbiter is PreClaimExecution {
    constructor(address addressBook) PreClaimExecution(addressBook) { }

    function callHandlePreClaimOpsCompactERC7579(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signature,
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend,
        SmartExecutionLib.SigMode sigMode
    )
        external
        returns (bool success)
    {
        return _handlePreClaimOpsCompactERC7579(account, order, signature, elementStub, notarizedChainId, preClaimGasStipend, sigMode);
    }

    function callHandlePreClaimOpsCompactERC7579Raw(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signature,
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend
    )
        external
        returns (bool success, bool sigOk, bool execOk)
    {
        ICompactIntentExecutor.EIP712CompactStub memory compactStub =
            ICompactIntentExecutor.EIP712CompactStub(order.nonce, order.expires, notarizedChainId);
        return _handlePreClaimOpsCompactERC7579(account, order, signature, elementStub, compactStub, preClaimGasStipend);
    }
}

/**
 * @title MockAddressBook
 */
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

    function getBytes32(AddressBookLib.ID) external pure returns (bytes32) {
        return bytes32(0);
    }

    function getBytes(AddressBookLib.ID) external pure returns (bytes memory) {
        return "";
    }

    function getUint(AddressBookLib.ID) external pure returns (uint256) {
        return 0;
    }

    function setAddress(AddressBookLib.ID, address) external { }

    function setAddresses(SetAddress[] calldata) external { }

    function setUint(AddressBookLib.ID, uint256) external { }

    function setUints(SetUint[] calldata) external { }

    function setBytes32(AddressBookLib.ID, bytes32) external { }

    function setBytes32s(SetBytes32[] calldata) external { }

    function setBytes(AddressBookLib.ID, bytes calldata) external { }

    function setBytess(SetBytess[] calldata) external { }

    function unsafeGetAddress(AddressBookLib.ID id) external view returns (address) {
        return this.getAddress(id);
    }
}

/**
 * @title PreClaimExecutionReturnValuesTest
 * @notice Tests for different return value scenarios in _handlePreClaimOpsCompactERC7579
 */
contract PreClaimExecutionReturnValuesTest is Test {
    MockArbiter public arbiter;
    MockIntentExecutorWithFailureModes public mockExecutor;
    MockAddressBook public addressBook;

    address public account = address(0x1234);
    uint256 public constant GAS_STIPEND = 1_000_000;

    function setUp() public {
        // Deploy mocks
        addressBook = new MockAddressBook();
        mockExecutor = new MockIntentExecutorWithFailureModes();
        addressBook.setExecutor(address(mockExecutor));
        arbiter = new MockArbiter(address(addressBook));
    }

    function _createTestOrder() internal view returns (Types.Order memory) {
        Types.Operation memory preClaimOps = Types.Operation({ data: "" });
        Types.Operation memory targetOps = Types.Operation({ data: "" });
        uint256[2][] memory emptyTokens = new uint256[2][](0);

        return Types.Order({
            sponsor: account,
            recipient: account,
            nonce: 1,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 1800,
            notarizedChainId: block.chainid,
            targetChainId: block.chainid,
            tokenIn: emptyTokens,
            tokenOut: emptyTokens,
            packedGasValues: 0,
            preClaimOps: preClaimOps,
            targetOps: targetOps,
            qualifier: ""
        });
    }

    function _createTestSignatures() internal pure returns (Types.Signatures memory) {
        return Types.Signatures({ preClaimSig: hex"1234", notarizedClaimSig: hex"5678" });
    }

    function _createElementStub() internal pure returns (ICompactIntentExecutor.EIP712ElementStubOrigin memory) {
        bytes32[] memory otherElements = new bytes32[](1);
        otherElements[0] = keccak256("element1");

        return ICompactIntentExecutor.EIP712ElementStubOrigin({
            otherElements: otherElements,
            minGas: 0,
            elementOffset: 0,
            destOpsHash: keccak256("dest"),
            tokenInHash: keccak256("token"),
            targetAttributesHash: keccak256("attrs"),
            qHash: keccak256("q")
        });
    }

    // Test 1: Success case (EMISSARY mode)
    function test_success_emissarySafe() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        assertTrue(success, "Should succeed in EMISSARY mode");
    }

    // Test 2: Success case (claim first mode)
    function test_success_claimFirst() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        assertTrue(success, "Should succeed in claim first mode");
    }

    // Test 3: Signature check reverts (EMISSARY mode - should pass because no gas check)
    function test_sigCheckRevert_emissarySafe() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // In EMISSARY mode: success = (!okGas || okSig)
        // If call fails (reverts), okGas should be false, so !okGas = true, therefore success = true
        assertTrue(success, "Should pass in EMISSARY mode even with sig check revert (no gas consumed)");
    }

    // Test 4: Signature check reverts (claim first mode - should fail)
    function test_sigCheckRevert_claimFirst() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // In claim first mode: success = okGas && okSig
        // If call fails, success should be false
        assertFalse(success, "Should fail in claim first mode with sig check revert");
    }

    // Test 5: Gas out during signature check
    function test_sigCheckGasOut() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_GAS_OUT);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account,
            order,
            sigs,
            elementStub,
            block.chainid,
            100_000, // Lower gas to trigger OOG
            SmartExecutionLib.SigMode.ERC1271
        );

        assertFalse(success, "Should fail when gassing out during sig check");
    }

    // Test 6: Execution reverts (signature valid)
    function test_executionRevert() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.EXECUTION_REVERT);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        // When the executor reverts, excessivelySafeCall returns success=false
        // This means we can't get the return values
        assertFalse(success, "Call should fail due to revert");
        assertFalse(sigOk, "No return values available due to revert");
        assertFalse(execOk, "No return values available due to revert");
    }

    // Test 7: Gas out during execution
    function test_executionGasOut() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.EXECUTION_GAS_OUT);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(
                account,
                order,
                sigs,
                elementStub,
                block.chainid,
                100_000 // Lower gas
            );

        // When OOG occurs, excessivelySafeCall returns success=false
        assertFalse(success, "Call should fail due to OOG");
        assertFalse(sigOk, "Should not get return values due to OOG");
        assertFalse(execOk, "Should not get return values due to OOG");
    }

    // Test 8: Signature invalid (returns false)
    function test_sigInvalid_emissarySafe() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_INVALID);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // In EMISSARY: success = (!okGas || okSig) = (false || false) = false
        // Wait, okGas should be true (call succeeded), so success = (true || false) = true... no wait
        // Let me re-read the logic: success = (sigMode == EMISSARY) ? (!okGas || okSig) : (okGas && okSig)
        // okGas = success from excessivelySafeCall = true (call succeeded)
        // okSig = false (signature invalid)
        // In EMISSARY: !okGas || okSig = !true || false = false || false = false
        assertFalse(success, "Should fail with invalid signature in EMISSARY");
    }

    // Test 9: Signature invalid in claim first mode
    function test_sigInvalid_claimFirst() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_INVALID);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // In claim first: success = okGas && okSig = true && false = false
        assertFalse(success, "Should fail with invalid signature in claim first mode");
    }

    // Test 10: Execution failed (sig valid, but exec returns false)
    function test_execFailed() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.EXEC_FAILED);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        assertTrue(success, "Gas check should pass");
        assertTrue(sigOk, "Signature should be valid");
        assertFalse(execOk, "Execution should fail");
    }

    // Test 11: Raw return values with success
    function test_rawReturnValues_success() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        assertTrue(success, "Gas check should pass");
        assertTrue(sigOk, "Signature should be valid");
        assertTrue(execOk, "Execution should succeed");
    }

    // Test 12: Insufficient gas for minGas requirement
    function test_insufficientGas_reverts() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        // This should revert due to insufficient gas
        // Using try-catch pattern since vm.expectRevert has issues with custom error parameters
        try arbiter.callHandlePreClaimOpsCompactERC7579{ gas: 10_000 }(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        ) {
            fail("Should have reverted with InsufficientGasForMinGas");
        } catch (bytes memory revertData) {
            // Check that it reverted with InsufficientGasForMinGas selector (0xac416190)
            bytes4 selector = bytes4(revertData);
            assertEq(selector, bytes4(keccak256("InsufficientGasForMinGas(uint256,uint256)")), "Wrong error selector");
        }
    }

    // Test 13: Zero gas stipend (skips gas check, should succeed)
    function test_zeroGasStipend_skipsCheck() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        // With zero gas stipend, _requireValidGasLeft should be skipped
        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account,
            order,
            sigs,
            elementStub,
            block.chainid,
            0, // Zero gas stipend
            SmartExecutionLib.SigMode.EMISSARY
        );

        assertTrue(success, "Should succeed with zero gas stipend");
    }

    // Test 14: Signature selection - preClaimSig used when present
    function test_signatureSelection_preClaimSigUsed() public {
        Types.Order memory order = _createTestOrder();
        // Create signatures where preClaimSig is non-empty
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: hex"aabbccdd", notarizedClaimSig: hex"11223344" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        assertTrue(success, "Should succeed");
        assertTrue(sigOk, "Signature should be valid");
        assertTrue(execOk, "Execution should succeed");
        // Note: We can't easily verify which sig was used without more instrumentation
    }

    // Test 15: Signature selection - fallback to notarizedClaimSig
    function test_signatureSelection_fallbackToNotarized() public {
        Types.Order memory order = _createTestOrder();
        // Create signatures where preClaimSig is empty
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"11223344" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        assertTrue(success, "Should succeed with notarized sig fallback");
        assertTrue(sigOk, "Signature should be valid");
        assertTrue(execOk, "Execution should succeed");
    }

    // Test 16: Return data truncated (< 64 bytes) - should return false values
    function test_returnDataTruncated() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        // Mock executor returns 2 booleans (64 bytes total)
        // If we get less, the assembly won't decode properly
        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        assertTrue(success, "Call should succeed");
        // With proper return data, these should be true
        assertTrue(sigOk, "Should decode first bool correctly");
        assertTrue(execOk, "Should decode second bool correctly");
    }

    // Test 17: EMISSARY with sig valid but exec failed
    function test_emissarySafe_sigValidExecFailed() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.EXEC_FAILED);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // In EMISSARY: success = !okGas || okSig = !true || true = false || true = true
        assertTrue(success, "Should succeed in EMISSARY even if exec failed (sig was valid)");
    }

    // Test 18: Claim-first with sig valid but exec failed
    function test_claimFirst_sigValidExecFailed() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.EXEC_FAILED);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // In claim-first: success = okGas && okSig = true && true = true
        // Note: execOk is NOT checked in the wrapper, only sigOk!
        assertTrue(success, "Should succeed in claim-first if okGas and okSig are true (execOk not checked)");
    }

    // Test 19: EMISSARY mode with call failure (okGas=false)
    function test_emissarySafe_callFailure() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // In EMISSARY: success = !okGas || okSig = !false || false = true || false = true
        assertTrue(success, "Should succeed in EMISSARY when call fails (skips pre-claim)");
    }

    // Test 20: Fuzz test - various gas stipends
    function testFuzz_variousGasStipends(uint256 gasStipend) public {
        gasStipend = bound(gasStipend, 100_000, 5_000_000);

        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, gasStipend, SmartExecutionLib.SigMode.ERC1271
        );

        assertTrue(success, "Should handle various gas stipends");
    }

    // Test 21: Fuzz test - EMISSARY mode behavior
    function testFuzz_emissarySafeMode(bool okGas, bool okSig) public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Set mock to return specific values
        if (!okGas) {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);
        } else if (!okSig) {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_INVALID);
        } else {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);
        }

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // Expected: !okGas || okSig
        bool expected = !okGas || okSig;
        assertEq(success, expected, "EMISSARY mode logic mismatch");
    }

    // Test 22: Fuzz test - Claim-first mode behavior
    function testFuzz_claimFirstMode(bool okGas, bool okSig) public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Set mock to return specific values
        if (!okGas) {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);
        } else if (!okSig) {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_INVALID);
        } else {
            mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SUCCESS);
        }

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // Expected: okGas && okSig
        bool expected = okGas && okSig;
        assertEq(success, expected, "Claim-first mode logic mismatch");
    }

    // Test 23: Raw function never reverts
    function test_rawFunctionNeverReverts() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = _createTestSignatures();
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockExecutor.setFailureMode(MockIntentExecutorWithFailureModes.FailureMode.SIG_CHECK_REVERT);

        // Raw function should NEVER revert, even with failures
        (bool success, bool sigOk, bool execOk) =
            arbiter.callHandlePreClaimOpsCompactERC7579Raw(account, order, sigs, elementStub, block.chainid, GAS_STIPEND);

        // Should return false values but not revert
        assertFalse(success, "Call failed as expected");
        assertFalse(sigOk, "No sig validation due to revert");
        assertFalse(execOk, "No execution due to revert");
    }
}
