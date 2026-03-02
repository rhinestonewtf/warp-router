// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { SameChainAdapter_Unit_Test } from "test/unit/arbiters/SameChainAdapter/SameChainAdapter.t.sol";

// Contracts
import { SameChainAdapter } from "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";

contract SameChainAdapter_Metadata_Unit_Test is SameChainAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface() public view {
        // Test that main functions are supported
        assertTrue(
            sameChainAdapter.supportsInterface(SameChainAdapter.samechain_compact_handleFill.selector),
            "Should support samechain_compact_handleFill"
        );
        assertTrue(
            sameChainAdapter.supportsInterface(SameChainAdapter.samechain_permit2_handleFill.selector),
            "Should support samechain_permit2_handleFill"
        );

        // Test that supportsInterface itself is supported (from base)
        assertTrue(sameChainAdapter.supportsInterface(SameChainAdapter.supportsInterface.selector), "Should support supportsInterface");

        // Test unsupported random selector
        assertFalse(sameChainAdapter.supportsInterface(bytes4(0x12345678)), "Should not support random selector");
    }
}
