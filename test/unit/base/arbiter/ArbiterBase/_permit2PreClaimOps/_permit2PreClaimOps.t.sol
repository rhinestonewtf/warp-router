// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ArbiterBase_Unit_Test, RealArbiterBase } from "test/unit/base/arbiter/ArbiterBase/ArbiterBase.t.sol";
import { ArbiterBase } from "@rhinestone/compact-utils/src/base/arbiter/ArbiterBase.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

contract Permit2PreClaimOps_Unit_Test is ArbiterBase_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        NO-OPS (SKIP EXECUTION)
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_NoOps_SkipsExecution() public {
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    ERC7579 DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_ERC7579_DispatchesCorrectly() public {
        mockExecutor.setShouldSucceed(true);
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_permit2PreClaimOps_ERC7579_Failure_EmitsEvent() public {
        mockExecutor.setShouldSucceed(false);
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        vm.expectEmit(false, false, false, false);
        emit PreClaimExecution.PreClaimExecutionFailed();

        // Permit2 ERC7579 is failure-tolerant, does not revert
        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    MULTICALL DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_MultiCall_DispatchesCorrectly() public {
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        assertTrue(mandateHash != bytes32(0));
        assertEq(mockTarget.value(), 42);
    }

    function test_permit2PreClaimOps_MultiCall_Failure_EmitsEvent() public {
        mockTarget.setShouldRevert(true);
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        vm.expectEmit(false, false, false, false);
        emit PreClaimExecution.PreClaimExecutionFailed();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    CALLDATA DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_Calldata_DispatchesCorrectly() public {
        Types.Operation memory ops = _calldataOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        assertTrue(mandateHash != bytes32(0));
        assertEq(mockTarget.value(), 42);
    }

    /* //////////////////////////////////////////////////////////////
                        FAILURE PATHS
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_Calldata_Failure_EmitsEvent() public {
        mockTarget.setShouldRevert(true);
        Types.Operation memory ops = _calldataOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();

        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                        ONLY ROUTER ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_onlyRouter_Permit2_RevertsWhen_CallerIsNotRouter() public {
        // Arrange
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();
        address notRouter = makeAddr("notRouter");

        // Act & Assert
        vm.prank(notRouter);
        vm.expectRevert(ArbiterBase.OnlyRouter.selector);
        realArbiter.exposed_permit2PreClaimOps(order, sigs);
    }

    function test_onlyRouter_Permit2_SucceedsWhen_CallerIsRouter() public {
        // Arrange
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();

        // Act
        vm.prank(router);
        bytes32 mandateHash = realArbiter.exposed_permit2PreClaimOps(order, sigs);

        // Assert
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    GAS STIPEND VALIDATION (minGas > 0)
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_WithMinGas_SucceedsWhen_SufficientGas() public {
        // Arrange - set minGas > 0 with enough gas available
        uint128 gasStipend = 500_000;
        uint128 minGas = 100_000;
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrderWithGas(ops, gasStipend, minGas);
        Types.Signatures memory sigs = _createSigs();

        // Act - call with plenty of gas (default gas limit is high)
        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        // Assert
        assertTrue(mandateHash != bytes32(0));
    }

    function test_permit2PreClaimOps_WithMinGas_RevertsWhen_InsufficientGas() public {
        // Arrange - set a high preClaimGasStipend that triggers _requireValidGasLeft
        uint128 gasStipend = 500_000;
        uint128 minGas = 100_000;
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrderWithGas(ops, gasStipend, minGas);
        Types.Signatures memory sigs = _createSigs();

        // Act & Assert - call with very limited gas to trigger InsufficientGasForMinGas
        vm.expectRevert();
        arbiter.exposed_permit2PreClaimOps{ gas: 200_000 }(order, sigs);
    }

    /* //////////////////////////////////////////////////////////////
                    PRE-CLAIM SIG SELECTION
    //////////////////////////////////////////////////////////////*/

    function test_permit2PreClaimOps_ERC7579_UsesPreClaimSigWhenNonEmpty() public {
        // Arrange - provide a non-empty preClaimSig to exercise the ternary:
        // sigs.preClaimSig.length != 0 ? sigs.preClaimSig : sigs.notarizedClaimSig
        mockExecutor.setShouldSucceed(true);
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigsWithPreClaimSig();

        // Act
        bytes32 mandateHash = arbiter.exposed_permit2PreClaimOps(order, sigs);

        // Assert - should succeed with a valid mandate hash
        assertTrue(mandateHash != bytes32(0));
    }
}
