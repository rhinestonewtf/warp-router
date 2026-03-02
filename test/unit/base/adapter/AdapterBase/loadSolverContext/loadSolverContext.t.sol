// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { AdapterBase_Unit_Test } from "test/unit/base/adapter/AdapterBase/AdapterBase.t.sol";

contract AdapterBase_relayerContext_Unit_Test is AdapterBase_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        SOLVER CONTEXT LOADING
    //////////////////////////////////////////////////////////////*/

    function test_loadrelayerContext_BasicContext() public {
        bytes32 nonce = keccak256("context_test");
        uint256[2][] memory tokenOut = _createBasicTokenOut();

        bytes memory expectedContext = abi.encode("solver", "data", uint256(12_345));

        _executeFillViaRouter(nonce, recipient, tokenOut, expectedContext);

        assertEq(adapter.lastrelayerContext(), expectedContext);
    }

    function test_loadrelayerContext_EmptyContext() public {
        bytes32 nonce = keccak256("empty_context");
        uint256[2][] memory tokenOut = _createBasicTokenOut();

        bytes memory emptyContext = "";

        _executeClaimViaRouter(nonce, recipient, tokenOut, emptyContext);

        assertEq(adapter.lastrelayerContext().length, 0);
    }

    function test_loadrelayerContext_ComplexStructData() public {
        bytes32 nonce = keccak256("complex");

        // Create complex context with struct-like data
        bytes memory complexContext = abi.encode(
            recipient, uint256(999), bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef), "metadata string"
        );

        _executeFillViaRouter(nonce, recipient, _createBasicTokenOut(), complexContext);

        assertEq(adapter.lastrelayerContext(), complexContext);
    }

    function test_loadrelayerContext_LargeContext() public {
        bytes32 nonce = keccak256("large");

        // Create large context (1KB)
        bytes memory largeContext = new bytes(1024);
        for (uint256 i = 0; i < 1024; i++) {
            largeContext[i] = bytes1(uint8(i % 256));
        }

        _executeFillViaRouter(nonce, recipient, _createBasicTokenOut(), largeContext);

        assertEq(adapter.lastrelayerContext(), largeContext);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_loadrelayerContext(bytes32 nonce, bytes memory contextData) public {
        vm.assume(contextData.length <= 10_000);

        _executeFillViaRouter(nonce, recipient, _createBasicTokenOut(), contextData);

        assertEq(adapter.lastrelayerContext(), contextData);
    }
}
