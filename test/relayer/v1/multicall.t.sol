// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV1 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";
import { MockRouter } from "../mocks/MockRouter.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

// Types
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

contract RhinestoneRelayer_multicall_Test is RhinestoneRelayer_Test {
    error RelayerNotTrusted();

    MockERC20 public token2;
    address public recipient = address(0x9999);

    function setUp() public override {
        super.setUp();

        // Deploy second token
        token2 = new MockERC20("Token 2", "TK2");
        token2.mint(address(relayer), 500e18);
    }

    function test_multicall_singleCall() public {
        Execution[] memory calls = new Execution[](1);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(router.lastSwapAmount(), 100e18);
    }

    function test_multicall_multipleCalls() public {
        Execution[] memory calls = new Execution[](3);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });
        calls[1] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token2), address(token2), 200e18)
        });
        calls[2] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token2), 50e18)
        });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        // Last call should be the final swap recorded
        assertEq(router.lastSwapAmount(), 50e18);
    }

    function test_multicall_withValue() public {
        // Fund relayer with ETH
        vm.deal(address(relayer), 5 ether);

        Execution[] memory calls = new Execution[](2);
        calls[0] =
            Execution({ target: address(router), value: 1 ether, callData: abi.encodeWithSelector(MockRouter.payableFunction.selector) });
        calls[1] =
            Execution({ target: address(router), value: 0.5 ether, callData: abi.encodeWithSelector(MockRouter.payableFunction.selector) });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        // Last call's value should be recorded
        assertEq(router.lastReceivedValue(), 0.5 ether);
        assertEq(address(relayer).balance, 3.5 ether);
    }

    function test_multicall_mixedValueAndNonValue() public {
        vm.deal(address(relayer), 2 ether);

        Execution[] memory calls = new Execution[](3);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });
        calls[1] =
            Execution({ target: address(router), value: 1 ether, callData: abi.encodeWithSelector(MockRouter.payableFunction.selector) });
        calls[2] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token2), address(token2), 200e18)
        });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(address(relayer).balance, 1 ether);
    }

    function test_multicall_emptyArray() public {
        Execution[] memory calls = new Execution[](0);

        // Should not revert with empty array
        vm.prank(relayerEOA);
        relayer.multicall(calls);
    }

    function test_multicall_RevertsWhen_OnlyTrustedRelayer() public {
        Execution[] memory calls = new Execution[](1);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });

        // Owner should not be able to call
        vm.prank(owner);
        vm.expectRevert(RelayerNotTrusted.selector);
        relayer.multicall(calls);

        // Random user should not be able to call
        vm.prank(user);
        vm.expectRevert(RelayerNotTrusted.selector);
        relayer.multicall(calls);
    }

    function test_multicall_RevertsWhen_CallFails() public {
        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });
        calls[1] = Execution({
            target: address(router), value: 0, callData: abi.encodeWithSelector(MockRouter.failWithReason.selector, "Multicall test revert")
        });

        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.multicall(calls);

        // First call should not have executed since the entire multicall reverts
        assertEq(router.lastSwapAmount(), 0);
    }

    function test_multicall_RevertsWhen_FirstCallFails() public {
        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({
            target: address(router), value: 0, callData: abi.encodeWithSelector(MockRouter.failWithReason.selector, "First call fails")
        });
        calls[1] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });

        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.multicall(calls);
    }

    function test_multicall_RevertsWhen_InsufficientValue() public {
        // Fund with only 1 ether
        vm.deal(address(relayer), 1 ether);

        Execution[] memory calls = new Execution[](1);
        calls[0] = Execution({
            target: address(router),
            value: 2 ether, // More than available
            callData: abi.encodeWithSelector(MockRouter.payableFunction.selector)
        });

        vm.prank(relayerEOA);
        vm.expectRevert();
        relayer.multicall(calls);
    }

    function test_multicall_differentTargets() public {
        // Deploy another mock contract
        MockRouter router2 = new MockRouter();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });
        calls[1] = Execution({
            target: address(router2),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token2), address(token2), 200e18)
        });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(router.lastSwapAmount(), 100e18);
        assertEq(router2.lastSwapAmount(), 200e18);
    }

    function test_multicall_toEOA() public {
        vm.deal(address(relayer), 2 ether);

        Execution[] memory calls = new Execution[](1);
        calls[0] = Execution({ target: recipient, value: 1 ether, callData: "" });

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(address(relayer).balance, 1 ether);
    }

    function test_multicall_longBatch() public {
        // Test with 10 calls
        Execution[] memory calls = new Execution[](10);
        for (uint256 i = 0; i < 10; i++) {
            calls[i] = Execution({
                target: address(router),
                value: 0,
                callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), i * 10e18)
            });
        }

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        // Last call should be recorded
        assertEq(router.lastSwapAmount(), 90e18);
    }

    function test_multicall_withMsgValue() public {
        Execution[] memory calls = new Execution[](1);
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18)
        });

        // Send ETH with the multicall transaction
        vm.deal(relayerEOA, 5 ether);
        vm.prank(relayerEOA);
        relayer.multicall{ value: 1 ether }(calls);

        // ETH should remain in relayer contract
        assertEq(address(relayer).balance, 1 ether);
    }

    function test_multicall_complexScenario() public {
        vm.deal(address(relayer), 10 ether);

        // Deploy third mock contract
        MockRouter router2 = new MockRouter();

        Execution[] memory calls = new Execution[](5);

        // 1. Swap tokens
        calls[0] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token2), 100e18)
        });

        // 2. Send ETH to router
        calls[1] =
            Execution({ target: address(router), value: 2 ether, callData: abi.encodeWithSelector(MockRouter.payableFunction.selector) });

        // 3. Another swap
        calls[2] = Execution({
            target: address(router2),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token2), address(token), 50e18)
        });

        // 4. Send ETH to EOA
        calls[3] = Execution({ target: recipient, value: 1 ether, callData: "" });

        // 5. Final swap
        calls[4] = Execution({
            target: address(router),
            value: 0,
            callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 25e18)
        });

        uint256 relayerBalanceBefore = address(relayer).balance;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(address(relayer).balance, relayerBalanceBefore - 3 ether);
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(router.lastSwapAmount(), 25e18);
        assertEq(router2.lastSwapAmount(), 50e18);
    }

    function testFuzz_multicall_variableBatchSize(uint8 batchSize) public {
        vm.assume(batchSize > 0 && batchSize <= 50);

        Execution[] memory calls = new Execution[](batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            calls[i] = Execution({
                target: address(router),
                value: 0,
                callData: abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), i * 1e18)
            });
        }

        vm.prank(relayerEOA);
        relayer.multicall(calls);
    }

    function testFuzz_multicall_variableValue(uint96 value) public {
        vm.assume(value > 0 && value < 100 ether);
        vm.deal(address(relayer), value * 2);

        Execution[] memory calls = new Execution[](1);
        calls[0] =
            Execution({ target: address(router), value: value, callData: abi.encodeWithSelector(MockRouter.payableFunction.selector) });

        vm.prank(relayerEOA);
        relayer.multicall(calls);

        assertEq(router.lastReceivedValue(), value);
    }
}
