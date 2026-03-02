// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV0 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV0.sol";
import { MockRouter } from "../mocks/MockRouter.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { RhinestoneRelayerV0_Test } from "./RhinestoneRelayerV0.t.sol";

contract RhinestoneRelayerV0_relayV0_Test is RhinestoneRelayerV0_Test {
    function test_relayV0ERC20_success() public {
        // Prepare router call for V0 router
        bytes memory swapCall = abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18);

        // Execute as relayer using relayV0_ERC20_13732236 function
        vm.prank(relayerEOA);
        (bool success,) = address(relayer).call(abi.encodePacked(relayer.relayV0_ERC20_13732236.selector, swapCall));
        assertTrue(success);

        // Verify V0 router was called
        assertEq(routerV0.lastSwapAmount(), 100e18);
    }

    function test_relayV0ERC20_onlyTrustedRelayer() public {
        bytes memory swapCall = abi.encodeWithSelector(MockRouter.swap.selector, address(0), address(0), 0);

        // Should revert when called by non-relayer
        vm.prank(user);
        (bool success, bytes memory data) = address(relayer).call(abi.encodePacked(relayer.relayV0_ERC20_13732236.selector, swapCall));
        assertFalse(success);
        assertEq(bytes4(data), bytes4(keccak256("RelayerNotTrusted()")));
    }

    function test_relayV0ERC20_forwardsRevertReason() public {
        // Prepare a call that will revert
        bytes memory failingCall = abi.encodeWithSelector(MockRouter.failWithReason.selector, "Custom revert reason");

        // Execute and expect revert
        vm.prank(relayerEOA);
        (bool success, bytes memory data) = address(relayer).call(abi.encodePacked(relayer.relayV0_ERC20_13732236.selector, failingCall));
        assertFalse(success);

        // The revert data is ABI encoded Error(string)
        bytes memory expectedRevert = abi.encodeWithSignature("Error(string)", "Custom revert reason");
        assertEq(data, expectedRevert);

        // Or decode it
        if (data.length >= 4) {
            bytes memory stringData = new bytes(data.length - 4);
            for (uint256 i = 0; i < stringData.length; i++) {
                stringData[i] = data[i + 4];
            }
            (string memory reason) = abi.decode(stringData, (string));
            assertEq(reason, "Custom revert reason");
        }
    }

    function test_relayV0ERC20_routesToV0Router() public {
        // Prepare router call
        bytes memory swapCall = abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 200e18);

        // Execute as relayer using relayV0_ERC20_13732236
        vm.prank(relayerEOA);
        (bool success,) = address(relayer).call(abi.encodePacked(relayer.relayV0_ERC20_13732236.selector, swapCall));
        assertTrue(success);

        // Verify V0 router was called with correct amount
        assertEq(routerV0.lastSwapAmount(), 200e18);

        // Verify V1 router was NOT called
        assertEq(routerV1.lastSwapAmount(), 0);
    }

    function test_relayV0ERC20_vs_relayERC20_different_routers() public {
        // First call V0 relay
        bytes memory swapCallV0 = abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 100e18);

        vm.prank(relayerEOA);
        (bool successV0,) = address(relayer).call(abi.encodePacked(relayer.relayV0_ERC20_13732236.selector, swapCallV0));
        assertTrue(successV0);
        assertEq(routerV0.lastSwapAmount(), 100e18);
        assertEq(routerV1.lastSwapAmount(), 0);

        // Then call V1 relay
        bytes memory swapCallV1 = abi.encodeWithSelector(MockRouter.swap.selector, address(token), address(token), 200e18);

        vm.prank(relayerEOA);
        (bool successV1,) = address(relayer).call(abi.encodePacked(relayer.relayERC202076776083.selector, swapCallV1));
        assertTrue(successV1);

        // V0 router should still have 100e18
        assertEq(routerV0.lastSwapAmount(), 100e18);
        // V1 router should now have 200e18
        assertEq(routerV1.lastSwapAmount(), 200e18);
    }
}
