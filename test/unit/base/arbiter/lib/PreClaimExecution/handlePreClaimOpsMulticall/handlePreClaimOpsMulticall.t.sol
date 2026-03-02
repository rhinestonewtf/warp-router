// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { PreClaimExecution_Unit_Test, MockCallTarget } from "test/unit/base/arbiter/lib/PreClaimExecution/PreClaimExecution.t.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

contract HandlePreClaimOpsMulticall_Unit_Test is PreClaimExecution_Unit_Test {
    function test_handlePreClaimOpsMulticall_Success() public {
        Types.Operation memory ops = _buildMulticallOps();

        bool success = arbiter.callHandlePreClaimOpsMulticall(ops, GAS_STIPEND);

        assertTrue(success);
        assertEq(callTarget.value(), 42);
    }

    function test_handlePreClaimOpsMulticall_Failure_EmitsPreClaimExecutionFailed() public {
        callTarget.setShouldRevert(true);
        Types.Operation memory ops = _buildMulticallOps();

        vm.expectEmit(false, false, false, false);
        emit PreClaimExecution.PreClaimExecutionFailed();

        bool success = arbiter.callHandlePreClaimOpsMulticall(ops, GAS_STIPEND);

        assertFalse(success);
    }

    function test_handlePreClaimOpsMulticall_RevertsWhen_InsufficientGas() public {
        Types.Operation memory ops = _buildMulticallOps();

        try arbiter.callHandlePreClaimOpsMulticall{ gas: 10_000 }(ops, GAS_STIPEND) {
            fail("Should have reverted with InsufficientGasForMinGas");
        } catch (bytes memory revertData) {
            bytes4 selector = bytes4(revertData);
            assertEq(selector, bytes4(keccak256("InsufficientGasForMinGas(uint256,uint256)")));
        }
    }

    function test_handlePreClaimOpsMulticall_ZeroGasStipend_SkipsGasCheck() public {
        Types.Operation memory ops = _buildMulticallOps();

        // Zero gas stipend skips the gas validation check
        // The call itself will get 0 gas and fail, but _requireValidGasLeft won't revert
        bool success = arbiter.callHandlePreClaimOpsMulticall(ops, 0);

        // Zero gas means the excessivelySafeCall gives 0 gas to the target, which will fail
        assertFalse(success);
    }

    function test_handlePreClaimOpsMulticall_TargetReverts_ReturnsFalse() public {
        callTarget.setShouldRevert(true);
        Types.Operation memory ops = _buildMulticallOps();

        bool success = arbiter.callHandlePreClaimOpsMulticall(ops, GAS_STIPEND);

        assertFalse(success);
        assertEq(callTarget.value(), 0);
    }
}
