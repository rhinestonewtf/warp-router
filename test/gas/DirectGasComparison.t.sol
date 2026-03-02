// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CompactEnvironment } from "../../src/tests/Environment.sol";
import { Router } from "../../src/router/Router.sol";
import { Version } from "../../src/Version.sol";
import { MockAdapter } from "../../src/tests/MockAdapter.sol";
import { MockERC20 as Token } from "../../src/tests/MockERC20.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract DirectGasComparisonTest is CompactEnvironment {
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

    function test_DirectComparison_ThreeIdenticalCalls() public {
        // Create the adapter calldatas
        bytes[] memory adapterCalldatas = new bytes[](3);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 100 ether];

        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));

        // Solver contexts
        bytes[] memory relayerContexts = new bytes[](3);
        relayerContexts[0] = "";
        relayerContexts[1] = "";
        relayerContexts[2] = "";

        console2.log("=== Direct Gas Comparison ===");

        // Take snapshot before any state changes
        uint256 snapshot = vm.snapshot();

        // TEST 1: Regular routeFill
        bytes32 hash1 = keccak256(abi.encode(adapterCalldatas));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(env.atomicFillSigner.key, hash1);
        bytes memory atomicFillSignature1 = abi.encodePacked(r1, s1, v1);

        uint256 regularGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, abi.encode(adapterCalldatas), atomicFillSignature1);
        uint256 regularGasUsed = regularGasStart - gasleft();

        // Revert to clean state
        vm.revertTo(snapshot);

        // TEST 2: Optimized routeFill (same data, clean state)
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);

        // The optimized function will use hashCalldata() which should equal keccak256() of the same data
        bytes32 hash2 = keccak256(encodedAdapterCalldatas);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(env.atomicFillSigner.key, hash2);
        bytes memory atomicFillSignature2 = abi.encodePacked(r2, s2, v2);

        uint256 optimizedGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, atomicFillSignature2);
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

    function test_DirectComparison_WithrelayerContext() public {
        // Create the adapter calldatas
        bytes[] memory adapterCalldatas = new bytes[](3);
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(testToken))), 100 ether];

        adapterCalldatas[0] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce1"), env.solver.addr, tokenOut));
        adapterCalldatas[1] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce2"), env.solver.addr, tokenOut));
        adapterCalldatas[2] = abi.encodeCall(mockAdapter.mockFill, (keccak256("nonce3"), env.solver.addr, tokenOut));

        // Solver contexts with data
        bytes[] memory relayerContexts = new bytes[](3);
        relayerContexts[0] = abi.encode(address(0x1111), uint256(100));
        relayerContexts[1] = abi.encode(address(0x2222), uint256(200));
        relayerContexts[2] = abi.encode(address(0x3333), uint256(300));

        console2.log("=== Direct Gas Comparison: With Solver Context ===");

        // Take snapshot before any state changes
        uint256 snapshot = vm.snapshot();

        // TEST 1: Regular routeFill
        bytes32 hash1 = keccak256(abi.encode(adapterCalldatas));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(env.atomicFillSigner.key, hash1);
        bytes memory atomicFillSignature1 = abi.encodePacked(r1, s1, v1);

        uint256 regularGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, abi.encode(adapterCalldatas), atomicFillSignature1);
        uint256 regularGasUsed = regularGasStart - gasleft();

        // Revert to clean state
        vm.revertTo(snapshot);

        // TEST 2: Optimized routeFill (same data, clean state)
        bytes memory encodedAdapterCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash2 = keccak256(encodedAdapterCalldatas);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(env.atomicFillSigner.key, hash2);
        bytes memory atomicFillSignature2 = abi.encodePacked(r2, s2, v2);

        uint256 optimizedGasStart = gasleft();
        router.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, atomicFillSignature2);
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
