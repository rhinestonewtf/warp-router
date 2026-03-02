// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Libraries
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";

// Base
import { Test } from "forge-std/Test.sol";

contract AllocatorLib_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function encodeAllocatorData(bytes calldata data, bytes32 hash) public pure returns (bytes memory) {
        return AllocatorLib.encodeAllocatorData(data, hash);
    }
}
