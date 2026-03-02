// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { AdapterBase_Unit_Test } from "test/unit/base/adapter/AdapterBase/AdapterBase.t.sol";

// Contracts
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

contract AdapterBase_PrefundRecipient_Unit_Test is AdapterBase_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                            ERC20 PREFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_prefundRecipient_SingleERC20() public {
        uint256[2][] memory tokenOut = _createBasicTokenOut();
        uint256 balanceBefore = token1.balanceOf(recipient);

        // Approve adapter from solver
        vm.prank(solver);
        token1.approve(address(adapter), 100 ether);

        adapter.mockPrefundRecipient(solver, recipient, tokenOut);

        assertEq(token1.balanceOf(recipient), balanceBefore + 100 ether);
    }

    function test_prefundRecipient_MultipleERC20s() public {
        uint256[2][] memory tokenOut = _createMultipleTokenOut();

        uint256 balance1Before = token1.balanceOf(recipient);
        uint256 balance2Before = token2.balanceOf(recipient);

        vm.startPrank(solver);
        token1.approve(address(adapter), 50 ether);
        token2.approve(address(adapter), 75 ether);
        vm.stopPrank();

        adapter.mockPrefundRecipient(solver, recipient, tokenOut);

        assertEq(token1.balanceOf(recipient), balance1Before + 50 ether);
        assertEq(token2.balanceOf(recipient), balance2Before + 75 ether);
    }

    function test_prefundRecipient_ZeroAmount() public {
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), 0];

        uint256 balanceBefore = token1.balanceOf(recipient);

        adapter.mockPrefundRecipient(solver, recipient, tokenOut);

        assertEq(token1.balanceOf(recipient), balanceBefore); // No change
    }

    /* //////////////////////////////////////////////////////////////
                            NATIVE PREFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_prefundRecipient_NativeETH() public {
        uint256 amount = 1 ether;
        uint256 balanceBefore = recipient.balance;

        vm.deal(address(adapter), 10 ether);

        adapter.mockPrefundRecipientSingle{ value: amount }(address(adapter), recipient, Constants.NATIVE_TOKEN, amount);

        assertEq(recipient.balance, balanceBefore + amount);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_prefundRecipient_RevertsWhen_InsufficientBalance() public {
        address poorSolver = makeAddr("poorSolver");
        uint256[2][] memory tokenOut = _createBasicTokenOut();

        vm.expectRevert(); // Should revert due to insufficient balance
        adapter.mockPrefundRecipient(poorSolver, recipient, tokenOut);
    }

    function test_prefundRecipient_RevertsWhen_InsufficientAllowance() public {
        address unapprovedSolver = makeAddr("unapprovedSolver");
        token1.mint(unapprovedSolver, 1000 ether);

        uint256[2][] memory tokenOut = _createBasicTokenOut();

        vm.expectRevert(); // Should revert due to no approval
        adapter.mockPrefundRecipient(unapprovedSolver, recipient, tokenOut);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_prefundRecipient_ERC20(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to); // Avoid self-transfer edge case
        vm.assume(amount > 0 && amount <= 1000 ether);

        // Setup
        token1.mint(from, amount);
        vm.prank(from);
        token1.approve(address(adapter), amount);

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), amount];

        uint256 balanceBefore = token1.balanceOf(to);

        adapter.mockPrefundRecipient(from, to, tokenOut);

        assertEq(token1.balanceOf(to), balanceBefore + amount);
    }
}
