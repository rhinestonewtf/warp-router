// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { AdapterLib_Unit_Test, MockAdapterForLib } from "../AdapterLib.t.sol";

// Libraries
import { AdapterLib } from "src/router/lib/AdapterLib.sol";

contract AdapterLib_callAdapterWithRelayerContext_Unit_Test is AdapterLib_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                            BASIC CALL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_callAdapterWithRelayerContext_BasicCall_Succeeds() public {
        bytes memory solverContext = abi.encode("solver", "data");
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(123))));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunction.selector);
        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), solverContext.length);
    }

    function test_callAdapterWithRelayerContext_EmptySolverContext_Succeeds() public {
        bytes memory solverContext = "";
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(456))));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunction.selector);
        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), 0);
    }

    function test_callAdapterWithRelayerContext_LargeSolverContext_Succeeds() public {
        // Create large solver context (10 KB)
        bytes memory solverContext = new bytes(10_240);
        for (uint256 i = 0; i < 10_240; i++) {
            solverContext[i] = bytes1(uint8(i % 256));
        }

        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(789))));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunction.selector);
        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), solverContext.length);
    }

    function test_callAdapterWithRelayerContext_ComplexCalldata_Succeeds() public {
        bytes memory solverContext = abi.encode("complex", uint256(12_345), address(0x123));
        bytes memory adapterCalldata =
            abi.encodeCall(mockAdapter.mockFunctionWithMultipleParams, (bytes32(uint256(111)), address(0xABC), 999 ether));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunctionWithMultipleParams.selector);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_callAdapterWithRelayerContext_RevertsWhen_DelegatecallFails() public {
        bytes memory solverContext = abi.encode("data");
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunctionRevertsAlways, ());

        vm.expectRevert();
        helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);
    }

    /* //////////////////////////////////////////////////////////////
                        CONTEXT ENCODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_callAdapterWithRelayerContext_ContextEncodingFormat() public {
        // Verify the exact format: [adapterCalldata][solverContext][contextLength]
        bytes memory solverContext = hex"aabbccdd";
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(123))));

        helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        // Verify context length was correctly appended
        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), 4);
    }

    function test_callAdapterWithRelayerContext_ContextPreservation() public {
        // Create context with specific data to verify preservation
        bytes memory solverContext = abi.encode(uint256(0x1234567890abcdef), address(0xDEADBEEF), "test string");

        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(999))));

        helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), solverContext.length);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_callAdapterWithRelayerContext_SolverContextSizes(uint16 contextSize) public {
        contextSize = uint16(bound(contextSize, 0, 5000));

        bytes memory solverContext = new bytes(contextSize);
        for (uint256 i = 0; i < contextSize; i++) {
            solverContext[i] = bytes1(uint8(i % 256));
        }

        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (bytes32(uint256(123))));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunction.selector);
        assertEq(MockAdapterForLib(address(helper)).lastSolverContextLength(), contextSize);
    }

    function testFuzz_callAdapterWithRelayerContext_CalldataVariations(bytes32 data) public {
        bytes memory solverContext = abi.encode("solver", uint256(12_345));
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunction, (data));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunction.selector);
    }

    function testFuzz_callAdapterWithRelayerContext_ComplexParams(bytes32 data1, address addr, uint256 amount) public {
        vm.assume(addr != address(0));
        amount = bound(amount, 0, type(uint128).max);

        bytes memory solverContext = abi.encode("fuzz", "test");
        bytes memory adapterCalldata = abi.encodeCall(mockAdapter.mockFunctionWithMultipleParams, (data1, addr, amount));

        bytes4 result = helper.callAdapter(address(mockAdapter), solverContext, adapterCalldata);

        assertEq(result, mockAdapter.mockFunctionWithMultipleParams.selector);
    }
}
