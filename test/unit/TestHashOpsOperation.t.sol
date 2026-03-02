// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { SmartExecutionLib } from "../../src/common/SmartExecutionLib.sol";
import { EIP712TypeHashLib } from "../../src/types/EIP712TypeHashLib.sol";
import { Types } from "../../src/types/OrderTypes.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Hasher } from "../../src/tests/Hasher.sol";
import { Constants } from "../../src/types/Constants.sol";
import { TestHelperLib } from "../../src/tests/Environment.sol";

contract TestHashOpsOperation is Test {
    using TestHelperLib for Execution[];

    bytes32 public constant TYPEHASH_OP = EIP712TypeHashLib.TYPEHASH_OP;
    bytes32 public constant TYPEHASH_OPS = EIP712TypeHashLib.TYPEHASH_OPS;

    Hasher public hasher;

    function setUp() public {
        hasher = new Hasher();
    }

    function test_hashOps_NO_OPS() public {
        // Test that empty operation returns NO_OPS
        bytes32 vt = bytes32(0);
        bytes32 noOps = EIP712TypeHashLib.hashOps(vt, Constants.NO_EXEC);
        assertEq(noOps, Constants.NO_OPS, "hashOps(0, NO_EXEC) should equal NO_OPS");

        // Empty operation data should also return NO_OPS
        noOps = hasher.hashOps(Types.Operation(""));
        assertEq(noOps, Constants.NO_OPS, "Empty operation should return NO_OPS");
    }

    function test_hashOps_emptyArray() public {
        // When toOperation receives empty executions, it returns an empty operation
        // Empty operations hash to NO_OPS
        Execution[] memory execs = new Execution[](0);
        Types.Operation memory ops = execs.toOperation();

        bytes32 actual = this.callHashOps(ops);

        // Empty operation should return NO_OPS
        assertEq(actual, Constants.NO_OPS, "Empty executions should produce NO_OPS");
    }

    function test_hashOps_twoExecutions() public {
        // Create operations with 2 executions using Environment helper
        Execution[] memory execs = new Execution[](2);
        execs[0] = Execution(address(0x123), 0, hex"aabbcc");
        execs[1] = Execution(address(0x456), 100, hex"ddeeff");

        Types.Operation memory ops = execs.toOperation();

        // Expected: hash of Op { vt: 0x0203, ops: [exec1, exec2] }
        // Type.ERC7579 = 2, SigMode.ERC1271_EMISSARY = 3
        bytes32 vt = bytes32(uint256(0x0203) << 240); // Left-align 2 bytes in bytes32

        // Hash each operation
        bytes32[] memory opsHashes = new bytes32[](2);
        opsHashes[0] = keccak256(abi.encode(TYPEHASH_OPS, execs[0].target, execs[0].value, keccak256(execs[0].callData)));
        opsHashes[1] = keccak256(abi.encode(TYPEHASH_OPS, execs[1].target, execs[1].value, keccak256(execs[1].callData)));

        bytes32 opsArrayHash = keccak256(abi.encodePacked(opsHashes));
        bytes32 expected = keccak256(abi.encode(TYPEHASH_OP, vt, opsArrayHash));

        bytes32 actual = this.callHashOps(ops);

        console.log("Expected:");
        console.logBytes32(expected);
        console.log("Actual:");
        console.logBytes32(actual);

        assertEq(actual, expected, "Two executions hash mismatch");
    }

    function callHashOps(Types.Operation calldata ops) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOps(ops);
    }
}
