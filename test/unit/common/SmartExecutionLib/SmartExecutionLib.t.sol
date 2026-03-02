// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

/// @title SmartExecutionLibHarness
/// @notice Exposes SmartExecutionLib internal/library functions for testing
contract SmartExecutionLibHarness {
    using SmartExecutionLib for Types.Operation;
    using SmartExecutionLib for SmartExecutionLib.SigMode;

    function encode(SmartExecutionLib.SigMode sigMode, Execution[] memory exec) external pure returns (Types.Operation memory) {
        return SmartExecutionLib.encode(sigMode, exec);
    }

    function decode(Types.Operation calldata ops) external pure returns (SmartExecutionLib.SigMode, Execution[] calldata) {
        return SmartExecutionLib.decode(ops);
    }

    function extractSigMode(Types.Operation calldata ops) external pure returns (SmartExecutionLib.SigMode) {
        return ops.extractSigMode();
    }

    function isExecutionEmissary(Types.Operation calldata ops) external pure returns (bool) {
        return ops.isExecutionEmissary();
    }

    function isExecutionEmissaryFromMode(SmartExecutionLib.SigMode sigMode) external pure returns (bool) {
        return sigMode.isExecutionEmissary();
    }

    function safeToERC7579(Types.Operation calldata ops) external pure returns (Execution[] calldata) {
        return ops.safeToERC7579();
    }

    function safeToMultiCall(Types.Operation calldata ops) external pure returns (Execution[] calldata) {
        return ops.safeToMultiCall();
    }

    function safeToCalldata(Types.Operation calldata ops) external pure returns (address, bytes calldata) {
        return ops.safeToCalldata();
    }

    function decodeAll(Types.Operation calldata ops) external pure returns (SmartExecutionLib.Type, bytes32) {
        return ops.decodeAll();
    }

    function toExecType(Types.Operation calldata ops) external pure returns (SmartExecutionLib.Type) {
        return ops.toExecType();
    }

    function toUint8(SmartExecutionLib.SigMode mode) external pure returns (uint8) {
        return SmartExecutionLib.toUint8(mode);
    }

    function toSigModeFromUint8(uint8 val) external pure returns (SmartExecutionLib.SigMode) {
        return SmartExecutionLib.toSigMode(val);
    }

    function toSigModeFromBytes1(bytes1 val) external pure returns (SmartExecutionLib.SigMode) {
        return SmartExecutionLib.toSigMode(val);
    }

    /// @notice Wrapper that simulates calling toSigMode(bytes1) from an assembly context,
    /// where the bytes1 value sits in the least-significant byte of the stack word.
    function toSigModeFromBytes1ViaAssembly(uint8 val) external pure returns (SmartExecutionLib.SigMode _out) {
        assembly ("memory-safe") {
            // Place val right-aligned as a bytes1 would appear in assembly contexts
            _out := and(val, 0xFF)
        }
    }
}

contract SmartExecutionLib_Unit_Test is Test {
    SmartExecutionLibHarness internal harness;

    function setUp() public {
        harness = new SmartExecutionLibHarness();
    }

    /* //////////////////////////////////////////////////////////////
                        ENCODE/DECODE ROUND TRIPS
    //////////////////////////////////////////////////////////////*/

    function _createSampleExecutions() internal pure returns (Execution[] memory) {
        Execution[] memory execs = new Execution[](2);
        execs[0] = Execution({ target: address(0xBEEF), value: 0, callData: hex"12345678" });
        execs[1] = Execution({ target: address(0xCAFE), value: 1 ether, callData: hex"aabbccdd" });
        return execs;
    }

    function test_encodeDecodeRoundTrip_EMISSARY() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.EMISSARY, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.EMISSARY));
        assertEq(decoded.length, 2);
        assertEq(decoded[0].target, address(0xBEEF));
        assertEq(decoded[1].target, address(0xCAFE));
    }

    function test_encodeDecodeRoundTrip_ERC1271() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.ERC1271, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.ERC1271));
        assertEq(decoded.length, 2);
    }

    function test_encodeDecodeRoundTrip_EMISSARY_ERC1271() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.EMISSARY_ERC1271));
        assertEq(decoded.length, 2);
    }

    function test_encodeDecodeRoundTrip_ERC1271_EMISSARY() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.ERC1271_EMISSARY, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.ERC1271_EMISSARY));
        assertEq(decoded.length, 2);
    }

    function test_encodeDecodeRoundTrip_EMISSARY_EXECUTION() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.EMISSARY_EXECUTION));
        assertEq(decoded.length, 2);
    }

    function test_encodeDecodeRoundTrip_EMISSARYEXECUTION_ERC1271() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271));
        assertEq(decoded.length, 2);
    }

    function test_encodeDecodeRoundTrip_ERC1271_EMISSARYEXECUTION() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory encoded = harness.encode(SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION, execs);

        (SmartExecutionLib.SigMode sigMode, Execution[] memory decoded) = harness.decode(encoded);
        assertEq(uint8(sigMode), uint8(SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION));
        assertEq(decoded.length, 2);
    }

    /* //////////////////////////////////////////////////////////////
                        SAFE CONVERSION HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_safeToERC7579_HappyPath() public view {
        Execution[] memory execs = _createSampleExecutions();
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(SmartExecutionLib.SigMode.ERC1271), abi.encode(execs));
        Types.Operation memory ops = Types.Operation({ data: data });

        Execution[] memory result = harness.safeToERC7579(ops);
        assertEq(result.length, 2);
        assertEq(result[0].target, address(0xBEEF));
        assertEq(result[1].target, address(0xCAFE));
    }

    function test_safeToMultiCall_HappyPath() public view {
        Execution[] memory execs = _createSampleExecutions();
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.MultiCall), uint8(SmartExecutionLib.SigMode.ERC1271), abi.encode(execs));
        Types.Operation memory ops = Types.Operation({ data: data });

        Execution[] memory result = harness.safeToMultiCall(ops);
        assertEq(result.length, 2);
        assertEq(result[0].target, address(0xBEEF));
        assertEq(result[1].target, address(0xCAFE));
    }

    function test_safeToCalldata_HappyPath() public view {
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.Calldata), uint8(SmartExecutionLib.SigMode.ERC1271), address(0xBEEF), hex"12345678");
        Types.Operation memory ops = Types.Operation({ data: data });

        (address target, bytes memory rawCalldata) = harness.safeToCalldata(ops);
        assertEq(target, address(0xBEEF));
        assertEq(rawCalldata, hex"12345678");
    }

    /* //////////////////////////////////////////////////////////////
                        SAFE CONVERSION REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_decode_RevertsWhen_WrongType() public {
        // Encode with Calldata type byte instead of ERC7579
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.Calldata), uint8(SmartExecutionLib.SigMode.ERC1271), hex"00");
        Types.Operation memory ops = Types.Operation({ data: data });
        vm.expectRevert(SmartExecutionLib.IncorrectType.selector);
        harness.decode(ops);
    }

    function test_safeToERC7579_RevertsWhen_WrongType() public {
        // Build data with MultiCall type byte
        Execution[] memory execs = _createSampleExecutions();
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.MultiCall), uint8(SmartExecutionLib.SigMode.ERC1271), abi.encode(execs));
        Types.Operation memory ops = Types.Operation({ data: data });
        vm.expectRevert(SmartExecutionLib.IncorrectType.selector);
        harness.safeToERC7579(ops);
    }

    function test_safeToMultiCall_RevertsWhen_WrongType() public {
        // Build data with ERC7579 type byte
        Execution[] memory execs = _createSampleExecutions();
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(SmartExecutionLib.SigMode.ERC1271), abi.encode(execs));
        Types.Operation memory ops = Types.Operation({ data: data });
        vm.expectRevert(SmartExecutionLib.IncorrectType.selector);
        harness.safeToMultiCall(ops);
    }

    function test_safeToCalldata_RevertsWhen_WrongType() public {
        // Build data with ERC7579 type byte
        Execution[] memory execs = _createSampleExecutions();
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(SmartExecutionLib.SigMode.ERC1271), abi.encode(execs));
        Types.Operation memory ops = Types.Operation({ data: data });
        vm.expectRevert(SmartExecutionLib.IncorrectType.selector);
        harness.safeToCalldata(ops);
    }

    /* //////////////////////////////////////////////////////////////
                        EXTRACT SIG MODE
    //////////////////////////////////////////////////////////////*/

    function test_extractSigMode_AllValues() public view {
        SmartExecutionLib.SigMode[7] memory modes = [
            SmartExecutionLib.SigMode.EMISSARY,
            SmartExecutionLib.SigMode.ERC1271,
            SmartExecutionLib.SigMode.EMISSARY_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            SmartExecutionLib.SigMode.EMISSARY_EXECUTION,
            SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION
        ];

        for (uint256 i = 0; i < modes.length; i++) {
            bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(modes[i]), hex"00");
            Types.Operation memory ops = Types.Operation({ data: data });
            SmartExecutionLib.SigMode extracted = harness.extractSigMode(ops);
            assertEq(uint8(extracted), uint8(modes[i]));
        }
    }

    /* //////////////////////////////////////////////////////////////
                        IS EXECUTION EMISSARY
    //////////////////////////////////////////////////////////////*/

    function test_isExecutionEmissary_TrueForExecutionModes() public view {
        SmartExecutionLib.SigMode[3] memory executionModes = [
            SmartExecutionLib.SigMode.EMISSARY_EXECUTION,
            SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION
        ];

        for (uint256 i = 0; i < executionModes.length; i++) {
            assertTrue(harness.isExecutionEmissaryFromMode(executionModes[i]));

            bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(executionModes[i]), hex"00");
            Types.Operation memory ops = Types.Operation({ data: data });
            assertTrue(harness.isExecutionEmissary(ops));
        }
    }

    function test_isExecutionEmissary_FalseForNonExecutionModes() public view {
        SmartExecutionLib.SigMode[4] memory nonExecModes = [
            SmartExecutionLib.SigMode.EMISSARY,
            SmartExecutionLib.SigMode.ERC1271,
            SmartExecutionLib.SigMode.EMISSARY_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY
        ];

        for (uint256 i = 0; i < nonExecModes.length; i++) {
            assertFalse(harness.isExecutionEmissaryFromMode(nonExecModes[i]));

            bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(nonExecModes[i]), hex"00");
            Types.Operation memory ops = Types.Operation({ data: data });
            assertFalse(harness.isExecutionEmissary(ops));
        }
    }

    /* //////////////////////////////////////////////////////////////
                        DECODE ALL / TO EXEC TYPE
    //////////////////////////////////////////////////////////////*/

    function test_decodeAll_EmptyOps_ReturnsNoOps() public view {
        Types.Operation memory ops = Types.Operation({ data: "" });
        (SmartExecutionLib.Type _type, bytes32 hash) = harness.decodeAll(ops);
        assertEq(uint8(_type), uint8(SmartExecutionLib.Type.Eip712Hash));
        assertEq(hash, Constants.NO_OPS);
    }

    function test_toExecType_EmptyData_ReturnsEip712Hash() public view {
        Types.Operation memory ops = Types.Operation({ data: "" });
        SmartExecutionLib.Type _type = harness.toExecType(ops);
        assertEq(uint8(_type), uint8(SmartExecutionLib.Type.Eip712Hash));
    }

    function test_decodeAll_NonEmpty_ReturnsCorrectTypeAndHash() public view {
        Execution[] memory execs = _createSampleExecutions();
        Types.Operation memory ops = harness.encode(SmartExecutionLib.SigMode.ERC1271, execs);

        (SmartExecutionLib.Type _type, bytes32 hash) = harness.decodeAll(ops);
        assertEq(uint8(_type), uint8(SmartExecutionLib.Type.ERC7579));
        assertTrue(hash != Constants.NO_OPS);
        assertTrue(hash != bytes32(0));
    }

    /* //////////////////////////////////////////////////////////////
                        CONVERSION HELPERS
    //////////////////////////////////////////////////////////////*/

    function test_toUint8_RoundTrip() public view {
        SmartExecutionLib.SigMode[7] memory modes = [
            SmartExecutionLib.SigMode.EMISSARY,
            SmartExecutionLib.SigMode.ERC1271,
            SmartExecutionLib.SigMode.EMISSARY_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            SmartExecutionLib.SigMode.EMISSARY_EXECUTION,
            SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION
        ];

        for (uint256 i = 0; i < modes.length; i++) {
            uint8 asUint8 = harness.toUint8(modes[i]);
            SmartExecutionLib.SigMode roundTripped = harness.toSigModeFromUint8(asUint8);
            assertEq(uint8(roundTripped), uint8(modes[i]));
        }
    }

    function test_toSigMode_FromBytes1() public view {
        SmartExecutionLib.SigMode[7] memory modes = [
            SmartExecutionLib.SigMode.EMISSARY,
            SmartExecutionLib.SigMode.ERC1271,
            SmartExecutionLib.SigMode.EMISSARY_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARY,
            SmartExecutionLib.SigMode.EMISSARY_EXECUTION,
            SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271,
            SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION
        ];

        for (uint256 i = 0; i < modes.length; i++) {
            // The library's toSigMode(bytes1) uses `and(_in, 0xFF)` in assembly,
            // which reads the least-significant byte of the 32-byte stack word.
            // This function is designed for assembly contexts where a bytes1 value
            // is right-aligned. We use toSigModeFromBytes1ViaAssembly to replicate
            // that calling convention.
            SmartExecutionLib.SigMode converted = harness.toSigModeFromBytes1ViaAssembly(uint8(modes[i]));
            assertEq(uint8(converted), uint8(modes[i]));
        }
    }
}
