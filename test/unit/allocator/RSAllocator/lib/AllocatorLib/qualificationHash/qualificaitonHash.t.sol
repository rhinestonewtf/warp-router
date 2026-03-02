// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { AllocatorLib_Unit_Test } from "test/unit/allocator/RSAllocator/lib/AllocatorLib/AllocatorLib.t.sol";

// Libraries
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";

contract AllocatorLib_QualificationHash_Unit_Test is AllocatorLib_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_qualificationHash() public pure {
        bytes32 expectedTypehash = keccak256("QualifiedClaim(bytes32 claimHash,bytes32 qualificationHash)");
        bytes32 claimHash = keccak256("test_claim");
        bytes32 qualHash = keccak256("test_qualification");

        bytes32 result = AllocatorLib.qualificationHash(claimHash, qualHash);
        bytes32 expected = keccak256(abi.encode(expectedTypehash, claimHash, qualHash));

        assertEq(result, expected, "Typehash should match keccak256 of QualifiedClaim string");
    }
}
