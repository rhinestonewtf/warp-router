// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "../RouterLogic.t.sol";

// Contracts
import { IRouter } from "src/interfaces/IRouter.sol";
import { ISingleCaller, MultiCaller } from "src/router/utils/Caller.sol";
import { IDirectRoute } from "src/router/core/DirectRoutes.sol";
import { FeeCollector } from "src/router/utils/FeeCollector.sol";
import { MockAdapter } from "src/tests/MockAdapter.sol";
import { ReentrantAdapter } from "test/utils/mocks/ReentrantAdapter.sol";
import { WrongSelectorAdapter, RevertingAdapter } from "test/utils/mocks/WrongSelectorAdapter.sol";

contract RouterLogic_OptimizedRouteFill_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        BASIC FILL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_SingleFill_Succeeds() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 100 ether);
    }

    function test_optimizedRouteFill_MultipleFills_Succeeds() public {
        address recipient2 = makeAddr("recipient2");

        bytes[] memory solverContexts = new bytes[](2);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce2"), recipient2, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 100 ether);
        assertEq(token1.balanceOf(recipient2), 100 ether);
    }

    function test_optimizedRouteFill_WithMultipleTokens_Succeeds() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createMultipleTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 50 ether);
        assertEq(token2.balanceOf(recipient), 75 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        ADAPTER CACHING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_AdapterCaching_SameAdapter() public {
        // Multiple calls with same selector should use caching
        bytes[] memory solverContexts = new bytes[](3);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));
        solverContexts[2] = _createSolverContext(keccak256("nonce3"));

        bytes[] memory adapterCalldatas = new bytes[](3);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce2"), recipient, _createBasicTokenOut());
        adapterCalldatas[2] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce3"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 300 ether);
    }

    /* //////////////////////////////////////////////////////////////
                    SPECIAL SELECTORS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_WithSingleCall_Succeeds() public {
        // Mix regular fill with single call (special selector)
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        // Regular fill adapter
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        // Special selector (doesn't consume context) - use encodePacked for fallback
        adapterCalldatas[1] =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token2), abi.encodeCall(token2.transfer, (recipient, 25 ether)));

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);
        token2.mint(address(routerLogic.CALLER()), 100 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 100 ether);
        assertEq(token2.balanceOf(recipient), 25 ether);
    }

    function test_optimizedRouteFill_WithFeeCollection_Succeeds() public {
        address feeRecipient = makeAddr("feeRecipient");

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 5 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = abi.encodeWithSelector(IDirectRoute.onFill_inRouter_collectFee.selector, fee);

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 100 ether);
        assertEq(token1.balanceOf(feeRecipient), 5 ether);
    }

    function test_optimizedRouteFill_AllSpecialSelectors_NoContexts() public {
        // All special selectors, no regular adapters, no contexts needed
        bytes[] memory solverContexts = new bytes[](0);

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 30 ether)));
        adapterCalldatas[1] =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token2), abi.encodeCall(token2.transfer, (recipient, 40 ether)));

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        token1.mint(address(routerLogic.CALLER()), 100 ether);
        token2.mint(address(routerLogic.CALLER()), 100 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 30 ether);
        assertEq(token2.balanceOf(recipient), 40 ether);
    }

    /* //////////////////////////////////////////////////////////////
                        SIGNATURE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_RevertsWhen_InvalidSignature() public {
        uint256 wrongPk = 0xBAD;

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory wrongSig = _signAtomicFillWithKey(wrongPk, encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.InvalidAtomicity.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, wrongSig);
    }

    function test_optimizedRouteFill_RevertsWhen_SignatureForDifferentData() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory wrongData = abi.encode("wrong");
        bytes memory wrongSig = _signAtomicFill(wrongData);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.InvalidAtomicity.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, wrongSig);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_RevertsWhen_LengthMismatch_TooManySolverContexts() public {
        bytes[] memory solverContexts = new bytes[](2);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));
        solverContexts[1] = _createSolverContext(keccak256("nonce2"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.LengthMismatch.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    function test_optimizedRouteFill_RevertsWhen_LengthMismatch_TooFewSolverContexts() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());
        adapterCalldatas[1] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce2"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.LengthMismatch.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    function test_optimizedRouteFill_RevertsWhen_InsufficientBalance() public {
        address poorSolver = makeAddr("poorSolver");

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        vm.expectRevert();
        vm.prank(poorSolver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    function test_optimizedRouteFill_RevertsWhen_AdapterNotInstalled() public {
        bytes4 uninstalledSelector = bytes4(keccak256("uninstalled()"));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(uninstalledSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_optimizedRouteFill_SingleFill(uint256 amount, address recip) public {
        vm.assume(recip != address(0));
        vm.assume(recip != solver); // Avoid self-transfer from solver to solver
        vm.assume(amount > 0 && amount <= 1000 ether);

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), amount];

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recip, tokenOut);

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recip), amount);
    }

    function testFuzz_optimizedRouteFill_MultipleFills(uint8 fillCount) public {
        fillCount = uint8(bound(fillCount, 1, 10));

        bytes[] memory solverContexts = new bytes[](fillCount);
        bytes[] memory adapterCalldatas = new bytes[](fillCount);

        for (uint256 i = 0; i < fillCount; i++) {
            solverContexts[i] = _createSolverContext(bytes32(i));
            adapterCalldatas[i] = _createAdapterCalldata(MOCK_FILL_SELECTOR, bytes32(i), recipient, _createBasicTokenOut());
        }

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 10_000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);

        assertEq(token1.balanceOf(recipient), 100 ether * fillCount);
    }

    /* //////////////////////////////////////////////////////////////
                        REENTRANCY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_RevertsWhen_Reentrancy() public {
        // Deploy and install a reentrant fill adapter
        ReentrantAdapter reentrantAdapter = new ReentrantAdapter(address(routerLogic));
        bytes4 reentrantSelector = ReentrantAdapter.reentrantFill.selector;

        vm.prank(adapterAdder);
        routerLogic.installFillAdapter(bytes2(0x0001), reentrantSelector, address(reentrantAdapter));

        // Build calldata that routes through the reentrant adapter
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(reentrantSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        // The adapter attempts to call routeClaim during delegatecall — nonReentrant blocks it
        vm.expectRevert();
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    /* //////////////////////////////////////////////////////////////
                    ADAPTER ERROR PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_optimizedRouteFill_RevertsWhen_AdapterCallFailed_WrongSelector() public {
        WrongSelectorAdapter wrongAdapter = new WrongSelectorAdapter(address(routerLogic));
        bytes4 wrongSelector = WrongSelectorAdapter.wrongFill.selector;

        vm.prank(adapterAdder);
        routerLogic.installFillAdapter(bytes2(0x0001), wrongSelector, address(wrongAdapter));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(wrongSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        vm.expectRevert(IRouter.AdapterCallFailed.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    function test_optimizedRouteFill_RevertsWhen_DelegatecallFailed() public {
        RevertingAdapter revertAdapter = new RevertingAdapter(address(routerLogic));
        bytes4 revertSelector = RevertingAdapter.revertingFill.selector;

        vm.prank(adapterAdder);
        routerLogic.installFillAdapter(bytes2(0x0001), revertSelector, address(revertAdapter));

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeWithSelector(revertSelector, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }
}
