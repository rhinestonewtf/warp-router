// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";

// Mocks
import { MockTheCompact } from "test/utils/mocks/MockTheCompact.sol";

contract RSAllocator_Constructor_Unit_Test is Test {
    MockTheCompact public mockCompact;

    function setUp() public {
        mockCompact = new MockTheCompact();
    }

    function test_constructor_Succeeds() public {
        address owner = makeAddr("owner");
        address signer = makeAddr("signer");

        RSAllocator allocator = new RSAllocator(address(mockCompact), owner, signer);

        assertEq(allocator.signer(), signer);
        assertEq(allocator.owner(), owner);
        assertTrue(allocator.ALLOCATOR_ID() > 0);
    }

    function test_constructor_RevertsWhen_SignerIsZero() public {
        address owner = makeAddr("owner");

        vm.expectRevert(RSAllocator.InvalidConstructor.selector);
        new RSAllocator(address(mockCompact), owner, address(0));
    }

    function test_constructor_SequentialAllocatorIds() public {
        address owner = makeAddr("owner");
        address signer = makeAddr("signer");

        RSAllocator a1 = new RSAllocator(address(mockCompact), owner, signer);
        RSAllocator a2 = new RSAllocator(address(mockCompact), owner, signer);

        assertEq(a1.ALLOCATOR_ID(), a2.ALLOCATOR_ID() - 1);
    }
}
