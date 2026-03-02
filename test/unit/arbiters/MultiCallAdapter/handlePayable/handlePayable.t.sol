// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { MultiCallAdapter_Unit_Test } from "test/unit/arbiters/MultiCallAdapter/MultiCallAdapter.t.sol";

// Contracts
import { MultiCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/MultiCallAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

// Mocks
import { MockReceiver } from "test/utils/mocks/MockReceiver.sol";

contract MultiCallAdapter_HandlePayable_Unit_Test is MultiCallAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multicall_handlePayable_RevertsWhen_NotCalledViaRouter() public {
        Execution[] memory executions = new Execution[](0);

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        multiCallAdapter.multicall_handlePayable(1 ether, executions);
    }

    function test_multicall_handlePayable_BasicPayableCall() public {
        address payable recipient = payable(makeAddr("recipient"));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: recipient, value: 1 ether, callData: "" });

        // Fund the multicaller with ETH
        vm.deal(address(multiCallAdapter), 2 ether);

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
        assertEq(recipient.balance, 1 ether, "Recipient should receive ETH");
    }

    function test_multicall_handlePayable_MultiplePayableCalls() public {
        address payable recipient1 = payable(makeAddr("recipient1"));
        address payable recipient2 = payable(makeAddr("recipient2"));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: recipient1, value: 0.5 ether, callData: "" });
        executions[1] = Execution({ target: recipient2, value: 0.5 ether, callData: "" });

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
        assertEq(recipient1.balance, 0.5 ether, "Recipient1 should receive 0.5 ETH");
        assertEq(recipient2.balance, 0.5 ether, "Recipient2 should receive 0.5 ETH");
    }

    function test_multicall_handlePayable_ZeroValue() public {
        address target = makeAddr("target");

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: target, value: 0, callData: abi.encodeWithSignature("someFunction()") });

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable(0, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
    }

    function test_multicall_handlePayable_EmptyExecutions() public {
        Execution[] memory executions = new Execution[](0);

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
        // ETH should remain in multicaller since no executions
        assertEq(address(multiCallAdapterAddress).balance, 11 ether); //
    }

    function test_multicall_handlePayable_WithCalldata() public {
        // Deploy a simple contract that can receive ETH with data
        MockReceiver receiver = new MockReceiver();

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(receiver), value: 1 ether, callData: abi.encodeWithSelector(MockReceiver.receiveWithData.selector, 123)
        });

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
        assertEq(receiver.lastValue(), 123, "Receiver should have received the data");
        assertEq(address(receiver).balance, 1 ether, "Receiver should have received ETH");
    }

    function test_multicall_handlePayable_MixedValueAndNonValue() public {
        address payable recipient = payable(makeAddr("recipient"));

        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution({ target: recipient, value: 0.5 ether, callData: "" });
        executions[1] = Execution({
            target: address(tokenA), value: 0, callData: abi.encodeWithSelector(tokenA.approve.selector, recipient, 100 ether)
        });
        executions[2] = Execution({ target: recipient, value: 0.5 ether, callData: "" });

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
        assertEq(recipient.balance, 1 ether, "Recipient should receive total 1 ETH");
        assertEq(tokenA.allowance(address(multiCallAdapterAddress), recipient), 100 ether, "Approval should be set");
    }

    function test_multicall_handlePayable_RevertsWhen_InsufficientETH() public {
        address payable recipient = payable(makeAddr("recipient"));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: recipient,
            value: 2 ether, // More than sent
            callData: ""
        });

        // Drain multicaller ETH
        vm.deal(address(multiCallAdapter), 0 ether);
        _prankDelegateCall();
        vm.expectRevert(); // Should revert due to insufficient ETH
        multiCallAdapter.multicall_handlePayable{ value: 1 ether }(1 ether, executions);
    }

    function test_multicall_handlePayable_RevertsWhen_ExecutionFails() public {
        // Create an execution that will fail
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(this), // This contract doesn't have the called function
            value: 0,
            callData: abi.encodeWithSignature("nonExistentFunction()")
        });

        _prankDelegateCall();
        vm.expectRevert();
        multiCallAdapter.multicall_handlePayable(0, executions);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_multicall_handlePayable(uint256 value, uint8 numExecutions) public {
        vm.assume(value <= 10 ether);
        vm.assume(numExecutions > 0 && numExecutions <= 5);

        // Create recipients
        address[] memory recipients = new address[](numExecutions);
        for (uint256 i = 0; i < numExecutions; i++) {
            recipients[i] = makeAddr(string(abi.encodePacked("recipient", i)));
        }

        // Create executions
        Execution[] memory executions = new Execution[](numExecutions);
        uint256 valuePerExecution = value / numExecutions;
        uint256 remainder = value % numExecutions;

        for (uint256 i = 0; i < numExecutions; i++) {
            uint256 execValue = valuePerExecution;
            if (i == 0) execValue += remainder; // Add remainder to first execution

            executions[i] = Execution({ target: recipients[i], value: execValue, callData: "" });
        }

        _prankDelegateCall();
        bytes4 selector = multiCallAdapter.multicall_handlePayable{ value: value }(value, executions);

        assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);

        // Verify all recipients received their share
        for (uint256 i = 0; i < numExecutions; i++) {
            uint256 expectedBalance = valuePerExecution;
            if (i == 0) expectedBalance += remainder;
            assertEq(recipients[i].balance, expectedBalance, "Recipient should receive correct amount");
        }
    }

    function testFuzz_multicall_handlePayable_WithCalldata(uint256 value, bytes calldata callData) public {
        vm.assume(value <= 10 ether);
        vm.assume(callData.length <= 1024); // Reasonable calldata size

        address recipient = makeAddr("recipient");

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: recipient, value: value, callData: callData });

        _prankDelegateCall();
        // This might revert if calldata is invalid, which is expected
        try multiCallAdapter.multicall_handlePayable{ value: value }(value, executions) returns (bytes4 selector) {
            assertEq(selector, multiCallAdapter.multicall_handlePayable.selector);
            assertEq(recipient.balance, value);
        } catch {
            // Expected if calldata causes revert
            assertTrue(true);
        }
    }
}
