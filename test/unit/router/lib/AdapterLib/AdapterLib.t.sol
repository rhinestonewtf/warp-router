// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { AdapterLib } from "src/router/lib/AdapterLib.sol";

// Mock adapter that returns its selector when called
contract MockAdapterForLib {
    bytes4 public constant SELECTOR = bytes4(keccak256("mockFunction()"));

    bytes public lastCalldata;
    bytes public lastSolverContext;
    uint256 public lastSolverContextLength;

    function mockFunction(bytes32 data) external returns (bytes4) {
        _extractSolverContext();
        return this.mockFunction.selector;
    }

    function mockFunctionWithMultipleParams(bytes32 data1, address addr, uint256 amount) external returns (bytes4) {
        _extractSolverContext();
        return this.mockFunctionWithMultipleParams.selector;
    }

    function mockFunctionReturnsWrongSelector() external pure returns (bytes4) {
        return bytes4(0xdeadbeef);
    }

    function mockFunctionRevertsAlways() external pure {
        revert("Always fails");
    }

    function _extractSolverContext() internal {
        bytes calldata ctx = _loadSolverContext();
        lastSolverContextLength = ctx.length;
        lastSolverContext = ctx;
    }

    function _loadSolverContext() internal pure returns (bytes calldata solverContext) {
        assembly ("memory-safe") {
            let totalSize := calldatasize()
            let ctxLen := calldataload(sub(totalSize, 0x20))
            solverContext.offset := sub(totalSize, add(ctxLen, 0x20))
            solverContext.length := ctxLen
        }
    }
}

contract WrapperHelper {
    using AdapterLib for address;

    bytes public lastCalldata;
    bytes public lastSolverContext;
    uint256 public lastSolverContextLength;

    function callAdapter(address adapter, bytes calldata solverContext, bytes calldata adapterCalldata) external returns (bytes4) {
        return adapter.callAdapterWithRelayerContext(solverContext, adapterCalldata);
    }
}

contract AdapterLib_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using AdapterLib for address;

    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockAdapterForLib internal mockAdapter;
    WrapperHelper internal helper;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        mockAdapter = new MockAdapterForLib();
        helper = new WrapperHelper();

        vm.label(address(mockAdapter), "MockAdapter");
    }
}
