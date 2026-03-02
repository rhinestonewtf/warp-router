// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { Types } from "src/types/OrderTypes.sol";
import { SmartExecutionLib } from "src/common/SmartExecutionLib.sol";
import { Constants } from "src/types/Constants.sol";
import { Hasher } from "src/tests/Hasher.sol";
import { EIP712TypeHashLib } from "src/types/EIP712TypeHashLib.sol";

/**
 * @title Eip712HashValidationTest
 * @notice Tests for Eip712Hash type validation
 * @dev Eip712Hash type must be exactly 34 bytes (2 byte vt + 32 byte hash).
 *      Any other length reverts to prevent malformed input.
 */
contract Eip712HashValidationTest is Test {
    Hasher hasher;

    function setUp() public {
        hasher = new Hasher();
    }

    /**
     * @notice Tests that Eip712Hash type with non-34 byte length reverts (too short)
     * @dev Eip712Hash must be exactly 34 bytes (2 vt + 32 hash)
     */
    function test_Eip712Hash_Type_TooShort_Reverts() public {
        Types.Operation memory ops = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash), // type = 0
                uint8(SmartExecutionLib.SigMode.EMISSARY), // sig mode = 0
                hex"deadbeefdeadbeef" // 8 bytes of data (total 10, not 34)
            )
        });

        vm.expectRevert(EIP712TypeHashLib.InvalidEip712HashLength.selector);
        hasher.hashOps(ops);
    }

    /**
     * @notice Tests that Eip712Hash type with more than 34 bytes reverts
     */
    function test_Eip712Hash_Type_TooLong_Reverts() public {
        Types.Operation memory ops = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash), // type = 0
                uint8(SmartExecutionLib.SigMode.EMISSARY), // sig mode = 0
                bytes32(keccak256("hash1")), // 32 bytes
                hex"deadbeef" // extra bytes making it > 34
            )
        });

        vm.expectRevert(EIP712TypeHashLib.InvalidEip712HashLength.selector);
        hasher.hashOps(ops);
    }

    /**
     * @notice Tests that Eip712Hash with exactly 34 bytes uses the provided hash
     */
    function test_Eip712Hash_Exactly34Bytes_UsesProvidedHash() public view {
        bytes32 providedHash = keccak256("test hash");

        Types.Operation memory ops = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash),
                uint8(SmartExecutionLib.SigMode.EMISSARY),
                providedHash // 32 bytes, total = 34
            )
        });

        bytes32 resultHash = hasher.hashOps(ops);

        // The result should NOT be NO_OPS (since we have data)
        assertNotEq(resultHash, Constants.NO_OPS, "Should not be NO_OPS constant");

        // The hash should incorporate the provided hash (wrapped in Op struct)
        assertTrue(resultHash != bytes32(0), "Hash should not be zero");
    }

    /**
     * @notice Tests that different provided hashes produce different results
     */
    function test_Eip712Hash_DifferentHashes_DifferentResults() public view {
        bytes32 hash1 = keccak256("hash1");
        bytes32 hash2 = keccak256("hash2");

        Types.Operation memory ops1 = Types.Operation({
            data: abi.encodePacked(uint8(SmartExecutionLib.Type.Eip712Hash), uint8(SmartExecutionLib.SigMode.EMISSARY), hash1)
        });

        Types.Operation memory ops2 = Types.Operation({
            data: abi.encodePacked(uint8(SmartExecutionLib.Type.Eip712Hash), uint8(SmartExecutionLib.SigMode.EMISSARY), hash2)
        });

        bytes32 result1 = hasher.hashOps(ops1);
        bytes32 result2 = hasher.hashOps(ops2);

        assertNotEq(result1, result2, "Different provided hashes should produce different results");
    }

    /**
     * @notice Tests that changing sig mode byte changes the hash
     */
    function test_Eip712Hash_DifferentSigMode_DifferentHash() public view {
        bytes32 providedHash = keccak256("test");

        Types.Operation memory ops1 = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash),
                uint8(SmartExecutionLib.SigMode.EMISSARY), // sig mode = 0
                providedHash
            )
        });

        Types.Operation memory ops2 = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash),
                uint8(SmartExecutionLib.SigMode.ERC1271), // sig mode = 1
                providedHash
            )
        });

        bytes32 hash1 = hasher.hashOps(ops1);
        bytes32 hash2 = hasher.hashOps(ops2);

        assertNotEq(hash1, hash2, "Different sig mode should produce different hashes");
    }

    /**
     * @notice Tests that empty operation returns NO_OPS
     */
    function test_EmptyOps_ReturnsNoOps() public view {
        Types.Operation memory emptyOps = Types.Operation({ data: "" });
        bytes32 hash = hasher.hashOps(emptyOps);
        assertEq(hash, Constants.NO_OPS, "Empty operation should return NO_OPS");
    }

    /**
     * @notice Tests that empty ops vs Eip712Hash with data produce different hashes
     * @dev This ensures an attacker cannot substitute empty ops with a crafted Eip712Hash
     */
    function test_EmptyOps_vs_Eip712Hash_DifferentHash() public view {
        Types.Operation memory emptyOps = Types.Operation({ data: "" });

        Types.Operation memory eip712Ops = Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Eip712Hash), uint8(SmartExecutionLib.SigMode.EMISSARY), bytes32(keccak256("attacker hash"))
            )
        });

        bytes32 emptyHash = hasher.hashOps(emptyOps);
        bytes32 eip712Hash = hasher.hashOps(eip712Ops);

        assertNotEq(emptyHash, eip712Hash, "Empty ops and Eip712Hash MUST have different hashes");
    }
}
