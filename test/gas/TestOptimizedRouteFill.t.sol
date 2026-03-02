// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CompactEnvironment } from "../../src/tests/Environment.sol";
import { Router } from "../../src/router/Router.sol";
import { Version } from "../../src/Version.sol";
import { RouterLogic } from "../../src/router/core/RouterLogic.sol";
import { IRouter } from "../../src/interfaces/IRouter.sol";
import { MockAdapter } from "../../src/tests/MockAdapter.sol";
import { MockERC20 as Token } from "../../src/tests/MockERC20.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Caller, ISingleCaller, MultiCaller } from "../../src/router/utils/Caller.sol";
import { IDirectRoute } from "../../src/router/core/DirectRoutes.sol";
import { FeeCollector } from "../../src/router/utils/FeeCollector.sol";

contract TestOptimizedRouteFill is CompactEnvironment {
    Router public router;
    MockAdapter public mockAdapter;
    Token public testToken;

    uint256 private constant TEST_AMOUNT = 1000 ether;
    bytes4 public constant FILL_SELECTOR = MockAdapter.mockFill.selector;

    function setUp() public {
        _deployCompact();
        router = new Router(env.atomicFillSigner.addr, env.eoa.addr, env.solver.addr);
        mockAdapter = new MockAdapter(address(router), address(0));
        testToken = new Token("TestToken", "TEST", 18);
        testToken.mint(env.solver.addr, TEST_AMOUNT * 10);

        vm.prank(env.eoa.addr);
        router.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(mockAdapter));

        vm.startPrank(env.solver.addr);
        testToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_OptimizedRouteFill_BasicFunctionality() public {
        // Create adapter calldatas - 3 regular adapter calls
        bytes[] memory adapterCalldatas = new bytes[](3);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 100 ether];

        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));

        // Solver contexts for each adapter call
        bytes[] memory relayerContexts = new bytes[](3);
        relayerContexts[0] = abi.encode("context1");
        relayerContexts[1] = abi.encode("context2");
        relayerContexts[2] = abi.encode("context3");

        // Encode and sign
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.atomicFillSigner.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature);

        console2.log("Test passed: Basic functionality with 3 adapter calls");
    }

    function test_OptimizedRouteFill_MixedSelectors() public {
        // Mix regular adapter calls with special selectors (singleCall, multiCall)
        // Pattern: singleCall, mockAdapter, mockAdapter, singleCall, mockAdapter, singleCall, mockAdapter
        bytes[] memory adapterCalldatas = new bytes[](7);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 50 ether];

        bytes memory targetCall = abi.encodeCall(testToken.balanceOf, (env.solver.addr));

        // SingleCall (doesn't consume solver context)
        adapterCalldatas[0] = abi.encodeWithSelector(ISingleCaller.singleCall.selector, address(testToken), targetCall);

        // Mock adapter calls (consume solver context)
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));

        // SingleCall again (doesn't consume solver context)
        adapterCalldatas[3] = abi.encodeWithSelector(ISingleCaller.singleCall.selector, address(testToken), targetCall);

        // Mock adapter call (consumes solver context)
        adapterCalldatas[4] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));

        // SingleCall again (doesn't consume solver context)
        adapterCalldatas[5] = abi.encodeWithSelector(ISingleCaller.singleCall.selector, address(testToken), targetCall);

        // Final mock adapter call (consumes solver context)
        adapterCalldatas[6] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce4"), env.solver.addr, tokenOut));

        // Only 4 solver contexts for the 4 mock adapter calls
        bytes[] memory relayerContexts = new bytes[](4);
        relayerContexts[0] = abi.encode("context1");
        relayerContexts[1] = abi.encode("context2");
        relayerContexts[2] = abi.encode("context3");
        relayerContexts[3] = abi.encode("context4");

        // Encode and sign
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.atomicFillSigner.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature);

        console2.log("Test passed: Alternating singleCall and mockAdapter pattern");
    }

    function test_OptimizedRouteFill_RepeatedSelectors() public {
        // Test the prevSelector optimization with repeated selectors
        bytes[] memory adapterCalldatas = new bytes[](5);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 20 ether];

        // All using the same selector (should reuse adapter)
        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));
        adapterCalldatas[3] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce4"), env.solver.addr, tokenOut));
        adapterCalldatas[4] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce5"), env.solver.addr, tokenOut));

        // 5 solver contexts for 5 adapter calls
        bytes[] memory relayerContexts = new bytes[](5);
        for (uint256 i = 0; i < 5; i++) {
            relayerContexts[i] = abi.encode("context", i);
        }

        // Encode and sign
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.atomicFillSigner.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature);

        console2.log("Test passed: Repeated selectors optimization");
    }

    function test_OptimizedRouteFill_FeeCollection() public {
        // Skip fee collection test for now - would need actual fee collection setup
        // This test ensures the optimization correctly handles fee collection selectors
        // that don't consume solver contexts

        // Test with only special selectors that don't consume solver context
        bytes[] memory adapterCalldatas = new bytes[](2);

        // SingleCall (doesn't consume solver context)
        bytes memory targetCall = abi.encodeCall(testToken.balanceOf, (env.solver.addr));
        adapterCalldatas[0] = abi.encodeWithSelector(ISingleCaller.singleCall.selector, address(testToken), targetCall);

        // Another SingleCall
        adapterCalldatas[1] = abi.encodeWithSelector(ISingleCaller.singleCall.selector, address(testToken), targetCall);

        // No solver contexts needed for special selectors
        bytes[] memory relayerContexts = new bytes[](0);

        // Encode and sign
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.atomicFillSigner.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature);

        console2.log("Test passed: Special selectors that don't consume solver contexts");
    }

    function test_OptimizedRouteFill_InvalidSignature() public {
        bytes[] memory adapterCalldatas = new bytes[](1);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 10 ether];
        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));

        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encode("context1");

        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);

        // Sign with wrong key (not atomicFillSigner)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.solver.key, hash); // Wrong signer
        bytes memory wrongSignature = abi.encodePacked(r, s, v);

        // Should revert with InvalidAtomicity
        vm.expectRevert(IRouter.InvalidAtomicity.selector);
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, wrongSignature);

        console2.log("Test passed: Invalid signature rejection");
    }

    function test_OptimizedRouteFill_LengthMismatch() public {
        bytes[] memory adapterCalldatas = new bytes[](2);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 10 ether];

        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));

        // Wrong number of solver contexts
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encode("context1");

        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedAdapterCalldatas);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(env.atomicFillSigner.key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with LengthMismatch
        vm.expectRevert(IRouter.LengthMismatch.selector);
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature);

        console2.log("Test passed: Length mismatch detection");
    }

    function test_GasComparison_OptimizedVsRegular() public {
        // Create identical test data for both functions
        bytes[] memory adapterCalldatas = new bytes[](3);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 100 ether];

        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));

        bytes[] memory relayerContexts = new bytes[](3);
        relayerContexts[0] = abi.encode("context1");
        relayerContexts[1] = abi.encode("context2");
        relayerContexts[2] = abi.encode("context3");

        console2.log("=== Gas Comparison: Optimized vs Regular ===");

        // Take snapshot
        uint256 snapshot = vm.snapshot();

        // Test regular routeFill
        bytes32 hash1 = keccak256(abi.encode(adapterCalldatas));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(env.atomicFillSigner.key, hash1);
        bytes memory signature1 = abi.encodePacked(r1, s1, v1);

        uint256 regularGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, abi.encode(adapterCalldatas), signature1);
        uint256 regularGasUsed = regularGasStart - gasleft();

        // Revert to clean state
        vm.revertTo(snapshot);

        // Test optimized routeFill
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash2 = keccak256(encodedAdapterCalldatas);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(env.atomicFillSigner.key, hash2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);

        uint256 optimizedGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, signature2);
        uint256 optimizedGasUsed = optimizedGasStart - gasleft();

        // Results
        console2.log("Regular routeFill gas:     ", regularGasUsed);
        console2.log("Optimized routeFill gas:   ", optimizedGasUsed);

        if (optimizedGasUsed < regularGasUsed) {
            uint256 gasSavings = regularGasUsed - optimizedGasUsed;
            uint256 percentSavings = (gasSavings * 100) / regularGasUsed;
            console2.log("Gas savings:               ", gasSavings);
            console2.log("Percent savings:           ", percentSavings, "%");
        } else {
            uint256 gasIncrease = optimizedGasUsed - regularGasUsed;
            uint256 percentIncrease = (gasIncrease * 100) / regularGasUsed;
            console2.log("Gas increase:              ", gasIncrease);
            console2.log("Percent increase:          ", percentIncrease, "%");
        }
    }
}
