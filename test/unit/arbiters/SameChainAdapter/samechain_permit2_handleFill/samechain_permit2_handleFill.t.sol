// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { SameChainAdapter_Unit_Test } from "test/unit/arbiters/SameChainAdapter/SameChainAdapter.t.sol";

// Contracts
import { SameChainAdapter } from "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";

// Interfaces
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { Mock1271Account } from "test/utils/mocks/Mock1271Account.sol";

contract SameChainAdapter_Permit2_HandleFill_Unit_Test is SameChainAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                            BASIC FILL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_samechain_permit2_handleFill_RevertsWhen_NotCalledViaRouter() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        sameChainAdapter.samechain_permit2_handleFill(fillData);
    }

    function test_samechain_permit2_handleFill_BasicFill() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        uint256 recipientBalanceBefore = tokenB.balanceOf(recipient);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(recipient), recipientBalanceBefore + 50 ether, "Recipient should receive tokenOut");
    }

    function test_samechain_permit2_handleFill_EmitsFilled() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        _prankDelegateCall();

        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);
        bytes memory adapterCalldata = abi.encodeWithSelector(SameChainAdapter.samechain_permit2_handleFill.selector, fillData);
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        // Note: AdapterBase doesn't emit a Filled event, so we just verify the call succeeds
        vm.prank(solver);
        (bool success,) = router.call(fullCalldata);
        assertTrue(success, "Router call should succeed");
    }

    function test_samechain_permit2_handleFill_WithETHValue() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        _prankDelegateCall();

        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);
        bytes memory adapterCalldata = abi.encodeWithSelector(SameChainAdapter.samechain_permit2_handleFill.selector, fillData);
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        vm.prank(solver);
        (bool success,) = router.call{ value: 1 ether }(fullCalldata);
        assertTrue(success, "Call with ETH should succeed");
    }

    function test_samechain_permit2_handleFill_RevertsWhen_InsufficientTokenOut() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        // Don't approve enough tokens
        vm.prank(solver);
        tokenB.approve(router, 10 ether); // Less than required 50 ether

        vm.expectRevert(); // Should revert due to insufficient approval
        _executeHandleFillPermit2(fillData);
    }

    function test_samechain_permit2_handleFill_PreFundsBeforeArbiter() public {
        SameChainAdapter.FillDataPermit2 memory fillData = _createBasicFillDataPermit2();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        uint256 recipientBalanceBefore = tokenB.balanceOf(recipient);

        _executeHandleFillPermit2(fillData);

        // Verify recipient was pre-funded (happened before arbiter call)
        assertEq(tokenB.balanceOf(recipient), recipientBalanceBefore + 50 ether);
    }

    function test_samechain_permit2_handleFill_DifferentRecipientAndSponsor() public {
        Types.Order memory order = _createBasicOrder();
        order.recipient = makeAddr("differentRecipient");

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(order.recipient), 50 ether);
    }

    function test_samechain_permit2_handleFill_ZeroTokenOut() public {
        Types.Order memory order = _createBasicOrder();
        order.tokenOut[0] = [uint256(uint160(address(tokenB))), 0];

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
    }

    function test_samechain_permit2_handleFill_MultipleTokensIn() public {
        Types.Order memory order = _createOrderWithMultipleTokensIn();

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        // Approve output token for pre-funding
        vm.prank(solver);
        tokenC.approve(router, 75 ether);

        uint256 recipientBalanceBefore = tokenC.balanceOf(recipient);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenC.balanceOf(recipient), recipientBalanceBefore + 75 ether);
    }

    function test_samechain_permit2_handleFill_SponsorEqualsRecipient() public {
        Types.Order memory order = _createBasicOrder();
        order.recipient = sponsor;

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(sponsor), 1050 ether); // 1000 initial + 50 from fill
    }

    function test_samechain_permit2_handleFill_RevertsWhen_ExpiredPermit() public {
        Types.Order memory order = _createBasicOrder();
        order.expires = block.timestamp - 1; // Already expired

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // This should revert in the arbiter validation
        vm.expectRevert();
        _executeHandleFillPermit2(fillData);
    }

    function test_samechain_permit2_handleFill_RevertsWhen_ExpiredFillDeadline() public {
        Types.Order memory order = _createBasicOrder();
        order.fillDeadline = block.timestamp - 1; // Already expired

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // This should revert in the arbiter validation
        vm.expectRevert();
        _executeHandleFillPermit2(fillData);
    }

    function test_samechain_permit2_handleFill_CrossChainOrder() public {
        Types.Order memory order = _createBasicOrder();
        order.targetChainId = 137; // Different chain

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
    }

    function test_samechain_permit2_handleFill_RevertsWhen_InvalidSignature() public {
        // Setup pre-claim operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        // Check initial state
        uint256 token3AllowanceBefore = tokenC.allowance(sponsor, address(target));

        assertEq(token3AllowanceBefore, 0, "TokenC allowance should be 0 initially");

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // Set the account to fail signature validation
        Mock1271Account(sponsor).setSigIsValid(false);

        vm.expectRevert();
        _executeHandleFillPermit2(fillData);
    }

    /* //////////////////////////////////////////////////////////////
                        PRECLAIM OPS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_samechain_permit2_handleFill_WithPreClaimOps_Fail_LowGas() public {
        // Setup pre-claim operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        // Check initial state
        uint256 token3AllowanceBefore = tokenC.allowance(sponsor, address(target));

        assertEq(token3AllowanceBefore, 0, "TokenC allowance should be 0 initially");

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify pre-claim operations not executed due to low gas stipend
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);

        uint256 token3AllowanceAfter = tokenC.allowance(sponsor, address(target));
        assertEq(token3AllowanceAfter, 0, "TokenC allowance should remain 0 due to low gas stipend");
    }

    function test_samechain_permit2_handleFill_WithPreClaimOps_Fail_Success() public {
        // Setup pre-claim operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });
        order.packedGasValues = Types.packGasValues(3_000_000, 1_000_000);

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        // Check initial state
        uint256 token3AllowanceBefore = tokenC.allowance(sponsor, address(target));

        assertEq(token3AllowanceBefore, 0, "TokenC allowance should be 0 initially");

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify pre-claim operations were executed
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);

        uint256 token3AllowanceAfter = tokenC.allowance(sponsor, address(target));
        assertEq(token3AllowanceAfter, 50 ether, "TokenC allowance should be updated by pre-claim ops");
    }

    function test_samechain_permit2_handleFill_PreClaimOps_MultipleOperations() public {
        // Create multiple pre-claim operations
        bytes memory preClaimData = _encodeMultiplePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });
        order.packedGasValues = Types.packGasValues(3_000_000, 1_000_000);

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify all operations executed
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenC.allowance(sponsor, address(target)), 30 ether);
        assertEq(tokenC.allowance(sponsor, solver), 20 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        TARGET OPS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_samechain_permit2_handleFill_WithTargetOps_RecipientEqualsSponsor() public {
        // Setup target operations
        bytes memory targetOpsData = _encodeTargetOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.recipient = sponsor;
        order.targetOps = Types.Operation({ data: targetOpsData });

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        uint256 targetBalanceBefore = tokenB.balanceOf(address(target));

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify target operations were executed
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(address(target)), targetBalanceBefore + 20 ether);
    }

    function test_samechain_permit2_handleFill_WithTargetOps_RecipientNotSponsor() public {
        // Setup target operations (should NOT execute)
        bytes memory targetOpsData = _encodeTargetOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.recipient = recipient;
        order.targetOps = Types.Operation({ data: targetOpsData });

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        uint256 targetBalanceBefore = tokenB.balanceOf(address(target));

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify target operations were NOT executed
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(address(target)), targetBalanceBefore);
    }

    function test_samechain_permit2_handleFill_WithBothPreClaimAndTargetOps() public {
        // Setup both pre-claim and target operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();
        bytes memory targetOpsData = _encodeTargetOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.recipient = sponsor;
        order.preClaimOps = Types.Operation({ data: preClaimData });
        order.packedGasValues = Types.packGasValues(3_000_000, 1_000_000);
        order.targetOps = Types.Operation({ data: targetOpsData });

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillPermit2(fillData);

        // Verify both pre-claim and target operations executed
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenC.allowance(sponsor, address(target)), 50 ether, "PreClaimOps should execute");
        assertEq(tokenB.balanceOf(address(target)), 20 ether, "TargetOps should execute");
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_samechain_permit2_handleFill(uint256 tokenOutAmount, uint64 nonce, address fuzzRecipient) public {
        vm.assume(tokenOutAmount > 0 && tokenOutAmount <= 1000 ether);
        vm.assume(fuzzRecipient != address(0));
        vm.assume(fuzzRecipient != solver);

        Types.Order memory order = _createBasicOrder();
        order.tokenOut[0] = [uint256(uint160(address(tokenB))), tokenOutAmount];
        order.nonce = nonce;
        order.recipient = fuzzRecipient;

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.prank(solver);
        tokenB.approve(router, tokenOutAmount);

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(fuzzRecipient), tokenOutAmount);
    }

    function testFuzz_samechain_permit2_handleFill_MultipleTokensOut(uint256 tokenAmount1, uint256 tokenAmount2) public {
        vm.assume(tokenAmount1 > 0 && tokenAmount1 <= 500 ether);
        vm.assume(tokenAmount2 > 0 && tokenAmount2 <= 500 ether);

        Types.Order memory order = _createBasicOrder();

        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0] = [uint256(uint160(address(tokenB))), tokenAmount1];
        tokenOut[1] = [uint256(uint160(address(tokenC))), tokenAmount2];
        order.tokenOut = tokenOut;

        SameChainAdapter.FillDataPermit2 memory fillData =
            SameChainAdapter.FillDataPermit2({ order: order, userSigs: _createBasicSignatures() });

        vm.startPrank(solver);
        tokenB.approve(router, tokenAmount1);
        tokenC.approve(router, tokenAmount2);
        vm.stopPrank();

        bytes4 selector = _executeHandleFillPermit2(fillData);
        assertEq(selector, sameChainAdapter.samechain_permit2_handleFill.selector);
        assertEq(tokenB.balanceOf(recipient), tokenAmount1);
        assertEq(tokenC.balanceOf(recipient), tokenAmount2);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createBasicFillDataPermit2() internal view returns (SameChainAdapter.FillDataPermit2 memory) {
        return SameChainAdapter.FillDataPermit2({ order: _createBasicOrder(), userSigs: _createBasicSignatures() });
    }
}
