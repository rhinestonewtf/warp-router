// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV1 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";
import { MockRouter } from "../mocks/MockRouter.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

contract RhinestoneRelayer_relay_Test is RhinestoneRelayer_Test {
    function test_relayFn_success() public {
        // Prepare router call
        bytes memory swapCall = abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18);

        // Execute as relayer using relayERC202076776083 function
        vm.prank(relayerEOA);
        (bool success,) = address(relayer).call(abi.encodePacked(relayer.relayERC202076776083.selector, swapCall));
        assertTrue(success);

        // Verify router was called
        assertEq(router.lastSwapAmount(), 100e18);
    }

    function test_relayFn_onlyTrustedRelayer() public {
        bytes memory swapCall = abi.encodeWithSelector(MockRouter.swap.selector, address(0), address(0), 0);

        // Should revert when called by non-relayer
        vm.prank(user);
        (bool success, bytes memory data) = address(relayer).call(abi.encodePacked(relayer.relayERC202076776083.selector, swapCall));
        assertFalse(success);
        assertEq(bytes4(data), bytes4(keccak256("RelayerNotTrusted()")));
    }

    function test_relayFn_forwardsRevertReason() public {
        // Prepare a call that will revert
        bytes memory failingCall = abi.encodeWithSelector(MockRouter.failWithReason.selector, "Custom revert reason");

        // Execute and expect revert
        vm.prank(relayerEOA);
        (bool success, bytes memory data) = address(relayer).call(abi.encodePacked(relayer.relayERC202076776083.selector, failingCall));
        assertFalse(success);

        // The revert data is ABI encoded Error(string)
        // We can either:
        // 1. Check the raw bytes
        bytes memory expectedRevert = abi.encodeWithSignature("Error(string)", "Custom revert reason");
        assertEq(data, expectedRevert);

        // 2. Or decode it
        // Skip the Error selector (4 bytes) and decode the string
        if (data.length >= 4) {
            bytes memory stringData = new bytes(data.length - 4);
            for (uint256 i = 0; i < stringData.length; i++) {
                stringData[i] = data[i + 4];
            }
            (string memory reason) = abi.decode(stringData, (string));
            assertEq(reason, "Custom revert reason");
        }
    }

    function test_relayFn_forwardsValue() public {
        // Fund relayer contract with ETH
        vm.deal(address(relayer), 1 ether);

        // Prepare call that expects ETH - using relayETH7172445 which supports sending ETH
        bytes memory payableCall = abi.encodeWithSelector(MockRouter.payableFunction.selector);

        // relayETH7172445 expects: [selector(4)][callvalue(12)][calldata]
        // callvalue is encoded in 12 bytes after selector
        bytes memory fullCall = abi.encodePacked(relayer.relayETH7172445.selector, bytes12(uint96(0.5 ether)), payableCall);

        // Execute as relayer
        vm.prank(relayerEOA);
        (bool success,) = address(relayer).call(fullCall);
        assertTrue(success);

        // Verify router received ETH
        assertEq(router.lastReceivedValue(), 0.5 ether);
    }

    // function testFuzz_relayFn_arbitraryCalldata(bytes calldata data) public {
    // vm.assume(data.length >= 4); // Need at least a selector
    //
    // bytes memory fullCall = abi.encodePacked(data);
    //
    // // Expect the router to be called with the exact data (minus relay selector)
    // vm.expectCall(address(router), data);
    //
    // vm.prank(relayerEOA);
    // (bool success,) = address(relayer).call(fullCall);
    // success;
    //
    // // Success depends on whether router has the function
    // // But we've verified the call was forwarded correctly
    //}
}
