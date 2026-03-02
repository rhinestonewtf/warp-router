// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

// Types
import { TokenAmount } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";

contract RhinestoneRelayer_setApprovals_Test is RhinestoneRelayer_Test {
    event Approved(address indexed token, uint256 amount, address router);

    MockERC20 public token2;
    MockERC20 public token3;

    function setUp() public override {
        super.setUp();

        // Deploy additional tokens
        token2 = new MockERC20("Token 2", "TK2");
        token3 = new MockERC20("Token 3", "TK3");
    }

    function test_setApprovals_single() public {
        TokenAmount[] memory approvals = new TokenAmount[](1);
        approvals[0] = TokenAmount({ token: address(token2), amount: 500e18 });

        vm.expectEmit(true, false, false, true);
        emit Approved(address(token2), 500e18, address(router));

        vm.prank(owner);
        relayer.setApprovals(approvals);

        assertEq(token2.allowance(address(relayer), address(router)), 500e18);
    }

    function test_setApprovals_multiple() public {
        TokenAmount[] memory approvals = new TokenAmount[](3);
        approvals[0] = TokenAmount({ token: address(token), amount: 100e18 });
        approvals[1] = TokenAmount({ token: address(token2), amount: 200e18 });
        approvals[2] = TokenAmount({ token: address(token3), amount: 300e18 });

        vm.prank(owner);
        relayer.setApprovals(approvals);

        assertEq(token.allowance(address(relayer), address(router)), 100e18);
        assertEq(token2.allowance(address(relayer), address(router)), 200e18);
        assertEq(token3.allowance(address(relayer), address(router)), 300e18);
    }

    function test_setApprovals_updateExisting() public {
        // Check initial approval
        assertEq(token.allowance(address(relayer), address(router)), 1000e18);

        // Update to new amount
        TokenAmount[] memory approvals = new TokenAmount[](1);
        approvals[0] = TokenAmount({ token: address(token), amount: 2000e18 });

        vm.prank(owner);
        relayer.setApprovals(approvals);

        assertEq(token.allowance(address(relayer), address(router)), 2000e18);
    }

    function test_setApprovals_RevertsWhen_OnlyOwner() public {
        TokenAmount[] memory approvals = new TokenAmount[](1);
        approvals[0] = TokenAmount({ token: address(token2), amount: 100e18 });

        // Non-owner should fail
        vm.prank(user);
        vm.expectRevert();
        relayer.setApprovals(approvals);

        // Relayer should fail
        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.setApprovals(approvals);
    }

    function test_setApprovals_zeroAmount() public {
        // Set approval to zero (revoke)
        TokenAmount[] memory approvals = new TokenAmount[](1);
        approvals[0] = TokenAmount({ token: address(token), amount: 0 });

        vm.prank(owner);
        relayer.setApprovals(approvals);

        assertEq(token.allowance(address(relayer), address(router)), 0);
    }

    function test_setApprovals_emptyArray() public {
        TokenAmount[] memory approvals = new TokenAmount[](0);

        // Should not revert with empty array
        vm.prank(owner);
        relayer.setApprovals(approvals);
    }
}
