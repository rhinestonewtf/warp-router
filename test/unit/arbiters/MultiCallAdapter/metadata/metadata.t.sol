// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { MultiCallAdapter_Unit_Test } from "test/unit/arbiters/MultiCallAdapter/MultiCallAdapter.t.sol";

// Contracts
import { MultiCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/MultiCallAdapter.sol";

contract MultiCallAdapter_Metadata_Unit_Test is MultiCallAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface() public view {
        // Test that all main functions are supported
        assertTrue(
            multiCallAdapter.supportsInterface(MultiCallAdapter.multicall_handleFill.selector), "Should support multicall_handleFill"
        );
        assertTrue(
            multiCallAdapter.supportsInterface(MultiCallAdapter.multicall_handleJITClaim.selector),
            "Should support multicall_handleJITClaim"
        );
        assertTrue(
            multiCallAdapter.supportsInterface(MultiCallAdapter.multicall_handlePayable.selector), "Should support multicall_handlePayable"
        );

        // Test that supportsInterface itself is supported (from base)
        assertTrue(multiCallAdapter.supportsInterface(MultiCallAdapter.supportsInterface.selector), "Should support supportsInterface");

        // Test unsupported random selector
        assertFalse(multiCallAdapter.supportsInterface(bytes4(0x12345678)), "Should not support random selector");
    }
}
