// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Paymaster_Unit_Test } from "../Paymaster.t.sol";

// Contracts
import { Paymaster } from "src/executor/StandaloneIntent/aux/Paymaster.sol";
import { Constants } from "src/types/Constants.sol";

// Test helper to expose internal state
contract PaymasterExposed is Paymaster {
    constructor(address intentExecutor) Paymaster(intentExecutor, address(this)) { }

    function exposed_nativeAmounts(address account) external view returns (uint256) {
        return nativeAmounts[account];
    }
}

contract Paymaster_SettleGasRefund_Unit_Test is Paymaster_Unit_Test {
    PaymasterExposed internal paymasterExposed;

    function setUp() public override {
        super.setUp();

        // Replace with exposed version for testing
        paymasterExposed = new PaymasterExposed(intentExecutor);
        vm.label(address(paymasterExposed), "PaymasterExposed");
    }

    /* //////////////////////////////////////////////////////////////
                    NATIVE TOKEN INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleGasRefund_Native_ExactAmount_ZerosBalance() public {
        uint256 depositAmount = 10 ether;
        uint256 refundAmount = 10 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        // Verify deposit was recorded
        assertEq(paymasterExposed.exposed_nativeAmounts(user), depositAmount, "Deposit not recorded");

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 userBalanceBefore = user.balance;

        // Intent executor settles the gas refund
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // INVARIANT: nativeAmounts[user] must be 0 after settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero after settlement");

        // Verify recipient received the refund amount
        assertEq(recipient.balance, recipientBalanceBefore + refundAmount, "Recipient didn't receive refund");

        // Verify user's ETH balance unchanged (no refund to user since exact amount)
        assertEq(user.balance, userBalanceBefore, "User balance changed unexpectedly");
    }

    function test_settleGasRefund_Native_PartialAmount_ZerosBalance() public {
        uint256 depositAmount = 10 ether;
        uint256 refundAmount = 6 ether;
        uint256 expectedUserRefund = 4 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 userBalanceBefore = user.balance;

        // Intent executor settles partial gas refund
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // INVARIANT: nativeAmounts[user] must be 0 after settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero after settlement");

        // Verify recipient received the refund amount
        assertEq(recipient.balance, recipientBalanceBefore + refundAmount, "Recipient didn't receive refund");

        // Verify user received the remaining balance
        assertEq(user.balance, userBalanceBefore + expectedUserRefund, "User didn't receive remaining balance");
    }

    function test_settleGasRefund_Native_MultipleDeposits_ZerosBalance() public {
        uint256 deposit1 = 5 ether;
        uint256 deposit2 = 3 ether;
        uint256 deposit3 = 2 ether;
        uint256 totalDeposit = deposit1 + deposit2 + deposit3;
        uint256 refundAmount = 7 ether;
        uint256 expectedUserRefund = 3 ether;

        // User makes multiple deposits
        vm.startPrank(user);
        (bool success1,) = address(paymasterExposed).call{ value: deposit1 }("");
        require(success1, "Deposit 1 failed");

        (bool success2,) = address(paymasterExposed).call{ value: deposit2 }("");
        require(success2, "Deposit 2 failed");

        (bool success3,) = address(paymasterExposed).call{ value: deposit3 }("");
        require(success3, "Deposit 3 failed");
        vm.stopPrank();

        // Verify total deposit
        assertEq(paymasterExposed.exposed_nativeAmounts(user), totalDeposit, "Total deposit incorrect");

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 userBalanceBefore = user.balance;

        // Intent executor settles gas refund
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // INVARIANT: nativeAmounts[user] must be 0 after settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero after settlement");

        // Verify balances
        assertEq(recipient.balance, recipientBalanceBefore + refundAmount, "Recipient didn't receive refund");
        assertEq(user.balance, userBalanceBefore + expectedUserRefund, "User didn't receive remaining balance");
    }

    function test_settleGasRefund_Native_ZeroAmount_NoChange() public {
        uint256 depositAmount = 10 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 userBalanceBefore = user.balance;

        // Intent executor settles with 0 amount (should return early)
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, 0, recipient);

        // Balance should remain unchanged when amount is 0
        assertEq(paymasterExposed.exposed_nativeAmounts(user), depositAmount, "Balance should remain unchanged");
        assertEq(recipient.balance, recipientBalanceBefore, "Recipient balance changed");
        assertEq(user.balance, userBalanceBefore, "User balance changed");
    }

    function test_settleGasRefund_Native_InsufficientBalance_Reverts() public {
        uint256 depositAmount = 5 ether;
        uint256 refundAmount = 10 ether; // More than deposited

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        // Attempt to settle more than available should revert
        vm.prank(intentExecutor);
        vm.expectRevert(Paymaster.InsufficientETHDeposit.selector);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // Verify balance is still intact after revert
        assertEq(paymasterExposed.exposed_nativeAmounts(user), depositAmount, "Balance changed after revert");
    }

    function test_settleGasRefund_Native_NoDeposit_Reverts() public {
        uint256 refundAmount = 1 ether;

        // User has no deposit, attempt to settle should revert
        vm.prank(intentExecutor);
        vm.expectRevert(Paymaster.InsufficientETHDeposit.selector);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);
    }

    function test_settleGasRefund_Native_MultipleSettlements_Reverts() public {
        uint256 depositAmount = 10 ether;
        uint256 firstRefund = 6 ether;
        uint256 secondRefund = 1 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        // First settlement
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, firstRefund, recipient);

        // INVARIANT: nativeAmounts[user] must be 0 after first settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero after first settlement");

        // Second settlement attempt should revert (no balance left)
        vm.prank(intentExecutor);
        vm.expectRevert(Paymaster.InsufficientETHDeposit.selector);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, secondRefund, recipient);
    }

    /* //////////////////////////////////////////////////////////////
                    ERC20 TOKEN SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleGasRefund_ERC20_DoesNotAffectNativeBalance() public {
        uint256 nativeDeposit = 10 ether;
        uint256 erc20RefundAmount = 5 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: nativeDeposit }("");
        require(success, "Deposit failed");

        // Approve ERC20 tokens for paymaster
        vm.prank(user);
        token1.approve(address(paymasterExposed), erc20RefundAmount);

        uint256 recipientTokenBalanceBefore = token1.balanceOf(recipient);

        // Intent executor settles with ERC20 (should not affect native balance)
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, address(token1), erc20RefundAmount, recipient);

        // Native balance should remain unchanged
        assertEq(paymasterExposed.exposed_nativeAmounts(user), nativeDeposit, "Native balance affected by ERC20 settlement");

        // Verify ERC20 transfer occurred
        assertEq(token1.balanceOf(recipient), recipientTokenBalanceBefore + erc20RefundAmount, "ERC20 transfer failed");
    }

    function test_settleGasRefund_ERC20_ZeroAmount_NoTransfer() public {
        // Approve tokens
        vm.prank(user);
        token1.approve(address(paymasterExposed), 100 ether);

        uint256 recipientTokenBalanceBefore = token1.balanceOf(recipient);

        // Settle with 0 amount (should return early)
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, address(token1), 0, recipient);

        // No transfer should occur
        assertEq(token1.balanceOf(recipient), recipientTokenBalanceBefore, "Token transfer occurred with 0 amount");
    }

    /* //////////////////////////////////////////////////////////////
                        AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleGasRefund_Unauthorized_Reverts() public {
        address unauthorized = makeAddr("unauthorized");
        uint256 depositAmount = 10 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        // Unauthorized caller attempts to settle
        vm.prank(unauthorized);
        vm.expectRevert(Paymaster.Unauthorized.selector);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, 1 ether, recipient);
    }

    /* //////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_settleGasRefund_Native_AlwaysZerosBalance(uint256 depositAmount, uint256 refundAmount) public {
        // Bound amounts to reasonable values
        depositAmount = bound(depositAmount, 1 ether, 50 ether);
        refundAmount = bound(refundAmount, 1 wei, depositAmount); // Refund must be <= deposit

        // Fund user if needed
        vm.deal(user, depositAmount);

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        // Intent executor settles gas refund
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // INVARIANT: nativeAmounts[user] must ALWAYS be 0 after settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero after settlement (fuzz)");
    }

    function testFuzz_settleGasRefund_Native_CorrectRefunds(uint256 depositAmount, uint256 refundAmount) public {
        // Bound amounts to reasonable values
        depositAmount = bound(depositAmount, 1 ether, 50 ether);
        refundAmount = bound(refundAmount, 1 wei, depositAmount);

        // Fund user if needed
        vm.deal(user, depositAmount);

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 userBalanceBefore = user.balance;
        uint256 expectedUserRefund = depositAmount - refundAmount;

        // Intent executor settles gas refund
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);

        // INVARIANT: nativeAmounts[user] must be 0
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero (fuzz)");

        // Verify correct refund to recipient
        assertEq(recipient.balance, recipientBalanceBefore + refundAmount, "Incorrect refund to recipient (fuzz)");

        // Verify correct refund to user (remaining balance)
        assertEq(user.balance, userBalanceBefore + expectedUserRefund, "Incorrect refund to user (fuzz)");
    }

    function testFuzz_settleGasRefund_Native_InsufficientBalance_Reverts(uint256 depositAmount, uint256 refundAmount) public {
        // Deposit less than refund
        depositAmount = bound(depositAmount, 0, 50 ether);
        refundAmount = bound(refundAmount, depositAmount + 1, 100 ether);

        // Fund user if needed
        if (depositAmount > 0) {
            vm.deal(user, depositAmount);

            // User deposits native tokens
            vm.prank(user);
            (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
            require(success, "Deposit failed");
        }

        // Attempt to settle more than available should revert
        vm.prank(intentExecutor);
        vm.expectRevert(Paymaster.InsufficientETHDeposit.selector);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, recipient);
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleGasRefund_Native_DifferentUsers_IndependentBalances() public {
        address user2 = makeAddr("user2");
        vm.deal(user2, 100 ether);

        uint256 user1Deposit = 10 ether;
        uint256 user2Deposit = 5 ether;

        // Both users deposit
        vm.prank(user);
        (bool success1,) = address(paymasterExposed).call{ value: user1Deposit }("");
        require(success1, "User1 deposit failed");

        vm.prank(user2);
        (bool success2,) = address(paymasterExposed).call{ value: user2Deposit }("");
        require(success2, "User2 deposit failed");

        // Settle for user1
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, user1Deposit, recipient);

        // INVARIANT: user1's balance must be 0
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: user1 balance not zero");

        // user2's balance should remain unchanged
        assertEq(paymasterExposed.exposed_nativeAmounts(user2), user2Deposit, "User2 balance affected by user1 settlement");
    }

    function test_settleGasRefund_Native_RecipientIsSender_ZerosBalance() public {
        uint256 depositAmount = 10 ether;
        uint256 refundAmount = 6 ether;

        // User deposits native tokens
        vm.prank(user);
        (bool success,) = address(paymasterExposed).call{ value: depositAmount }("");
        require(success, "Deposit failed");

        uint256 userBalanceBefore = user.balance;

        // Settle with user as recipient
        vm.prank(intentExecutor);
        paymasterExposed.settleGasRefund(user, Constants.NATIVE_TOKEN, refundAmount, user);

        // INVARIANT: nativeAmounts[user] must be 0 after settlement
        assertEq(paymasterExposed.exposed_nativeAmounts(user), 0, "INVARIANT VIOLATED: nativeAmounts not zero");

        // User should receive both the refund and remaining balance
        uint256 expectedTotal = refundAmount + (depositAmount - refundAmount);
        assertEq(user.balance, userBalanceBefore + expectedTotal, "User didn't receive correct total");
    }
}
