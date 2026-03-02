// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV0 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV0.sol";

// Test
import { BaseTest } from "./Base.t.sol";

contract RhinestoneRelayerV0_constructor_Test is BaseTest {
    error InvalidConstructorArg();

    function test_constructor_RevertsWhen_OwnerIsZero() public {
        address routerV0 = address(0x123);
        address routerV1 = address(0x456);
        address owner = address(0);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV0(routerV0, routerV1, owner);
    }

    function test_constructor_RevertsWhen_RouterV0IsZero() public {
        address routerV0 = address(0);
        address routerV1 = address(0x456);
        address owner = address(0x789);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV0(routerV0, routerV1, owner);
    }

    function test_constructor_RevertsWhen_RouterV1IsZero() public {
        address routerV0 = address(0x123);
        address routerV1 = address(0);
        address owner = address(0x789);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV0(routerV0, routerV1, owner);
    }

    function test_constructor_RevertsWhen_AllAreZero() public {
        address routerV0 = address(0);
        address routerV1 = address(0);
        address owner = address(0);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV0(routerV0, routerV1, owner);
    }

    function test_constructor_RevertsWhen_RoutersAreZero() public {
        address routerV0 = address(0);
        address routerV1 = address(0);
        address owner = address(0x789);

        vm.expectRevert(InvalidConstructorArg.selector);
        new RhinestoneRelayerV0(routerV0, routerV1, owner);
    }

    function test_constructor_Success() public {
        address routerV0 = address(0x123);
        address routerV1 = address(0x456);
        address owner = address(0x789);

        RhinestoneRelayerV0 relayer = new RhinestoneRelayerV0(routerV0, routerV1, owner);

        assertEq(relayer.RHINESTONE_V0(), routerV0);
        assertEq(relayer.RHINESTONE_ROUTER(), routerV1);
        assertEq(relayer.owner(), owner);
    }
}
