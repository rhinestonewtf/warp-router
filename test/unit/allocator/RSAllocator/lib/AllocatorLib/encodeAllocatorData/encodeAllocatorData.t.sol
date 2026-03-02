// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { AllocatorLib_Unit_Test } from "test/unit/allocator/RSAllocator/lib/AllocatorLib/AllocatorLib.t.sol";

// Libraries
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";

contract AllocatorLib_EncodeAllocatorData_Unit_Test is AllocatorLib_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_encodeAllocatorData_BasicEncoding() public view {
        // Test basic encoding with typical signature and qualification hash
        bytes memory signature =
            hex"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b"; //65
        // bytes (r,s,v)
        bytes32 qualificationHash = keccak256("test_qualification");

        bytes memory result = this.encodeAllocatorData(signature, qualificationHash);

        // Expected result should be qualificationHash (32 bytes) + signature (65 bytes)
        bytes memory expected = abi.encodePacked(qualificationHash, signature);

        assertEq(result, expected, "Should properly concatenate qualification hash and signature");
        assertEq(result.length, 32 + signature.length, "Result should be 32 bytes + signature length");

        // Verify the qualification hash is at the beginning
        bytes32 extractedHash;
        assembly {
            extractedHash := mload(add(result, 0x20))
        }
        assertEq(extractedHash, qualificationHash, "Qualification hash should be at the beginning");
    }

    function testFuzz_encodeAllocatorData(bytes calldata signature, bytes32 qualificationHash) public view {
        // Fuzz test with random signature and qualification hash
        bytes memory result = this.encodeAllocatorData(signature, qualificationHash);

        // Verify the encoding matches abi.encodePacked
        bytes memory expected = abi.encodePacked(qualificationHash, signature);
        assertEq(result, expected, "Should match abi.encodePacked output");

        // Verify length
        assertEq(result.length, 32 + signature.length, "Length should be 32 bytes plus signature length");

        // Verify we can decode it back
        if (signature.length > 0) {
            // Extract qualification hash (first 32 bytes)
            bytes32 decodedHash;
            assembly {
                decodedHash := mload(add(result, 0x20))
            }
            assertEq(decodedHash, qualificationHash, "Should be able to extract qualification hash");

            // Extract signature (remaining bytes)
            bytes memory decodedSignature = new bytes(signature.length);
            for (uint256 i = 0; i < signature.length; i++) {
                decodedSignature[i] = result[32 + i];
            }
            assertEq(decodedSignature, signature, "Should be able to extract signature");
        }
    }
}
