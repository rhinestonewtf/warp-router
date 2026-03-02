// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { LibERC7579 } from "@rhinestone/compact-utils/src/common/LibERC7579.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { MockSmartAccount } from "./MockSmartAccount.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract MockExecutor is ERC7579ExecutorBase {
    using LibERC7579 for bool;

    function executeLibERC7579(address account, Execution[] calldata execs) external {
        bytes memory executionData = abi.encode(execs);

        // Call executeFromExecutor directly using constant mode
        (bool success, bytes memory returnData) = account.call(abi.encodeWithSelector(0xd691c964, LibERC7579.BATCH_MODE, executionData));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function executeLibERC7579Encoded(address account, bytes calldata encodedExec) external {
        LibERC7579.executeEncoded(account, encodedExec).bubbleRevert();
    }

    function executeERC7579Base(address account, Execution[] calldata execs) external returns (bytes[] memory) {
        return _execute(account, execs);
    }

    function isInitialized(address) external pure returns (bool) {
        return false;
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == 2; // MODULE_TYPE_EXECUTOR
    }

    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }
}

contract PreciseGasComparisonTest is Test {
    MockSmartAccount mockAccount;
    MockExecutor mockExecutor;
    MockTarget target1;
    MockTarget target2;

    function setUp() public {
        mockAccount = new MockSmartAccount();
        mockExecutor = new MockExecutor();
        target1 = new MockTarget();
        target2 = new MockTarget();

        // Fund the mock account
        vm.deal(address(mockAccount), 10 ether);
    }

    function test_preciseGasComparison() public {
        // Prepare identical execution data
        Execution[] memory execs = new Execution[](2);
        execs[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.setValue, (123)) });
        execs[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.setValue, (456)) });

        bytes memory encodedExecs = abi.encode(execs);

        // Take snapshot of initial state
        uint256 snapshot = vm.snapshot();

        // Test 1: LibERC7579.execute()
        uint256 gasBefore = gasleft();
        mockExecutor.executeLibERC7579(address(mockAccount), execs);
        uint256 libExecuteGas = gasBefore - gasleft();

        // Verify results and revert to snapshot
        assertEq(target1.value(), 123);
        assertEq(target2.value(), 456);
        vm.revertTo(snapshot);

        // Test 2: ERC7579ExecutorBase._execute()
        gasBefore = gasleft();
        mockExecutor.executeERC7579Base(address(mockAccount), execs);
        uint256 baseExecuteGas = gasBefore - gasleft();

        // Verify results and revert to snapshot
        assertEq(target1.value(), 123);
        assertEq(target2.value(), 456);
        vm.revertTo(snapshot);

        // Test 3: LibERC7579.executeEncoded()
        gasBefore = gasleft();
        mockExecutor.executeLibERC7579Encoded(address(mockAccount), encodedExecs);
        uint256 libEncodedGas = gasBefore - gasleft();

        // Verify results and revert to snapshot
        assertEq(target1.value(), 123);
        assertEq(target2.value(), 456);
        vm.revertTo(snapshot);

        // Test 4: Direct call baseline
        bytes32 mode = bytes32(uint256(0x01) << 248);
        gasBefore = gasleft();
        mockAccount.executeFromExecutor(mode, encodedExecs);
        uint256 directGas = gasBefore - gasleft();

        // Verify results
        assertEq(target1.value(), 123);
        assertEq(target2.value(), 456);

        // Log precise results
        emit log_named_uint("LibERC7579.execute gas", libExecuteGas);
        emit log_named_uint("ERC7579ExecutorBase._execute gas", baseExecuteGas);
        emit log_named_uint("LibERC7579.executeEncoded gas", libEncodedGas);
        emit log_named_uint("Direct executeFromExecutor gas", directGas);

        // Calculate overheads
        emit log_named_uint("LibERC7579.execute overhead", libExecuteGas - directGas);
        emit log_named_uint("ERC7579ExecutorBase overhead", baseExecuteGas - directGas);
        emit log_named_uint("LibERC7579.executeEncoded overhead", libEncodedGas - directGas);

        // Find the most efficient
        uint256 minGas = libExecuteGas;
        string memory winner = "LibERC7579.execute";

        if (baseExecuteGas < minGas) {
            minGas = baseExecuteGas;
            winner = "ERC7579ExecutorBase._execute";
        }
        if (libEncodedGas < minGas) {
            minGas = libEncodedGas;
            winner = "LibERC7579.executeEncoded";
        }

        emit log_string(string.concat("Most efficient: ", winner));
        emit log_named_uint("Best gas usage", minGas);

        // All functions should work correctly
        assertTrue(libExecuteGas > 0 && baseExecuteGas > 0 && libEncodedGas > 0 && directGas > 0, "All functions should consume gas");
    }

    function test_functionalParity() public {
        // Test that all three execution methods produce identical results
        Execution[] memory execs = new Execution[](3);
        execs[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.setValue, (111)) });
        execs[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.setValue, (222)) });
        execs[2] = Execution({
            target: address(target1),
            value: 0,
            callData: abi.encodeCall(MockTarget.setValue, (333)) // Overwrite first value
        });

        bytes memory encodedExecs = abi.encode(execs);

        // Test 1: LibERC7579.execute()
        uint256 snapshot1 = vm.snapshot();
        mockExecutor.executeLibERC7579(address(mockAccount), execs);
        uint256 result1_target1 = target1.value();
        uint256 result1_target2 = target2.value();
        vm.revertTo(snapshot1);

        // Test 2: ERC7579ExecutorBase._execute()
        uint256 snapshot2 = vm.snapshot();
        mockExecutor.executeERC7579Base(address(mockAccount), execs);
        uint256 result2_target1 = target1.value();
        uint256 result2_target2 = target2.value();
        vm.revertTo(snapshot2);

        // Test 3: LibERC7579.executeEncoded()
        uint256 snapshot3 = vm.snapshot();
        mockExecutor.executeLibERC7579Encoded(address(mockAccount), encodedExecs);
        uint256 result3_target1 = target1.value();
        uint256 result3_target2 = target2.value();
        vm.revertTo(snapshot3);

        // All should produce identical results
        assertEq(result1_target1, result2_target1, "Target1: LibERC7579.execute vs ERC7579ExecutorBase");
        assertEq(result1_target1, result3_target1, "Target1: LibERC7579.execute vs LibERC7579.executeEncoded");
        assertEq(result2_target1, result3_target1, "Target1: ERC7579ExecutorBase vs LibERC7579.executeEncoded");

        assertEq(result1_target2, result2_target2, "Target2: LibERC7579.execute vs ERC7579ExecutorBase");
        assertEq(result1_target2, result3_target2, "Target2: LibERC7579.execute vs LibERC7579.executeEncoded");
        assertEq(result2_target2, result3_target2, "Target2: ERC7579ExecutorBase vs LibERC7579.executeEncoded");

        // Verify final values are correct (target1 should be 333, target2 should be 222)
        assertEq(result1_target1, 333, "Target1 should have final value 333");
        assertEq(result1_target2, 222, "Target2 should have value 222");
    }

    function test_emptyArrayHandling() public {
        Execution[] memory emptyExecs = new Execution[](0);
        bytes memory encodedEmptyExecs = abi.encode(emptyExecs);

        // All functions should handle empty arrays without reverting
        mockExecutor.executeLibERC7579(address(mockAccount), emptyExecs);
        mockExecutor.executeERC7579Base(address(mockAccount), emptyExecs);
        mockExecutor.executeLibERC7579Encoded(address(mockAccount), encodedEmptyExecs);

        // No state should change
        assertEq(target1.value(), 0, "Target1 should remain 0");
        assertEq(target2.value(), 0, "Target2 should remain 0");
    }

    function test_revertPropagation() public {
        // Create a mock target that will revert
        MockRevertTarget revertTarget = new MockRevertTarget();

        Execution[] memory revertExecs = new Execution[](1);
        revertExecs[0] = Execution({ target: address(revertTarget), value: 0, callData: abi.encodeCall(MockRevertTarget.alwaysRevert, ()) });

        bytes memory encodedRevertExecs = abi.encode(revertExecs);

        // All functions should propagate reverts (MockSmartAccount converts to "Execution failed")
        vm.expectRevert("Execution failed");
        mockExecutor.executeLibERC7579(address(mockAccount), revertExecs);

        vm.expectRevert("Execution failed");
        mockExecutor.executeERC7579Base(address(mockAccount), revertExecs);

        vm.expectRevert("Execution failed");
        mockExecutor.executeLibERC7579Encoded(address(mockAccount), encodedRevertExecs);
    }
}

contract MockRevertTarget {
    function alwaysRevert() external pure {
        revert("Always reverts");
    }
}
