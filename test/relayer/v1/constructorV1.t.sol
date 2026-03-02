// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV1 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";

// Test
import { BaseTest } from "./Base.t.sol";

contract RhinestoneRelayerV1_constructor_Test is BaseTest {
    error InvalidConstructorArg();

    function test_constructor_RevertsWhen_OwnerIsZero() public {
        address router = address(0x123);
        address owner = address(0);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV1(router, owner);
    }

    function test_constructor_RevertsWhen_RouterIsZero() public {
        address router = address(0);
        address owner = address(0x456);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV1(router, owner);
    }

    function test_constructor_RevertsWhen_BothAreZero() public {
        address router = address(0);
        address owner = address(0);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV1(router, owner);
    }

    function test_constructor_Success() public {
        address router = address(0x123);
        address owner = address(0x456);

        RhinestoneRelayerV1 relayer = new RhinestoneRelayerV1(router, owner);

        assertEq(relayer.RHINESTONE_ROUTER(), router);
        assertEq(relayer.owner(), owner);
    }
}
