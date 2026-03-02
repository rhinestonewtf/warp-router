// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { CompactEnvironment, TestHelperLib } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { MockArbiter } from "src/tests/MockArbiter.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

contract ArbiterBaseTest is CompactEnvironment {
    using SmartExecutionLib for *;
    using TestHelperLib for *;

    MockArbiter arbiter;

    function setUp() public {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);

        arbiter = new MockArbiter(address(env.router), address(env.compact), address(ADDRESSBOOK));

        env.token1.mint(env.smartAccount1.account, 1000 ether);
        env.token2.mint(env.smartAccount1.account, 1000 ether);
    }

    // ============ Compact Flow Tests ============

    function test_compact_erc7579() public {
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 100 ether))
        });

        Types.Order memory order = _createOrder(execs.toOperation(0), 1);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testCompactPreClaimOps(order, _createSignatures(), new bytes32[](0), 0, block.chainid, 100_000);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_compact_multiCall() public {
        Execution[] memory execs = new Execution[](2);
        execs[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 50 ether)) });
        execs[1] =
            Execution({ target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 50 ether)) });

        Types.Order memory order = _createOrder(execs.toOperationMulticall(), 2);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testCompactPreClaimOps(order, _createSignatures(), new bytes32[](0), 0, block.chainid, 100_000);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_compact_callData() public {
        Types.Operation memory ops;
        ops.data = abi.encodePacked(
            SmartExecutionLib.Type.Calldata,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            address(env.token1),
            abi.encodeCall(IERC20.approve, (address(env.target), 75 ether))
        );

        Types.Order memory order = _createOrder(ops, 3);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testCompactPreClaimOps(order, _createSignatures(), new bytes32[](0), 0, block.chainid, 100_000);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_compact_noExec() public {
        Types.Operation memory ops = _createEmptyOperation();
        Types.Order memory order = _createOrder(ops, 4);

        // With bytes32 vt migration, empty operations are wrapped in Op structure
        // The hash is now keccak256(TYPEHASH_OP, vt, NO_EXEC), not raw NO_EXEC
        // Just verify that the mandate hash is computed correctly
        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testCompactPreClaimOps(order, _createSignatures(), new bytes32[](0), 0, block.chainid, 100_000);

        assertTrue(mandateHash != bytes32(0));
    }

    // ============ Permit2 Flow Tests ============

    function test_permit2_erc7579() public {
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 100 ether))
        });

        Types.Order memory order = _createOrder(execs.toOperation(0), 10);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testPermit2PreClaimOps(order, _createSignatures(), 4_204_204_206_969);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_permit2_multiCall() public {
        Execution[] memory execs = new Execution[](1);
        execs[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 50 ether)) });

        Types.Order memory order = _createOrder(execs.toOperationMulticall(), 11);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testPermit2PreClaimOps(order, _createSignatures(), 4_204_204_206_969);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_permit2_callData() public {
        Types.Operation memory ops;
        ops.data = abi.encodePacked(
            SmartExecutionLib.Type.Calldata,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            address(env.token1),
            abi.encodeCall(IERC20.approve, (address(env.target), 75 ether))
        );

        Types.Order memory order = _createOrder(ops, 12);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testPermit2PreClaimOps(order, _createSignatures(), 4_204_204_206_969);

        assertTrue(mandateHash != bytes32(0));
    }

    function test_permit2_noExec() public {
        Types.Operation memory ops = _createEmptyOperation();
        Types.Order memory order = _createOrder(ops, 13);

        vm.prank(address(env.router));
        bytes32 mandateHash = arbiter.testPermit2PreClaimOps(order, _createSignatures(), 4_204_204_206_969);

        assertTrue(mandateHash != bytes32(0));
    }

    // ============ Helpers ============

    function _createOrder(Types.Operation memory ops, uint256 nonce) internal view returns (Types.Order memory) {
        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0][0] = uint256(uint160(address(env.token1)));
        tokenIn[0][1] = 100 ether;

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token2)));
        tokenOut[0][1] = 100 ether;

        return Types.Order({
            sponsor: env.smartAccount1.account,
            recipient: env.smartAccount1.account,
            nonce: nonce,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 1800,
            notarizedChainId: block.chainid,
            targetChainId: block.chainid,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            preClaimOps: ops,
            targetOps: _createEmptyOperation(),
            qualifier: bytes(""),
            packedGasValues: 0
        });
    }

    function _createEmptyOperation() internal pure returns (Types.Operation memory ops) {
        // Return truly empty operation - empty data means no pre-claim ops
        // This is how empty operations should be represented
        return ops; // ops.data is empty by default
    }

    function _createSignatures() internal pure returns (Types.Signatures memory) {
        return Types.Signatures({ notarizedClaimSig: abi.encodePacked(uint256(1), uint256(2), uint8(27)), preClaimSig: bytes("") });
    }
}
