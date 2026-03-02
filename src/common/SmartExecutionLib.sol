// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { LibERC7579 } from "../common/LibERC7579.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Constants } from "../types/Constants.sol";
import { EIP712TypeHashLib } from "../types/EIP712TypeHashLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";

/**
 * @title SmartExecution
 * @author Rhinestone (zeroknots.eth, @highscore)
 * @notice A library for encoding and decoding different types of execution data.
 *         It provides helper functions to handle various execution formats, such as converting
 *         raw calldata to ERC-7579 `Execution` structs. The first byte of an encoded execution
 *         payload indicates its type.
 */
library SmartExecutionLib {
    using LibERC7579 for bytes;
    using SmartExecutionLib for Types.Operation;
    using SmartExecutionLib for bytes;
    using EfficientHashLib for bytes32;
    using EfficientHashLib for bytes32[];
    using EIP712TypeHashLib for Execution[];
    using EIP712TypeHashLib for Types.Operation;

    /// @notice Thrown when the execution type doesn't match the expected type
    error IncorrectType();

    /**
     * @notice Defines the type of execution encoded in a bytes payload.
     * @dev The type is determined by the first byte of the payload.
     *      - `NONE`: No execution type specified.
     *      - `Eip712Hash`: The payload is an EIP-712 hash (not fully implemented).
     *      - `Calldata`: The payload is raw transaction calldata.
     */
    enum Type {
        Eip712Hash,
        Calldata,
        ERC7579,
        MultiCall
    }

    enum SigMode {
        EMISSARY,
        ERC1271,
        EMISSARY_ERC1271,
        ERC1271_EMISSARY,
        EMISSARY_EXECUTION,
        EMISSARYEXECUTION_ERC1271,
        ERC1271_EMISSARYEXECUTION
    }

    // Constants for ops.data byte offsets
    uint256 internal constant OFFSET_EXEC_TYPE = 0;
    uint256 internal constant OFFSET_SIG_MODE = 1;
    uint256 internal constant OFFSET_EXEC_DATA = 2;

    function toUint8(SigMode _sigMode) internal pure returns (uint8 _out) {
        assembly ("memory-safe") {
            _out := _sigMode
        }
    }

    function toSigMode(uint8 _in) internal pure returns (SigMode _sigMode) {
        assembly ("memory-safe") {
            _sigMode := _in
        }
    }

    function toSigMode(bytes1 _in) internal pure returns (SigMode _sigMode) {
        assembly ("memory-safe") {
            _sigMode := and(_in, 0xFF)
        }
    }

    function extractSigMode(Types.Operation calldata ops) internal pure returns (SigMode _sigMode) {
        _sigMode = SigMode(uint8(ops.data[OFFSET_SIG_MODE]));
    }

    function isExecutionEmissary(Types.Operation calldata ops) internal pure returns (bool) {
        SigMode sigMode = extractSigMode(ops);
        return sigMode == SigMode.EMISSARY_EXECUTION || sigMode == SigMode.EMISSARYEXECUTION_ERC1271
            || sigMode == SigMode.ERC1271_EMISSARYEXECUTION;
    }

    function isExecutionEmissary(SigMode sigMode) internal pure returns (bool) {
        return sigMode == SigMode.EMISSARY_EXECUTION || sigMode == SigMode.EMISSARYEXECUTION_ERC1271
            || sigMode == SigMode.ERC1271_EMISSARYEXECUTION;
    }

    /**
     * @notice Decodes all components from an operation struct
     * @dev Extracts signature mode, execution type, and computes the EIP-712 hash in a single call.
     *      For empty operations, returns NO_OPS (hash of empty Op wrapper) instead of NO_EXEC
     *      to correctly represent an empty Op struct in the EIP-712 structure.
     * @param ops The operation struct to decode
     * @return _type The execution type extracted from byte 0
     * @return hash The EIP-712 hash of the operation (NO_OPS for empty operations)
     * @custom:security Uses toExecType() which validates the type byte before casting
     */
    function decodeAll(Types.Operation calldata ops) internal pure returns (Type _type, bytes32 hash) {
        // For empty operations, return NO_OPS which is the hash of an empty Op wrapper struct
        // This differs from NO_EXEC which is just the hash of an empty Ops[] array
        if (ops.data.length == 0) return (SmartExecutionLib.Type.Eip712Hash, Constants.NO_OPS);
        // toExecType() validates the type byte before casting
        _type = ops.toExecType();
        hash = ops.hashOps();
    }

    /**
     * @notice Determines the execution type from an encoded execution payload.
     * @dev It reads the first byte of the `encodedExecution` data.
     *      SECURITY: Validates the type byte before casting to prevent enum conversion panics
     * @param ops The encoded execution payload.
     * @return _type The execution type enum.
     */
    function toExecType(Types.Operation calldata ops) internal pure returns (Type _type) {
        if (ops.data.length == 0) return Type.Eip712Hash;
        uint8 typeValue = uint8(ops.data[OFFSET_EXEC_TYPE]);
        _type = Type(typeValue);
    }

    /**
     * @notice Safely decodes an execution payload into an array of ERC-7579 `Execution` structs.
     * @dev It first checks that the execution type is `Calldata` and then calls `toERC7579`.
     *      It reverts with `IncorrectType` if the type is wrong.
     * @param ops The full encoded execution payload, including the type byte.
     * @return executions An array of `Execution` structs.
     */
    function safeToERC7579(Types.Operation calldata ops) internal pure returns (Execution[] calldata executions) {
        require(toExecType(ops) == Type.ERC7579, IncorrectType());
        return ops.onlyExecutionData().toERC7579();
    }

    /**
     * @notice Safely decodes an execution payload into an array of ERC-7579 `Execution` structs.
     * @dev It first checks that the execution type is `Calldata` and then calls `toERC7579`.
     *      It reverts with `IncorrectType` if the type is wrong.
     * @param ops The full encoded execution payload, including the type byte.
     * @return executions An array of `Execution` structs.
     */
    function safeToMultiCall(Types.Operation calldata ops) internal pure returns (Execution[] calldata executions) {
        require(toExecType(ops) == Type.MultiCall, IncorrectType());
        return ops.onlyExecutionData().toERC7579();
    }

    function onlyExecutionData(Types.Operation calldata ops) internal pure returns (bytes calldata encodedExec) {
        encodedExec = ops.data[OFFSET_EXEC_DATA:];
    }

    /**
     * @notice Decodes a raw calldata payload (without the type byte) into an array of ERC-7579 `Execution` structs.
     * @dev This function uses `decodeBatch` from `LibERC7579` and then performs a memory-safe cast
     *      of the resulting pointers to the `Execution[]` type using assembly.
     * @param encodedExecutionWithoutType The execution payload, excluding the type byte.
     * @return executions An array of `Execution` structs.
     */
    function toERC7579(bytes calldata encodedExecutionWithoutType) internal pure returns (Execution[] calldata executions) {
        bytes32[] calldata pointers = encodedExecutionWithoutType.decodeBatchUnchecked();
        assembly ("memory-safe") {
            executions.offset := pointers.offset
            executions.length := pointers.length
        }
    }

    /**
     * @notice Safely decodes an execution payload into a target address and raw calldata.
     * @dev It first checks that the execution type is `Calldata` and then calls `toCalldata`.
     *      It reverts with `IncorrectType` if the type is wrong.
     * @param ops The full encoded execution payload, including the type byte.
     * @return target The target address for the call.
     * @return rawCalldata The raw calldata for the call.
     */
    function safeToCalldata(Types.Operation calldata ops) internal pure returns (address target, bytes calldata rawCalldata) {
        require(toExecType(ops) == Type.Calldata, IncorrectType());
        return toCalldata(ops.data[OFFSET_EXEC_DATA:]); // Skip the type and sig mode bytes
    }

    /**
     * @notice Decodes a raw calldata payload (without the type byte) into a target address and raw calldata.
     * @dev It assumes the first 20 bytes are the target address and the rest is the calldata.
     * @param encodedExecutionWithoutType The execution payload, excluding the type byte.
     * @return target The target address for the call.
     * @return rawCalldata The raw calldata for the call.
     */
    function toCalldata(bytes calldata encodedExecutionWithoutType) internal pure returns (address target, bytes calldata rawCalldata) {
        target = address(bytes20(encodedExecutionWithoutType[:20])); // Extract the target address
        rawCalldata = encodedExecutionWithoutType[20:]; // The rest is the calldata
    }

    function encode(SigMode sigMode, Execution[] memory exec) internal pure returns (Types.Operation memory ops) {
        ops.data = abi.encodePacked(Type.ERC7579, sigMode, abi.encode(exec));
    }

    function decode(Types.Operation calldata ops) internal pure returns (SigMode sigMode, Execution[] calldata executions) {
        bytes calldata encoded = ops.data;
        Type _type = Type(uint8(encoded[OFFSET_EXEC_TYPE]));
        require(_type == Type.ERC7579, IncorrectType());
        sigMode = SigMode(uint8(encoded[OFFSET_SIG_MODE]));
        executions = toERC7579(encoded[OFFSET_EXEC_DATA:]);
    }
}
