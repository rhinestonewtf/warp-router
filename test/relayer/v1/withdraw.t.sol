// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

// Types
import { TokenAmount } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";

contract RhinestoneRelayer_withdraw_Test is RhinestoneRelayer_Test {
    event Withdrawn(address indexed token, uint256 amount);

    function test_withdraw_singleToken() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(address(token), 100e18);

        vm.prank(owner);
        relayer.withdraw(withdrawals);

        assertEq(token.balanceOf(owner), ownerBalanceBefore + 100e18);
        assertEq(token.balanceOf(address(relayer)), 900e18);
    }

    function test_withdraw_multipleTokens() public {
        // Deploy and fund with second token
        MockERC20 token2 = new MockERC20("Token 2", "TK2");
        token2.mint(address(relayer), 500e18);

        TokenAmount[] memory withdrawals = new TokenAmount[](2);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 200e18 });
        withdrawals[1] = TokenAmount({ token: address(token2), amount: 300e18 });

        vm.prank(owner);
        relayer.withdraw(withdrawals);

        assertEq(token.balanceOf(owner), 200e18);
        assertEq(token2.balanceOf(owner), 300e18);
        assertEq(token.balanceOf(address(relayer)), 800e18);
        assertEq(token2.balanceOf(address(relayer)), 200e18);
    }

    function test_withdraw_nativeETH() public {
        // Fund relayer with ETH
        vm.deal(address(relayer), 5 ether);

        uint256 ownerBalanceBefore = owner.balance;

        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(0), // Native ETH
            amount: 2 ether
        });

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(address(0), 2 ether);

        vm.prank(owner);
        relayer.withdraw(withdrawals);

        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
        assertEq(address(relayer).balance, 3 ether);
    }

    function test_withdraw_mixedETHAndTokens() public {
        // Fund with ETH
        vm.deal(address(relayer), 3 ether);

        uint256 ownerETHBefore = owner.balance;
        uint256 ownerTokenBefore = token.balanceOf(owner);

        TokenAmount[] memory withdrawals = new TokenAmount[](2);
        withdrawals[0] = TokenAmount({ token: address(0), amount: 1 ether });
        withdrawals[1] = TokenAmount({ token: address(token), amount: 150e18 });

        vm.prank(owner);
        relayer.withdraw(withdrawals);

        assertEq(owner.balance, ownerETHBefore + 1 ether);
        assertEq(token.balanceOf(owner), ownerTokenBefore + 150e18);
    }

    function test_withdraw_RevertsWhen_OnlyOwner() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        // Non-owner should fail
        vm.prank(user);
        vm.expectRevert();
        relayer.withdraw(withdrawals);

        // Relayer should fail
        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.withdraw(withdrawals);
    }

    function test_withdraw_RevertsWhen_InsufficientBalance() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(token),
            amount: 2000e18 // More than balance
        });

        vm.prank(owner);
        vm.expectRevert(); // Should revert on insufficient balance
        relayer.withdraw(withdrawals);
    }

    function test_withdraw_emptyArray() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](0);

        // Should not revert with empty array
        vm.prank(owner);
        relayer.withdraw(withdrawals);
    }

    function test_withdraw_fullBalance() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(token),
            amount: 1000e18 // Full balance
        });

        vm.prank(owner);
        relayer.withdraw(withdrawals);

        assertEq(token.balanceOf(owner), 1000e18);
        assertEq(token.balanceOf(address(relayer)), 0);
    }
}
