// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { SameChainAdapter_Unit_Test } from "test/unit/arbiters/SameChainAdapter/SameChainAdapter.t.sol";

// Contracts
import { SameChainAdapter } from "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

// Interfaces
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ITheCompact } from "the-compact/interfaces/ITheCompact.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";
import { Mock1271Account } from "test/utils/mocks/Mock1271Account.sol";

contract SameChainAdapter_Compact_HandleFill_Unit_Test is SameChainAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                            BASIC FILL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_samechain_compact_handleFill_RevertsWhen_NotCalledViaRouter() public {
        // Lock assets first
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        sameChainAdapter.samechain_compact_handleFill(fillData);
    }

    function test_samechain_compact_handleFill_BasicFill() public {
        // Lock assets for the sponsor (100 ether tokenA as per order)
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        uint256 recipientBalanceBefore = tokenB.balanceOf(recipient);

        bytes4 selector = _executeHandleFillCompact(fillData);

        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
        assertEq(tokenB.balanceOf(recipient), recipientBalanceBefore + 50 ether, "Recipient should receive tokenOut");
    }

    function test_samechain_compact_handleFill_MultipleTokensIn() public {
        // Lock assets for both tokens in the order
        _lockAssets(address(tokenA), 100 ether);
        _lockAssets(address(tokenB), 50 ether);

        Types.Order memory order = _createOrderWithMultipleTokensIn();

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: order, userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: ""
        });

        // Approve output token for pre-funding
        vm.prank(solver);
        tokenC.approve(router, 75 ether);

        uint256 recipientBalanceBefore = tokenC.balanceOf(recipient);

        bytes4 selector = _executeHandleFillCompact(fillData);

        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
        assertEq(tokenC.balanceOf(recipient), recipientBalanceBefore + 75 ether, "Recipient should receive tokenOut");
    }

    function test_samechain_compact_handleFill_EmitsFilled() public {
        vm.skip(true);
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        _prankDelegateCall();

        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);
        bytes memory adapterCalldata = abi.encodeWithSelector(SameChainAdapter.samechain_compact_handleFill.selector, fillData);
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        vm.expectEmit(true, false, false, false);
        // emit AdapterBase.Filled(fillData.order.nonce);

        vm.prank(solver);
        router.call(fullCalldata);
    }

    function test_samechain_compact_handleFill_RevertsWhen_InvalidSignature() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // Set the account to fail signature validation
        Mock1271Account(sponsor).setSigIsValid(false);

        // Should revert due to invalid signature
        vm.expectRevert();
        _executeHandleFillCompact(fillData);

        // Reset for cleanup
        Mock1271Account(sponsor).setSigIsValid(true);
    }

    function test_samechain_compact_handleFill_RevertsWhen_ExpiredFillDeadline() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // Set the order deadline to past
        fillData.order.fillDeadline = uint64(block.timestamp - 1);

        // Should revert due to expired deadline
        vm.expectRevert();
        _executeHandleFillCompact(fillData);

        // Reset for cleanup
        Mock1271Account(sponsor).setSigIsValid(true);
    }

    function test_samechain_compact_handleFill_WithOtherElements() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        bytes32[] memory otherElements = new bytes32[](2);
        otherElements[0] = keccak256("element1");
        otherElements[1] = keccak256("element2");

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: _createBasicOrder(), userSigs: _createBasicSignatures(), otherElements: otherElements, allocatorData: ""
        });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillCompact(fillData);
        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
    }

    function test_samechain_compact_handleFill_WithAllocatorData() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        bytes memory allocatorData = abi.encode(uint256(123), address(0x456));

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: _createBasicOrder(), userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: allocatorData
        });

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillCompact(fillData);
        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
    }

    function test_samechain_compact_handleFill_WithETHValue() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        SameChainAdapter.FillDataCompact memory fillData = _createBasicFillDataCompact();

        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        _prankDelegateCall();

        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);
        bytes memory adapterCalldata = abi.encodeWithSelector(SameChainAdapter.samechain_compact_handleFill.selector, fillData);
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        vm.prank(solver);
        (bool success,) = router.call{ value: 1 ether }(fullCalldata);
        assertTrue(success, "Call with ETH should succeed");
    }

    /* //////////////////////////////////////////////////////////////
                        PRECLAIM OPS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Pre-claim operations with 0 gas stipend now cause the transaction to revert
    ///      rather than silently failing. This is intentional security behavior to prevent
    ///      fills from proceeding when pre-claim operations cannot be executed.
    function test_samechain_compact_handleFill_WithPreClaimOps_PreClaimOps_Fail_LowGas() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        // Mint tokenC for sponsor to use in pre-claim operations
        tokenC.mint(sponsor, 100 ether);

        // Setup pre-claim operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: order, userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: ""
        });

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        // With 0 gas stipend (packedGasValues: 0), pre-claim operations cannot execute
        // and the fill now reverts instead of silently failing
        vm.expectRevert();
        _executeHandleFillCompact(fillData);
    }

    function test_samechain_compact_handleFill_WithPreClaimOps_PreClaimOps_Success() public {
        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        // Mint tokenC for sponsor to use in pre-claim operations
        tokenC.mint(sponsor, 100 ether);

        // Setup pre-claim operations
        bytes memory preClaimData = _encodePreClaimOperationsERC7579();

        Types.Order memory order = _createBasicOrder();
        order.preClaimOps = Types.Operation({ data: preClaimData });
        order.packedGasValues = Types.packGasValues(3_000_000, 1_000_000); // High gas stipend to ensure execution

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: order, userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: ""
        });

        // Check initial state
        uint256 token3AllowanceBefore = tokenC.allowance(sponsor, address(target));
        uint256 targetParamBefore = target.param();

        assertEq(token3AllowanceBefore, 0, "TokenC allowance should be 0 initially");
        assertEq(targetParamBefore, 0, "Target param should be 0 initially");

        // Approve tokens for pre-funding
        vm.prank(solver);
        tokenB.approve(router, 50 ether);

        bytes4 selector = _executeHandleFillCompact(fillData);

        // Verify pre-claim operations were executed
        uint256 token3AllowanceAfter = tokenC.allowance(sponsor, address(target));
        uint256 targetParamAfter = target.param();

        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
        assertEq(token3AllowanceAfter, 50 ether, "TokenC allowance should be updated");
        assertEq(targetParamAfter, 12_345, "Target param should be updated");
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_samechain_compact_handleFill(uint256 tokenOutAmount, uint64 nonce) public {
        vm.assume(tokenOutAmount > 0 && tokenOutAmount <= 1000 ether);

        // Lock assets
        _lockAssets(address(tokenA), 100 ether);

        Types.Order memory order = _createBasicOrder();
        order.tokenOut[0] = [_toId(address(tokenB)), tokenOutAmount];
        order.nonce = nonce;

        SameChainAdapter.FillDataCompact memory fillData = SameChainAdapter.FillDataCompact({
            order: order, userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: ""
        });

        vm.prank(solver);
        tokenB.approve(router, tokenOutAmount);

        bytes4 selector = _executeHandleFillCompact(fillData);
        assertEq(selector, sameChainAdapter.samechain_compact_handleFill.selector);
        assertEq(tokenB.balanceOf(recipient), tokenOutAmount);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createBasicFillDataCompact() internal returns (SameChainAdapter.FillDataCompact memory) {
        // Note: Caller should lock assets before calling this
        return SameChainAdapter.FillDataCompact({
            order: _createBasicOrder(), userSigs: _createBasicSignatures(), otherElements: new bytes32[](0), allocatorData: ""
        });
    }

    function _lockAssets(address token, uint256 amount) internal returns (uint256 tokenId) {
        MockERC20(token).mint(sponsor, amount);
        vm.startPrank(sponsor);
        IERC20(token).approve(address(compact), amount);
        tokenId = ITheCompact(compact).depositERC20(token, lockTag, amount, sponsor);
        vm.stopPrank();
    }
}
