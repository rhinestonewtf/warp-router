// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "../RouterLogic.t.sol";

// Contracts
import { IRouter } from "src/interfaces/IRouter.sol";
import { ISingleCaller, MultiCaller } from "src/router/utils/Caller.sol";
import { MockAdapter } from "src/tests/MockAdapter.sol";
import { ReentrantAdapter } from "test/utils/mocks/ReentrantAdapter.sol";
import { WrongSelectorAdapter, RevertingAdapter } from "test/utils/mocks/WrongSelectorAdapter.sol";

contract RouterLogic_RouteClaim_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        SINGLE CLAIM - BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Single_BasicClaim_Succeeds() public {
        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);

        // Verify claim executed successfully
        assertEq(token1.balanceOf(recipient), 100 ether);
    }

    function test_routeClaim_Single_WithMultipleTokens_Succeeds() public {
        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata =
            _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createMultipleTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);

        assertEq(token1.balanceOf(recipient), 50 ether);
        assertEq(token2.balanceOf(recipient), 75 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        BATCH CLAIM - BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Batch_SingleClaim_Succeeds() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);

        assertEq(token1.balanceOf(recipient), 100 ether);
    }

    function test_routeClaim_Batch_MultipleClaims_Succeeds() public {
        address recipient2 = makeAddr("recipient2");

        bytes[] memory solverContexts = new bytes[](2);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce2"), recipient2, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);

        assertEq(token1.balanceOf(recipient), 100 ether);
        assertEq(token1.balanceOf(recipient2), 100 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        SPECIAL SELECTORS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Single_SingleCall_Succeeds() public {
        // SingleCall selector should work without consuming solver context
        bytes memory adapterCalldata =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 50 ether)));

        token1.mint(address(routerLogic.CALLER()), 100 ether);

        vm.prank(solver);
        routerLogic.routeClaim("", adapterCalldata);

        assertEq(token1.balanceOf(recipient), 50 ether);
    }

    function test_routeClaim_Batch_WithSpecialSelectors_Succeeds() public {
        // Mix regular adapters with special selectors
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        // Regular adapter call
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        // Special selector (doesn't consume context)
        adapterCalldatas[1] =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token2), abi.encodeCall(token2.transfer, (recipient, 25 ether)));

        _approveTokens(solver, address(routerLogic), 1000 ether);
        token2.mint(address(routerLogic.CALLER()), 100 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);

        assertEq(token1.balanceOf(recipient), 100 ether);
        assertEq(token2.balanceOf(recipient), 25 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        ADAPTER CACHING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Batch_AdapterCaching_SameAdapter() public {
        // Multiple calls to same adapter should use caching
        bytes[] memory solverContexts = new bytes[](3);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));
        solverContexts[2] = _createSolverContext(keccak256("nonce3"));

        bytes[] memory adapterCalldatas = new bytes[](3);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce2"), recipient, _createBasicTokenOut());
        adapterCalldatas[2] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce3"), recipient, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);

        assertEq(token1.balanceOf(recipient), 300 ether);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_RevertsWhen_LengthMismatch_TooManySolverContexts() public {
        bytes[] memory solverContexts = new bytes[](2);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.LengthMismatch.selector);
        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);
    }

    function test_routeClaim_RevertsWhen_LengthMismatch_TooFewSolverContexts() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce2"), recipient, _createBasicTokenOut());

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.LengthMismatch.selector);
        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);
    }

    function test_routeClaim_RevertsWhen_AdapterNotInstalled() public {
        bytes4 uninstalledSelector = bytes4(keccak256("uninstalled()"));

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata = abi.encodeWithSelector(uninstalledSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);
    }

    function test_routeClaim_RevertsWhen_InsufficientBalance() public {
        address poorSolver = makeAddr("poorSolver");

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert();
        vm.prank(poorSolver);
        routerLogic.routeClaim(solverContext, adapterCalldata);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_routeClaim_Single(uint256 amount, address recip) public {
        vm.assume(recip != address(0));
        vm.assume(recip != solver); // Avoid self-transfer from solver to solver
        vm.assume(recip != user); // Avoid user who has pre-existing balance
        vm.assume(amount > 0 && amount <= 1000 ether);

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), amount];

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, keccak256("nonce1"), recip, tokenOut);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);

        assertEq(token1.balanceOf(recip), amount);
    }

    function testFuzz_routeClaim_Batch(uint8 claimCount) public {
        claimCount = uint8(bound(claimCount, 1, 10));

        bytes[] memory solverContexts = new bytes[](claimCount);
        bytes[] memory adapterCalldatas = new bytes[](claimCount);

        for (uint256 i = 0; i < claimCount; i++) {
            solverContexts[i] = _createSolverContext(bytes32(i));
            adapterCalldatas[i] = _createAdapterCalldata(MOCK_CLAIM_SELECTOR, bytes32(i), recipient, _createBasicTokenOut());
        }

        _approveTokens(solver, address(routerLogic), 10_000 ether);

        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);

        assertEq(token1.balanceOf(recipient), 100 ether * claimCount);
    }

    /* //////////////////////////////////////////////////////////////
                        REENTRANCY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Single_RevertsWhen_Reentrancy() public {
        // Deploy and install a reentrant claim adapter
        ReentrantAdapter reentrantAdapter = new ReentrantAdapter(address(routerLogic));
        bytes4 reentrantSelector = ReentrantAdapter.reentrantClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), reentrantSelector, address(reentrantAdapter));

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata =
            abi.encodeWithSelector(reentrantSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        // The adapter attempts to re-enter routeClaim during delegatecall — nonReentrant blocks it
        vm.expectRevert();
        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);
    }

    function test_routeClaim_Batch_RevertsWhen_Reentrancy() public {
        // Deploy and install a reentrant claim adapter
        ReentrantAdapter reentrantAdapter = new ReentrantAdapter(address(routerLogic));
        bytes4 reentrantSelector = ReentrantAdapter.reentrantClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), reentrantSelector, address(reentrantAdapter));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(reentrantSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        // The adapter attempts to re-enter routeClaim during delegatecall — nonReentrant blocks it
        vm.expectRevert();
        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);
    }

    /* //////////////////////////////////////////////////////////////
                    ADAPTER ERROR PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_routeClaim_Single_RevertsWhen_AdapterCallFailed_WrongSelector() public {
        WrongSelectorAdapter wrongAdapter = new WrongSelectorAdapter(address(routerLogic));
        bytes4 wrongSelector = WrongSelectorAdapter.wrongClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), wrongSelector, address(wrongAdapter));

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata =
            abi.encodeWithSelector(wrongSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert(IRouter.AdapterCallFailed.selector);
        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);
    }

    function test_routeClaim_Batch_RevertsWhen_AdapterCallFailed_WrongSelector() public {
        WrongSelectorAdapter wrongAdapter = new WrongSelectorAdapter(address(routerLogic));
        bytes4 wrongSelector = WrongSelectorAdapter.wrongClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), wrongSelector, address(wrongAdapter));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(wrongSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert(IRouter.AdapterCallFailed.selector);
        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);
    }

    function test_routeClaim_Single_RevertsWhen_DelegatecallFailed() public {
        RevertingAdapter revertAdapter = new RevertingAdapter(address(routerLogic));
        bytes4 revertSelector = RevertingAdapter.revertingClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), revertSelector, address(revertAdapter));

        bytes memory solverContext = _createSolverContext(keccak256("nonce1"));
        bytes memory adapterCalldata =
            abi.encodeWithSelector(revertSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.routeClaim(solverContext, adapterCalldata);
    }

    function test_routeClaim_Batch_RevertsWhen_DelegatecallFailed() public {
        RevertingAdapter revertAdapter = new RevertingAdapter(address(routerLogic));
        bytes4 revertSelector = RevertingAdapter.revertingClaim.selector;

        vm.prank(adapterAdder);
        routerLogic.installClaimAdapter(bytes2(0x0001), revertSelector, address(revertAdapter));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(revertSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.routeClaim(solverContexts, adapterCalldatas);
    }
}
