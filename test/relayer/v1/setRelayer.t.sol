// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Test
import { RhinestoneRelayer_Test } from "./RhinestoneRelayer.t.sol";

contract RhinestoneRelayer_setRelayer_Test is RhinestoneRelayer_Test {
    event RelayerSet(address indexed relayer, bool isTrusted);

    function test_setRelayer_add() public {
        address newRelayer = address(0x4);

        vm.expectEmit(true, false, false, true);
        emit RelayerSet(newRelayer, true);

        vm.prank(owner);
        relayer.setRelayer(newRelayer, true);

        assertTrue(relayer.isRelayer(newRelayer));
    }

    function test_setRelayer_remove() public {
        // First verify relayerEOA is trusted
        assertTrue(relayer.isRelayer(relayerEOA));

        vm.expectEmit(true, false, false, true);
        emit RelayerSet(relayerEOA, false);

        vm.prank(owner);
        relayer.setRelayer(relayerEOA, false);

        assertFalse(relayer.isRelayer(relayerEOA));
    }

    function test_setRelayer__RevertsWhen_OnlyOwner() public {
        address newRelayer = address(0x4);

        // Non-owner should not be able to set relayer
        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        relayer.setRelayer(newRelayer, true);

        // Relayer should not be able to set other relayers
        vm.prank(relayerEOA);
        vm.expectRevert(); // Ownable revert
        relayer.setRelayer(newRelayer, true);
    }

    function test_setRelayer_multipleRelayers() public {
        address relayer1 = address(0x4);
        address relayer2 = address(0x5);
        address relayer3 = address(0x6);

        vm.startPrank(owner);

        relayer.setRelayer(relayer1, true);
        relayer.setRelayer(relayer2, true);
        relayer.setRelayer(relayer3, true);

        vm.stopPrank();

        assertTrue(relayer.isRelayer(relayer1));
        assertTrue(relayer.isRelayer(relayer2));
        assertTrue(relayer.isRelayer(relayer3));
        assertTrue(relayer.isRelayer(relayerEOA)); // Original still trusted
    }

    function test_setRelayer_toggleTrust() public {
        address testRelayer = address(0x4);

        vm.startPrank(owner);

        // Add relayer
        relayer.setRelayer(testRelayer, true);
        assertTrue(relayer.isRelayer(testRelayer));

        // Remove relayer
        relayer.setRelayer(testRelayer, false);
        assertFalse(relayer.isRelayer(testRelayer));

        // Add back
        relayer.setRelayer(testRelayer, true);
        assertTrue(relayer.isRelayer(testRelayer));

        vm.stopPrank();
    }
}
