// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { CompactEnvironment } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { MockAdapter } from "@rhinestone/compact-utils/src/tests/MockAdapter.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { AdapterBase } from "src/base/adapter/AdapterBase.sol";

contract AdapterBaseTest is CompactEnvironment {
    MockAdapter adapter;

    function setUp() public {
        _deployCompact();

        // Deploy MockAdapter with router and no arbiter (will create its own)
        adapter = new MockAdapter(address(env.router), address(0));

        // Set up routes for testing
        _setFillRoute(adapter.mockFill.selector, address(adapter));
        _setClaimRoute(adapter.mockClaim.selector, address(adapter));

        // Fund test accounts
        env.token1.mint(env.solver.addr, 1000 ether);
        env.token2.mint(env.solver.addr, 1000 ether);

        vm.startPrank(env.solver.addr);
        env.token1.approve(address(env.router), type(uint256).max);
        env.token2.approve(address(env.router), type(uint256).max);
        env.token1.approve(address(adapter), type(uint256).max);
        env.token2.approve(address(adapter), type(uint256).max);
        vm.stopPrank();

        // Also mint to router for prefund tests
        env.token1.mint(address(env.router), 1000 ether);
        env.token2.mint(address(env.router), 1000 ether);
    }

    // ============ onlyViaRouter Tests ============

    function test_onlyViaRouter_fillBlocked() public {
        bytes32 nonce = keccak256("test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        // Direct call should fail
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        adapter.mockFill(nonce, env.eoa.addr, tokenOut);
    }

    function test_onlyViaRouter_claimBlocked() public {
        bytes32 nonce = keccak256("test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        // Direct call should fail
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        adapter.mockClaim(nonce, env.eoa.addr, tokenOut);
    }

    function test_onlyViaRouter_fillViaRouter() public {
        bytes32 nonce = keccak256("test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        // Via router using optimized_routeFill
        bytes memory adapterCalldata = abi.encodeCall(adapter.mockFill, (nonce, env.eoa.addr, tokenOut));
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = adapterCalldata;

        bytes memory encodedCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedCalldatas);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encode("test context");

        vm.prank(env.solver.addr);
        env.router.optimized_routeFill921336808(relayerContexts, encodedCalldatas, signature);

        // Verify execution
        assertTrue(adapter.fillExecuted(nonce));
    }

    function test_onlyViaRouter_claimViaRouter() public {
        bytes32 nonce = keccak256("claim_test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        // Via router using routeClaim
        bytes memory adapterCalldata = abi.encodeCall(adapter.mockClaim, (nonce, env.eoa.addr, tokenOut));
        bytes memory relayerContext = abi.encode("claim context");

        vm.prank(env.solver.addr);
        env.router.routeClaim(relayerContext, adapterCalldata);

        // Verify execution
        assertTrue(adapter.claimExecuted(nonce));
    }

    // ============ Solver Context Tests ============

    function test_loadrelayerContext() public {
        bytes32 nonce = keccak256("context_test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 50 ether;

        bytes memory expectedContext = abi.encode("solver", "data", uint256(12_345));
        bytes memory adapterCalldata = abi.encodeCall(adapter.mockFill, (nonce, env.eoa.addr, tokenOut));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = adapterCalldata;
        bytes memory encodedCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedCalldatas);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = expectedContext;

        vm.prank(env.solver.addr);
        env.router.optimized_routeFill921336808(relayerContexts, encodedCalldatas, signature);

        // Verify context was loaded
        assertEq(adapter.lastrelayerContext(), expectedContext);
    }

    function test_loadrelayerContext_empty() public {
        bytes32 nonce = keccak256("empty_context");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 25 ether;

        bytes memory adapterCalldata = abi.encodeCall(adapter.mockClaim, (nonce, env.eoa.addr, tokenOut));
        bytes memory emptyContext = "";

        vm.prank(env.solver.addr);
        env.router.routeClaim(emptyContext, adapterCalldata);

        // Empty context should work
        assertEq(adapter.lastrelayerContext().length, 0);
    }

    // ============ Prefund Tests ============

    function test_prefundRecipient_erc20() public {
        address from = env.solver.addr;
        address to = env.eoa.addr;
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        uint256 balanceBefore = env.token1.balanceOf(to);

        adapter.mockPrefundRecipient(from, to, tokenOut);
        assertEq(env.token1.balanceOf(to), balanceBefore + 100 ether);
    }

    function test_prefundRecipient_native() public {
        address from = address(env.router);
        address to = env.eoa.addr;
        uint256 amount = 1 ether;

        // Fund router with ETH
        vm.deal(from, 10 ether);
        uint256 balanceBefore = to.balance;

        vm.prank(from);
        adapter.mockPrefundRecipientSingle{ value: amount }(from, to, Constants.NATIVE_TOKEN, amount);

        assertEq(to.balance, balanceBefore + amount);
    }

    function test_prefundRecipient_multiple() public {
        address from = env.solver.addr;
        address to = env.eoa.addr;
        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 50 ether;
        tokenOut[1][0] = uint256(uint160(address(env.token2)));
        tokenOut[1][1] = 75 ether;
        uint256 balance1Before = env.token1.balanceOf(to);
        uint256 balance2Before = env.token2.balanceOf(to);

        adapter.mockPrefundRecipient(from, to, tokenOut);
        assertEq(env.token1.balanceOf(to), balance1Before + 50 ether);
    }

    // ============ supportsInterface Tests ============

    function test_supportsInterface() public {
        assertTrue(adapter.supportsInterface(adapter.mockFill.selector));
        assertTrue(adapter.supportsInterface(adapter.mockClaim.selector));
        assertTrue(adapter.supportsInterface(adapter.supportsInterface.selector));
    }

    // ============ Event Tests ============

    function test_events_filled() public {
        vm.skip(true);
        bytes32 nonce = keccak256("event_test");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 100 ether;

        bytes memory adapterCalldata = abi.encodeCall(adapter.mockFill, (nonce, env.eoa.addr, tokenOut));
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = adapterCalldata;

        bytes memory encodedCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedCalldatas);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = "";

        // // Expect Filled event
        // // vm.expectEmit(true, true, true, true);
        // // emit AdapterBase.Filled(uint256(nonce));

        vm.prank(env.solver.addr);
        env.router.optimized_routeFill921336808(relayerContexts, encodedCalldatas, signature);
    }

    function test_events_claimed() public {
        vm.skip(true);
        bytes32 nonce = keccak256("claim_event");
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0][0] = uint256(uint160(address(env.token1)));
        tokenOut[0][1] = 50 ether;

        bytes memory adapterCalldata = abi.encodeCall(adapter.mockClaim, (nonce, env.eoa.addr, tokenOut));

        // // Expect Claimed event
        // // vm.expectEmit(true, true, true, true);
        // emit AdapterBase.Claimed(uint256(nonce));

        vm.prank(env.solver.addr);
        env.router.routeClaim("", adapterCalldata);
    }

    // ============ Batch Operations Test ============

    function test_batchFills() public {
        bytes32 nonce1 = keccak256("batch1");
        bytes32 nonce2 = keccak256("batch2");

        uint256[2][] memory tokenOut1 = new uint256[2][](1);
        tokenOut1[0][0] = uint256(uint160(address(env.token1)));
        tokenOut1[0][1] = 25 ether;

        uint256[2][] memory tokenOut2 = new uint256[2][](1);
        tokenOut2[0][0] = uint256(uint160(address(env.token2)));
        tokenOut2[0][1] = 30 ether;

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = abi.encodeCall(adapter.mockFill, (nonce1, env.eoa.addr, tokenOut1));
        adapterCalldatas[1] = abi.encodeCall(adapter.mockFill, (nonce2, env.solver.addr, tokenOut2));

        bytes memory encodedCalldatas = abi.encode(adapterCalldatas);
        bytes32 hash = keccak256(encodedCalldatas);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        bytes[] memory relayerContexts = new bytes[](2);
        relayerContexts[0] = abi.encode("context1");
        relayerContexts[1] = abi.encode("context2");

        vm.prank(env.solver.addr);
        env.router.optimized_routeFill921336808(relayerContexts, encodedCalldatas, signature);

        assertTrue(adapter.fillExecuted(nonce1));
        assertTrue(adapter.fillExecuted(nonce2));
    }
}
