// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "test/unit/router/core/RouterLogic/RouterLogic.t.sol";

// Contracts
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { DirectRoutes } from "src/router/core/DirectRoutes.sol";

contract DirectRoutes_SetApprovals_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                    SET SINGLE APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_setApproval_Single_Succeeds() public {
        address spender = makeAddr("spender");

        bytes memory data = abi.encodePacked(
            address(token1), spender, uint256(10 ether), uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data);

        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);
    }

    function test_onFill_inRouter_setApproval_Single_ZeroAmount_Succeeds() public {
        address spender = makeAddr("spender");

        bytes memory data =
            abi.encodePacked(address(token1), spender, uint256(0), uint64(block.chainid), uint32(block.timestamp + 1 hours));

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data);

        assertEq(token1.allowance(address(routerLogic), spender), 0);
    }

    function test_onFill_inRouter_setApproval_Single_MaxAmount_Succeeds() public {
        address spender = makeAddr("spender");

        bytes memory data = abi.encodePacked(
            address(token1), spender, type(uint256).max, uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data);

        assertEq(token1.allowance(address(routerLogic), spender), type(uint256).max);
    }

    function test_onFill_inRouter_setApproval_Single_OverwriteExisting() public {
        address spender = makeAddr("spender");

        // Set initial approval
        bytes memory data1 = abi.encodePacked(
            address(token1), spender, uint256(10 ether), uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data1);
        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);

        // Update to new amount
        bytes memory data2 = abi.encodePacked(
            address(token1), spender, uint256(50 ether), uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data2);
        assertEq(token1.allowance(address(routerLogic), spender), 50 ether);
    }

    function test_onFill_inRouter_setApproval_Single_Revoke() public {
        address spender = makeAddr("spender");

        // Set initial approval
        bytes memory data1 = abi.encodePacked(
            address(token1), spender, uint256(100 ether), uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data1);
        assertEq(token1.allowance(address(routerLogic), spender), 100 ether);

        // Revoke by setting to 0
        bytes memory data2 = abi.encodePacked(
            address(token1), spender, uint256(0), uint64(block.chainid), uint32(block.timestamp + 1 hours)
        );
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data2);
        assertEq(token1.allowance(address(routerLogic), spender), 0);
    }

    function testFuzz_onFill_inRouter_setApproval_Single(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        bytes memory data =
            abi.encodePacked(address(token1), spender, amount, uint64(block.chainid), uint32(block.timestamp + 1 hours));

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data);

        assertEq(token1.allowance(address(routerLogic), spender), amount);
    }

    /* //////////////////////////////////////////////////////////////
                    SET APPROVAL BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_setApproval_SingleToken_Succeeds() public {
        address spender = makeAddr("spender");

        // Approve token1 from routerLogic to spender for 10 ether
        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 10 ether];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        // Transfer some tokens to router first so it can set approvals
        vm.prank(solver);
        token1.transfer(address(routerLogic), 100 ether);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);
    }

    function test_onFill_inRouter_setApproval_MultipleTokens_Succeeds() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](2);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 5 ether];
        tokenAndSpenderAndAmounts[1] = [uint256(uint160(address(token2))), uint256(uint160(spender)), 15 ether];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.startPrank(solver);
        token1.transfer(address(routerLogic), 100 ether);
        token2.transfer(address(routerLogic), 100 ether);
        vm.stopPrank();

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), 5 ether);
        assertEq(token2.allowance(address(routerLogic), spender), 15 ether);
    }

    function test_onFill_inRouter_setApproval_ZeroAmount_Succeeds() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 0];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), 0);
    }

    function test_onFill_inRouter_setApproval_MaxAmount_Succeeds() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), type(uint256).max];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), type(uint256).max);
    }

    /* //////////////////////////////////////////////////////////////
                    SET APPROVAL MULTIPLE SPENDERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_setApproval_MultipleSpenders_Succeeds() public {
        address spender1 = makeAddr("spender1");
        address spender2 = makeAddr("spender2");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](2);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender1)), 10 ether];
        tokenAndSpenderAndAmounts[1] = [uint256(uint160(address(token1))), uint256(uint160(spender2)), 20 ether];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender1), 10 ether);
        assertEq(token1.allowance(address(routerLogic), spender2), 20 ether);
    }

    function test_onFill_inRouter_setApproval_DifferentTokensAndSpenders_Succeeds() public {
        address spender1 = makeAddr("spender1");
        address spender2 = makeAddr("spender2");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](2);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender1)), 10 ether];
        tokenAndSpenderAndAmounts[1] = [uint256(uint160(address(token2))), uint256(uint160(spender2)), 20 ether];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender1), 10 ether);
        assertEq(token2.allowance(address(routerLogic), spender2), 20 ether);
    }

    function test_onFill_inRouter_setApproval_ComplexScenario() public {
        address spender1 = makeAddr("spender1");
        address spender2 = makeAddr("spender2");
        address spender3 = makeAddr("spender3");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](5);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender1)), 10 ether];
        tokenAndSpenderAndAmounts[1] = [uint256(uint160(address(token2))), uint256(uint160(spender2)), 20 ether];
        tokenAndSpenderAndAmounts[2] = [uint256(uint160(address(token1))), uint256(uint160(spender2)), 5 ether];
        tokenAndSpenderAndAmounts[3] = [uint256(uint160(address(token3))), uint256(uint160(spender3)), 30 ether];
        tokenAndSpenderAndAmounts[4] = [uint256(uint160(address(token2))), uint256(uint160(spender1)), 15 ether];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender1), 10 ether);
        assertEq(token1.allowance(address(routerLogic), spender2), 5 ether);
        assertEq(token2.allowance(address(routerLogic), spender1), 15 ether);
        assertEq(token2.allowance(address(routerLogic), spender2), 20 ether);
        assertEq(token3.allowance(address(routerLogic), spender3), 30 ether);
    }

    function test_onFill_inRouter_setApproval_EmptyArray_Succeeds() public {
        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](0);
        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        // Should succeed without doing anything
    }

    /* //////////////////////////////////////////////////////////////
                    APPROVAL OVERWRITE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_setApproval_OverwriteExistingApproval() public {
        address spender = makeAddr("spender");

        // Set initial approval
        uint256[3][] memory tokenAndSpenderAndAmounts1 = new uint256[3][](1);
        tokenAndSpenderAndAmounts1[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 10 ether];

        bytes memory data1 = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts1)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data1);

        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);

        // Update approval to a new amount
        uint256[3][] memory tokenAndSpenderAndAmounts2 = new uint256[3][](1);
        tokenAndSpenderAndAmounts2[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 50 ether];

        bytes memory data2 = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts2)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data2);

        assertEq(token1.allowance(address(routerLogic), spender), 50 ether);
    }

    function test_onFill_inRouter_setApproval_RevokeApproval() public {
        address spender = makeAddr("spender");

        // Set initial approval
        uint256[3][] memory tokenAndSpenderAndAmounts1 = new uint256[3][](1);
        tokenAndSpenderAndAmounts1[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 100 ether];

        bytes memory data1 = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts1)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data1);

        assertEq(token1.allowance(address(routerLogic), spender), 100 ether);

        // Revoke approval by setting to 0
        uint256[3][] memory tokenAndSpenderAndAmounts2 = new uint256[3][](1);
        tokenAndSpenderAndAmounts2[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 0];

        bytes memory data2 = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts2)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data2);

        assertEq(token1.allowance(address(routerLogic), spender), 0);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_onFill_inRouter_setApproval_SingleToken(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), amount];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), amount);
    }

    function testFuzz_onFill_inRouter_setApproval_MultipleTokens(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 0, type(uint128).max);
        amount2 = bound(amount2, 0, type(uint128).max);
        amount3 = bound(amount3, 0, type(uint128).max);

        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](3);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), amount1];
        tokenAndSpenderAndAmounts[1] = [uint256(uint160(address(token2))), uint256(uint160(spender)), amount2];
        tokenAndSpenderAndAmounts[2] = [uint256(uint160(address(token3))), uint256(uint160(spender)), amount3];

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), amount1);
        assertEq(token2.allowance(address(routerLogic), spender), amount2);
        assertEq(token3.allowance(address(routerLogic), spender), amount3);
    }

    function testFuzz_onFill_inRouter_setApproval_MultipleApprovals(uint8 approvalCount) public {
        approvalCount = uint8(bound(approvalCount, 1, 10));
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](approvalCount);

        for (uint256 i = 0; i < approvalCount; i++) {
            tokenAndSpenderAndAmounts[i] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 1 ether * (i + 1)];
        }

        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp + 1 hours)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        // Last approval should be the final value
        assertEq(token1.allowance(address(routerLogic), spender), 1 ether * approvalCount);
    }

    /* //////////////////////////////////////////////////////////////
                    CHAINID AND EXPIRY VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_setApproval_Single_RevertWrongChainId() public {
        address spender = makeAddr("spender");

        // Use wrong chain ID (current + 1)
        bytes memory data = abi.encodePacked(
            address(token1), spender, uint256(10 ether), uint64(block.chainid + 1), uint32(block.timestamp + 1 hours)
        );

        vm.prank(solver);
        vm.expectRevert(DirectRoutes.InvalidApprovalChainId.selector);
        routerLogic.exposed_onFill_inRouter_setApproval(data);
    }

    function test_onFill_inRouter_setApproval_Single_RevertExpired() public {
        address spender = makeAddr("spender");

        // Use expired timestamp (1 second ago)
        bytes memory data = abi.encodePacked(
            address(token1), spender, uint256(10 ether), uint64(block.chainid), uint32(block.timestamp - 1)
        );

        vm.prank(solver);
        vm.expectRevert(DirectRoutes.InvalidApprovalExpired.selector);
        routerLogic.exposed_onFill_inRouter_setApproval(data);
    }

    function test_onFill_inRouter_setApprovals_RevertWrongChainId() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 10 ether];

        // Use wrong chain ID (current + 1)
        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid + 1), uint32(block.timestamp + 1 hours)),
            abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        vm.expectRevert(DirectRoutes.InvalidApprovalChainId.selector);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);
    }

    function test_onFill_inRouter_setApprovals_RevertExpired() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 10 ether];

        // Use expired timestamp (1 second ago)
        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp - 1)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        vm.expectRevert(DirectRoutes.InvalidApprovalExpired.selector);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);
    }

    function test_onFill_inRouter_setApproval_Single_ExactExpiryTimestamp() public {
        address spender = makeAddr("spender");

        // Use exact current timestamp (should succeed since expires >= block.timestamp)
        bytes memory data = abi.encodePacked(
            address(token1), spender, uint256(10 ether), uint64(block.chainid), uint32(block.timestamp)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApproval(data);

        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);
    }

    function test_onFill_inRouter_setApprovals_ExactExpiryTimestamp() public {
        address spender = makeAddr("spender");

        uint256[3][] memory tokenAndSpenderAndAmounts = new uint256[3][](1);
        tokenAndSpenderAndAmounts[0] = [uint256(uint160(address(token1))), uint256(uint160(spender)), 10 ether];

        // Use exact current timestamp (should succeed since expires >= block.timestamp)
        bytes memory data = bytes.concat(
            abi.encodePacked(uint64(block.chainid), uint32(block.timestamp)), abi.encode(tokenAndSpenderAndAmounts)
        );

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_setApprovals(data);

        assertEq(token1.allowance(address(routerLogic), spender), 10 ether);
    }
}
