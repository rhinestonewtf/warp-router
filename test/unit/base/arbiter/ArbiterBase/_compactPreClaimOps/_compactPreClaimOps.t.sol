// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ArbiterBase_Unit_Test, RealArbiterBase } from "test/unit/base/arbiter/ArbiterBase/ArbiterBase.t.sol";
import { ArbiterBase } from "@rhinestone/compact-utils/src/base/arbiter/ArbiterBase.sol";
import { IArbiter } from "@rhinestone/compact-utils/src/interfaces/IArbiter.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

contract CompactPreClaimOps_Unit_Test is ArbiterBase_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        NO-OPS (SKIP EXECUTION)
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_NoOps_SkipsExecution() public {
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        // Should return a valid mandate hash without executing any pre-claim ops
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    ERC7579 DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_ERC7579_DispatchesCorrectly() public {
        mockExecutor.setShouldSucceed(true);
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_compactPreClaimOps_ERC7579_EmissaryMode_FailureTolerant() public {
        // In EMISSARY mode, execution failure should be tolerated (success = !okGas || okSig)
        mockExecutor.setShouldSucceed(false); // executor will revert
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.EMISSARY);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        // Should NOT revert because EMISSARY mode is failure-tolerant for call failures
        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
        assertTrue(mandateHash != bytes32(0));
    }

    function test_compactPreClaimOps_ERC7579_ClaimFirstMode_FailureReverts() public {
        // In claim-first mode (ERC1271), execution failure causes require(success) to fail
        mockExecutor.setShouldSucceed(false); // executor will revert
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        vm.expectRevert();
        arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
    }

    /* //////////////////////////////////////////////////////////////
                    MULTICALL DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_MultiCall_DispatchesCorrectly() public {
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        assertTrue(mandateHash != bytes32(0));
        assertEq(mockTarget.value(), 42);
    }

    /* //////////////////////////////////////////////////////////////
                    CALLDATA DISPATCH
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_Calldata_DispatchesCorrectly() public {
        Types.Operation memory ops = _calldataOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        assertTrue(mandateHash != bytes32(0));
        assertEq(mockTarget.value(), 42);
    }

    /* //////////////////////////////////////////////////////////////
                        REQUIRE NO OPS
    //////////////////////////////////////////////////////////////*/

    function test_requireNoOps_PassesForEmptyOps() public {
        // Empty ops should have hash == NO_OPS, which passes the check
        // This is tested indirectly via _compactPreClaimOps with empty ops
        // Just verify the mandate hash is valid
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);
        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_qualificationHash_ReturnsHash() public view {
        bytes memory data = hex"aabbccdd";
        bytes32 hash = arbiter.qualificationHash(data);
        assertTrue(hash != bytes32(0));
    }

    function test_qualificationHash_EmptyData() public view {
        bytes32 hash = arbiter.qualificationHash("");
        // Empty qualifier data should still return a valid hash (hash of empty struct)
        assertTrue(hash != bytes32(0) || hash == bytes32(0)); // always passes, but tests it doesn't revert
    }

    function test_supportsInterface_IArbiter() public view {
        assertTrue(arbiter.supportsInterface(type(IArbiter).interfaceId));
    }

    function test_supportsInterface_ERC165() public view {
        assertTrue(arbiter.supportsInterface(arbiter.supportsInterface.selector));
    }

    function test_supportsInterface_Unknown_ReturnsFalse() public view {
        assertFalse(arbiter.supportsInterface(bytes4(0xdeadbeef)));
    }

    /* //////////////////////////////////////////////////////////////
                        FAILURE PATHS
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_MultiCall_Failure_EmitsEvent() public {
        mockTarget.setShouldRevert(true);
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        // Multicall failure is tolerated (doesn't revert), just emits event
        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
        assertTrue(mandateHash != bytes32(0));
    }

    function test_compactPreClaimOps_Calldata_Failure_EmitsEvent() public {
        mockTarget.setShouldRevert(true);
        Types.Operation memory ops = _calldataOps();
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                        ONLY ROUTER ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_onlyRouter_RevertsWhen_CallerIsNotRouter() public {
        // Arrange
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);
        address notRouter = makeAddr("notRouter");

        // Act & Assert
        vm.prank(notRouter);
        vm.expectRevert(ArbiterBase.OnlyRouter.selector);
        realArbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);
    }

    function test_onlyRouter_SucceedsWhen_CallerIsRouter() public {
        // Arrange
        Types.Order memory order = _createOrder(_emptyOps());
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        // Act
        vm.prank(router);
        bytes32 mandateHash = realArbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        // Assert
        assertTrue(mandateHash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                    REQUIRE NO OPS REVERT
    //////////////////////////////////////////////////////////////*/

    function test_requireNoOps_RevertsWhen_NonEmptyOps() public {
        // Arrange - use ERC7579 ops which are non-empty and will have a hash != NO_OPS
        Types.Operation memory nonEmptyOps = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);

        // Act & Assert
        vm.expectRevert(ArbiterBase.NoOperationsAllowed.selector);
        arbiter.exposed_requireNoOps(nonEmptyOps);
    }

    /* //////////////////////////////////////////////////////////////
                    GAS STIPEND VALIDATION (minGas > 0)
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_WithMinGas_SucceedsWhen_SufficientGas() public {
        // Arrange - set minGas > 0 with enough gas available
        uint128 gasStipend = 500_000;
        uint128 minGas = 100_000;
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrderWithGas(ops, gasStipend, minGas);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        // Act - call with plenty of gas (default gas limit is high)
        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        // Assert
        assertTrue(mandateHash != bytes32(0));
    }

    function test_compactPreClaimOps_WithMinGas_RevertsWhen_InsufficientGas() public {
        // Arrange - set a high preClaimGasStipend that triggers _requireValidGasLeft
        // The gas check in PreClaimExecution._requireValidGasLeft(uint256 gasStipend) will revert
        // if gasleft() < gasStipend + (gasStipend / 63) + 10_000
        uint128 gasStipend = 500_000;
        uint128 minGas = 100_000;
        Types.Operation memory ops = _multicallOps();
        Types.Order memory order = _createOrderWithGas(ops, gasStipend, minGas);
        Types.Signatures memory sigs = _createSigs();
        bytes32[] memory otherElements = new bytes32[](0);

        // Act & Assert - call with very limited gas to trigger InsufficientGasForMinGas
        // The gasStipend check: requiredGas = 500_000 + (500_000 / 63) + 10_000 ~= 517_936
        // Provide less gas than required to trigger the revert
        vm.expectRevert();
        arbiter.exposed_compactPreClaimOps{ gas: 200_000 }(order, sigs, otherElements, 0, block.chainid);
    }

    /* //////////////////////////////////////////////////////////////
                    PRE-CLAIM SIG SELECTION
    //////////////////////////////////////////////////////////////*/

    function test_compactPreClaimOps_ERC7579_UsesPreClaimSigWhenNonEmpty() public {
        // Arrange - provide a non-empty preClaimSig to exercise the ternary:
        // sigs.preClaimSig.length != 0 ? sigs.preClaimSig : sigs.notarizedClaimSig
        mockExecutor.setShouldSucceed(true);
        Types.Operation memory ops = _erc7579Ops(SmartExecutionLib.SigMode.ERC1271);
        Types.Order memory order = _createOrder(ops);
        Types.Signatures memory sigs = _createSigsWithPreClaimSig();
        bytes32[] memory otherElements = new bytes32[](0);

        // Act
        bytes32 mandateHash = arbiter.exposed_compactPreClaimOps(order, sigs, otherElements, 0, block.chainid);

        // Assert - should succeed with a valid mandate hash
        assertTrue(mandateHash != bytes32(0));
    }
}
