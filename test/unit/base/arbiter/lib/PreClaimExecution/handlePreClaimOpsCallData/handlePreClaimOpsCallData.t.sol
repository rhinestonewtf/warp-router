// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { PreClaimExecution_Unit_Test, MockCallTarget } from "test/unit/base/arbiter/lib/PreClaimExecution/PreClaimExecution.t.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";

contract HandlePreClaimOpsCallData_Unit_Test is PreClaimExecution_Unit_Test {
    function test_handlePreClaimOpsCallData_Success() public {
        bytes memory callData = abi.encodeCall(MockCallTarget.doSomething, (42));

        bool success = arbiter.callHandlePreClaimOpsCallData(address(callTarget), callData, GAS_STIPEND);

        assertTrue(success);
        assertEq(callTarget.value(), 42);
    }

    function test_handlePreClaimOpsCallData_Failure_EmitsPreClaimExecutionFailed() public {
        callTarget.setShouldRevert(true);
        bytes memory callData = abi.encodeCall(MockCallTarget.doSomething, (42));

        vm.expectEmit(false, false, false, false);
        emit PreClaimExecution.PreClaimExecutionFailed();

        bool success = arbiter.callHandlePreClaimOpsCallData(address(callTarget), callData, GAS_STIPEND);

        assertFalse(success);
    }

    function test_handlePreClaimOpsCallData_RevertsWhen_InsufficientGas() public {
        bytes memory callData = abi.encodeCall(MockCallTarget.doSomething, (42));

        try arbiter.callHandlePreClaimOpsCallData{ gas: 10_000 }(address(callTarget), callData, GAS_STIPEND) {
            fail("Should have reverted with InsufficientGasForMinGas");
        } catch (bytes memory revertData) {
            bytes4 selector = bytes4(revertData);
            assertEq(selector, bytes4(keccak256("InsufficientGasForMinGas(uint256,uint256)")));
        }
    }

    function test_handlePreClaimOpsCallData_ZeroGasStipend_SkipsGasCheck() public {
        bytes memory callData = abi.encodeCall(MockCallTarget.doSomething, (42));

        // Zero gas stipend skips the gas validation check
        bool success = arbiter.callHandlePreClaimOpsCallData(address(callTarget), callData, 0);

        // Zero gas means the excessivelySafeCall gives 0 gas to the target, which will fail
        assertFalse(success);
    }

    function test_handlePreClaimOpsCallData_TargetReverts_ReturnsFalse() public {
        callTarget.setShouldRevert(true);
        bytes memory callData = abi.encodeCall(MockCallTarget.doSomething, (42));

        bool success = arbiter.callHandlePreClaimOpsCallData(address(callTarget), callData, GAS_STIPEND);

        assertFalse(success);
        assertEq(callTarget.value(), 0);
    }
}
