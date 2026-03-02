// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { Paymaster } from "src/executor/StandaloneIntent/aux/Paymaster.sol";
import { MockERC20 } from "src/tests/MockERC20.sol";
import { Constants } from "src/types/Constants.sol";

contract Paymaster_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    Paymaster internal paymaster;

    MockERC20 internal token1;
    MockERC20 internal token2;

    address internal intentExecutor;
    address internal user;
    address internal recipient;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        intentExecutor = makeAddr("intentExecutor");
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        paymaster = new Paymaster(intentExecutor, address(this));

        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);

        vm.label(address(paymaster), "Paymaster");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(intentExecutor, "IntentExecutor");
        vm.label(user, "User");
        vm.label(recipient, "Recipient");

        // Fund user with tokens
        token1.mint(user, 1000 ether);
        token2.mint(user, 1000 ether);

        // Fund user with native tokens
        vm.deal(user, 100 ether);
        vm.deal(recipient, 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _depositNative(address account, uint256 amount) internal {
        vm.prank(account);
        (bool success,) = address(paymaster).call{ value: amount }("");
        require(success, "Native deposit failed");
    }

    function _approveToken(address account, address token, uint256 amount) internal {
        vm.prank(account);
        MockERC20(token).approve(address(paymaster), amount);
    }

    function _getUserNativeBalance(address account) internal view returns (uint256) {
        // Using a staticcall to read the internal mapping via a helper function
        // Since we can't directly access internal state in tests, we'll use the contract's view functions
        // or track it separately in our tests
        return account.balance;
    }
}
