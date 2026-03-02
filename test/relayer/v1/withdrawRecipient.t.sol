// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

// Types
import { TokenAmount } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";

contract RhinestoneRelayer_withdrawRecipient_Test is RhinestoneRelayer_Test {
    event Withdrawn(address indexed token, uint256 amount);
    error InvalidRecipient();

    address public recipient = address(0x9999);

    function test_withdrawRecipient_singleToken() public {
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(address(token), 100e18);

        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);

        assertEq(token.balanceOf(recipient), recipientBalanceBefore + 100e18);
        assertEq(token.balanceOf(address(relayer)), 900e18);
        assertEq(token.balanceOf(owner), 0); // Owner should NOT receive tokens
    }

    function test_withdrawRecipient_multipleTokens() public {
        // Deploy and fund with second token
        MockERC20 token2 = new MockERC20("Token 2", "TK2");
        token2.mint(address(relayer), 500e18);

        TokenAmount[] memory withdrawals = new TokenAmount[](2);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 200e18 });
        withdrawals[1] = TokenAmount({ token: address(token2), amount: 300e18 });

        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);

        assertEq(token.balanceOf(recipient), 200e18);
        assertEq(token2.balanceOf(recipient), 300e18);
        assertEq(token.balanceOf(address(relayer)), 800e18);
        assertEq(token2.balanceOf(address(relayer)), 200e18);
        // Owner should have nothing
        assertEq(token.balanceOf(owner), 0);
        assertEq(token2.balanceOf(owner), 0);
    }

    function test_withdrawRecipient_nativeETH() public {
        // Fund relayer with ETH
        vm.deal(address(relayer), 5 ether);

        uint256 recipientBalanceBefore = recipient.balance;

        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(0), // Native ETH
            amount: 2 ether
        });

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(address(0), 2 ether);

        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);

        assertEq(recipient.balance, recipientBalanceBefore + 2 ether);
        assertEq(address(relayer).balance, 3 ether);
        assertEq(owner.balance, 0); // Owner should NOT receive ETH
    }

    function test_withdrawRecipient_mixedETHAndTokens() public {
        // Fund with ETH
        vm.deal(address(relayer), 3 ether);

        uint256 recipientETHBefore = recipient.balance;
        uint256 recipientTokenBefore = token.balanceOf(recipient);

        TokenAmount[] memory withdrawals = new TokenAmount[](2);
        withdrawals[0] = TokenAmount({ token: address(0), amount: 1 ether });
        withdrawals[1] = TokenAmount({ token: address(token), amount: 150e18 });

        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);

        assertEq(recipient.balance, recipientETHBefore + 1 ether);
        assertEq(token.balanceOf(recipient), recipientTokenBefore + 150e18);
        // Owner should have nothing
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_withdrawRecipient_RevertsWhen_OnlyOwner() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        // Non-owner should fail
        vm.prank(user);
        vm.expectRevert();
        relayer.withdraw(recipient, withdrawals);

        // Relayer should fail
        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.withdraw(recipient, withdrawals);
    }

    function test_withdrawRecipient_RevertsWhen_InsufficientBalance() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(token),
            amount: 2000e18 // More than balance
        });

        vm.prank(owner);
        vm.expectRevert(); // Should revert on insufficient balance
        relayer.withdraw(recipient, withdrawals);
    }

    function test_withdrawRecipient_emptyArray() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](0);

        // Should not revert with empty array
        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);
    }

    function test_withdrawRecipient_fullBalance() public {
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({
            token: address(token),
            amount: 1000e18 // Full balance
        });

        vm.prank(owner);
        relayer.withdraw(recipient, withdrawals);

        assertEq(token.balanceOf(recipient), 1000e18);
        assertEq(token.balanceOf(address(relayer)), 0);
        assertEq(token.balanceOf(owner), 0); // Owner should NOT receive tokens
    }

    function test_withdrawRecipient_toOwnerIsSameAsWithdraw() public {
        // Test that withdraw(owner, tokens) is equivalent to withdraw(tokens)
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        relayer.withdraw(owner, withdrawals);

        assertEq(token.balanceOf(owner), ownerBalanceBefore + 100e18);
        assertEq(token.balanceOf(address(relayer)), 900e18);
    }

    function test_withdrawRecipient_toRelayerEOA() public {
        // Can withdraw to the relayer EOA address
        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(token), amount: 100e18 });

        uint256 relayerEOABalanceBefore = token.balanceOf(relayerEOA);

        vm.prank(owner);
        relayer.withdraw(relayerEOA, withdrawals);

        assertEq(token.balanceOf(relayerEOA), relayerEOABalanceBefore + 100e18);
        assertEq(token.balanceOf(address(relayer)), 900e18);
    }

    function test_withdrawRecipient_RevertsWhen_RecipientIsZero() public {
        vm.deal(address(relayer), 1 ether);

        TokenAmount[] memory withdrawals = new TokenAmount[](1);
        withdrawals[0] = TokenAmount({ token: address(0), amount: 0.5 ether });

        vm.prank(owner);
        vm.expectRevert(InvalidRecipient.selector);
        relayer.withdraw(address(0), withdrawals);
    }
}
