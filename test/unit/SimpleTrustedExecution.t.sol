// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IntentExecutor } from "../../src/executor/IntentExecutor.sol";
import { TrustedExecution } from "../../src/executor/TrustedExecution/TrustedExecution.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { MockERC20 as Token } from "../../src/tests/MockERC20.sol";
import { TheCompact } from "the-compact/TheCompact.sol";
import { Router } from "../../src/router/Router.sol";
import { AddressBook } from "../../src/common/AddressBook/AddressBook.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { Constants } from "../../src/types/Constants.sol";
import { MockPermit2 } from "./MockPermit2.sol";
import { MockSmartAccount } from "./MockSmartAccount.sol";
import { TestAllocator } from "../../src/tests/DebugAllocator.sol";
import { TestHelperLib } from "src/tests/Environment.sol";
import { Paymaster } from "../../src/executor/StandaloneIntent/aux/Paymaster.sol";

contract SimpleTrustedExecutionTest is Test {
    using TestHelperLib for Execution[];

    IntentExecutor executor;
    Token token;
    TheCompact compact;
    Router router;
    AddressBook addressBook;
    TestAllocator allocator;
    MockSmartAccount smartAccount;

    address user = makeAddr("user");
    address arbiter = makeAddr("arbiter");

    function setUp() public {
        // Deploy a mock Permit2 contract at the expected address
        MockPermit2 mockPermit2 = new MockPermit2();
        bytes memory permit2Code = address(mockPermit2).code;
        vm.etch(address(Constants.PERMIT2), permit2Code);

        // Deploy basic contracts without circular dependencies
        token = new Token("Test Token", "TEST", 18);
        compact = new TheCompact();
        router = new Router(arbiter, address(this), address(this));
        addressBook = new AddressBook(address(this));
        smartAccount = new MockSmartAccount();

        // Pre-populate AddressBook with dummy addresses for the adapters that TrustedExecution expects
        addressBook.setAddress(Constants.SAMECHAIN_ARBITER_ID, address(0x1234));

        // Create allocator
        allocator = new TestAllocator(address(compact), arbiter, arbiter);

        // Deploy Paymaster and register in AddressBook for StandaloneIntentExecutor
        address predictedIntentExecutor = address(0x5678); // Placeholder
        Paymaster paymaster = new Paymaster(predictedIntentExecutor, address(this));
        addressBook.setAddress(Constants.PAYMASTER_ID, address(paymaster));

        // Try to deploy IntentExecutor with better error handling
        try new IntentExecutor(address(router), address(compact), address(allocator), address(addressBook), address(0x2345)) returns (
            IntentExecutor _executor
        ) {
            executor = _executor;
        } catch Error(string memory reason) {
            console.log("IntentExecutor deployment failed with reason:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("IntentExecutor deployment failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Low-level deployment error");
        }

        // Label addresses for better trace output
        vm.label(address(executor), "IntentExecutor");
        vm.label(address(token), "TestToken");
        vm.label(user, "User");
        vm.label(arbiter, "Arbiter");
    }

    function test_deploymentSuccess() public {
        // Test that all contracts deployed successfully
        assertTrue(address(token) != address(0));
        assertTrue(address(compact) != address(0));
        assertTrue(address(router) != address(0));
        assertTrue(address(addressBook) != address(0));
        assertTrue(address(executor) != address(0));
    }

    function test_executeWithoutSignature_WhitelistedArbiter() public {
        // Setup: Register arbiter in AddressBook to make it the SAMECHAIN_ARBITER
        addressBook.setAddress(Constants.SAMECHAIN_ARBITER_ID, arbiter);

        // Deploy Paymaster for new executor
        Paymaster paymaster = new Paymaster(address(0x9999), address(this)); // Placeholder
        addressBook.setAddress(Constants.PAYMASTER_ID, address(paymaster));

        // Deploy a new executor that will recognize the arbiter
        executor = new IntentExecutor(address(router), address(compact), address(allocator), address(addressBook), address(0));

        // Create a simple execution
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(token), value: 0, callData: abi.encodeCall(token.mint, (user, 1000 ether)) });

        // Execute as whitelisted arbiter
        vm.prank(arbiter);
        executor.executeOpsWithoutSignature(address(smartAccount), executions.toOperation(0));

        // Verify execution succeeded
        assertEq(token.balanceOf(user), 1000 ether);
    }

    function test_executeWithoutSignature_UnauthorizedArbiter() public {
        // Create a simple execution
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(token), value: 0, callData: abi.encodeCall(token.mint, (user, 1000 ether)) });

        // Try to execute as non-whitelisted arbiter - should revert with InvalidPermission
        vm.prank(arbiter);
        vm.expectRevert(); // The specific error is from SkipSignatureCheckLib.InvalidPermission
        executor.executeOpsWithoutSignature(address(smartAccount), executions.toOperation(0));
    }

    function test_batchExecuteWithoutSignature() public {
        // Setup: Register arbiter in AddressBook
        addressBook.setAddress(Constants.SAMECHAIN_ARBITER_ID, arbiter);

        // Deploy Paymaster for new executor
        Paymaster paymaster = new Paymaster(address(0xAAAA), address(this)); // Placeholder
        addressBook.setAddress(Constants.PAYMASTER_ID, address(paymaster));

        // Deploy a new executor that will recognize the arbiter
        executor = new IntentExecutor(address(router), address(compact), address(allocator), address(addressBook), address(0));

        // Create multiple executions
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(token), value: 0, callData: abi.encodeCall(token.mint, (user, 500 ether)) });
        executions[1] = Execution({ target: address(token), value: 0, callData: abi.encodeCall(token.mint, (user, 300 ether)) });

        // Execute batch as whitelisted arbiter
        vm.prank(arbiter);
        executor.executeOpsWithoutSignature(address(smartAccount), executions.toOperation(0));

        // Verify both executions succeeded
        assertEq(token.balanceOf(user), 800 ether);
    }

    function test_addressBook_OnlyOwner() public {
        // Only the address book owner should be able to set addresses
        vm.prank(user);
        vm.expectRevert();
        addressBook.setAddress(Constants.SAMECHAIN_ARBITER_ID, arbiter);
    }
}
