// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { SingleCallAdapter_Unit_Test } from "test/unit/arbiters/SingleCallAdapter/SingleCallAdapter.t.sol";

// Contracts
import { SingleCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/SingleCallAdapter.sol";
import { IAdapter } from "@rhinestone/compact-utils/src/interfaces/IAdapter.sol";

// Libraries
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

contract SingleCallAdapter_Metadata_Unit_Test is SingleCallAdapter_Unit_Test {
    using AdapterTagLib for bytes12;

    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface() public view {
        // Test that singleCall_handleFill is supported
        assertTrue(
            singleCallAdapter.supportsInterface(SingleCallAdapter.singleCall_handleFill.selector),
            "Should support singleCall_handleFill"
        );

        // Test that supportsInterface itself is supported (from base)
        assertTrue(
            singleCallAdapter.supportsInterface(SingleCallAdapter.supportsInterface.selector), "Should support supportsInterface"
        );

        // Test IAdapter interface
        assertTrue(singleCallAdapter.supportsInterface(type(IAdapter).interfaceId), "Should support IAdapter interface");

        // Test unsupported random selector
        assertFalse(singleCallAdapter.supportsInterface(bytes4(0x12345678)), "Should not support random selector");
    }

    function test_router() public view {
        assertEq(singleCallAdapter._ROUTER(), router, "Router should be set correctly");
    }

    function test_arbiter() public view {
        // When arbiter is address(0) in constructor, it defaults to address(this)
        assertEq(singleCallAdapter.ARBITER(), address(singleCallAdapter), "Arbiter should default to adapter address");
    }

    function test_adapterTag() public view {
        bytes12 tag = singleCallAdapter.ADAPTER_TAG();

        // Should have skipRelayerContext flag set
        assertTrue(tag.isSkipRelayerContext(), "Should have skipRelayerContext flag set");

        // Should equal DEFAULT_ADAPTER_TAG with skipRelayerContext set
        assertEq(tag, Constants.DEFAULT_ADAPTER_TAG.setSkipRelayerContext(), "Should match expected adapter tag");
    }
}
