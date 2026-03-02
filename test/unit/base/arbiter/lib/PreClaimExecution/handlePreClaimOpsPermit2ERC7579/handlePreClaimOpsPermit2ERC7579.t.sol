// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { PreClaimExecution_Unit_Test, MockPermit2IntentExecutor } from "test/unit/base/arbiter/lib/PreClaimExecution/PreClaimExecution.t.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract HandlePreClaimOpsPermit2ERC7579_Unit_Test is PreClaimExecution_Unit_Test {
    function test_handlePreClaimOpsPermit2ERC7579_Success() public {
        mockPermit2Executor.setShouldSucceed(true);
        Types.Operation memory ops = _buildERC7579Ops();

        bool success = arbiter.callHandlePreClaimOpsPermit2ERC7579(
            account, _createPermit2Stub(), _createMandateStub(), ops, hex"1234", GAS_STIPEND
        );

        assertTrue(success);
    }

    function test_handlePreClaimOpsPermit2ERC7579_Failure_EmitsPreClaimExecutionFailed() public {
        mockPermit2Executor.setShouldSucceed(false);
        Types.Operation memory ops = _buildERC7579Ops();

        vm.expectEmit(false, false, false, false);
        emit PreClaimExecution.PreClaimExecutionFailed();

        bool success = arbiter.callHandlePreClaimOpsPermit2ERC7579(
            account, _createPermit2Stub(), _createMandateStub(), ops, hex"1234", GAS_STIPEND
        );

        assertFalse(success);
    }

    function test_handlePreClaimOpsPermit2ERC7579_RevertsWhen_InsufficientGas() public {
        mockPermit2Executor.setShouldSucceed(true);
        Types.Operation memory ops = _buildERC7579Ops();

        try arbiter.callHandlePreClaimOpsPermit2ERC7579{ gas: 10_000 }(
            account, _createPermit2Stub(), _createMandateStub(), ops, hex"1234", GAS_STIPEND
        ) {
            fail("Should have reverted with InsufficientGasForMinGas");
        } catch (bytes memory revertData) {
            bytes4 selector = bytes4(revertData);
            assertEq(selector, bytes4(keccak256("InsufficientGasForMinGas(uint256,uint256)")));
        }
    }

    function test_handlePreClaimOpsPermit2ERC7579_ZeroGasStipend_SkipsGasCheck() public {
        mockPermit2Executor.setShouldSucceed(true);
        Types.Operation memory ops = _buildERC7579Ops();

        // With zero gas stipend, _requireValidGasLeft is skipped (no revert),
        // but excessivelySafeCall forwards 0 gas, so the subcall fails
        bool success = arbiter.callHandlePreClaimOpsPermit2ERC7579(
            account, _createPermit2Stub(), _createMandateStub(), ops, hex"1234", 0
        );

        // Zero gas stipend means the subcall gets 0 gas, causing failure
        assertFalse(success);
    }

    function test_handlePreClaimOpsPermit2ERC7579_ExecutorReverts_ReturnsFalse() public {
        mockPermit2Executor.setShouldSucceed(false);
        Types.Operation memory ops = _buildERC7579Ops();

        bool success = arbiter.callHandlePreClaimOpsPermit2ERC7579(
            account, _createPermit2Stub(), _createMandateStub(), ops, hex"1234", GAS_STIPEND
        );

        assertFalse(success);
    }
}
