// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { MultiCallAdapter_Unit_Test } from "test/unit/arbiters/MultiCallAdapter/MultiCallAdapter.t.sol";

// Contracts
import { MultiCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/MultiCallAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

// Interfaces
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

// Mocks
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";

contract MultiCallAdapter_HandleFill_Unit_Test is MultiCallAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multicall_handleFill_RevertsWhen_NotCalledViaRouter() public {
        MultiCallAdapter.FillData memory fillData = _createBasicFillData();

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        multiCallAdapter.multicall_handleFill(fillData);
    }

    function test_multicall_handleFill_BasicFill() public {
        // Setup fill data
        MultiCallAdapter.FillData memory fillData = _createBasicFillData();

        // Approve tokens for the router to transfer from solver
        vm.prank(solver);
        tokenA.approve(router, 100 ether);

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector, "Should return correct selector");
    }

    function test_multicall_handleFill_MultipleTokensOut() public {
        // Create fill data with multiple output tokens
        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 50 ether];
        tokenOut[1] = [uint256(uint160(address(tokenB))), 30 ether];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 100 ether];

        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 0 });

        // Approve tokens
        vm.startPrank(solver);
        tokenA.approve(router, 50 ether);
        tokenB.approve(router, 30 ether);
        vm.stopPrank();

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
    }

    function test_multicall_handleFill_WithMulticalls() public {
        // Create multicalls that transfer tokens
        Execution[] memory multicalls = new Execution[](2);
        multicalls[0] = Execution({
            target: address(tokenA), value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, tokenInRecipient, 50 ether)
        });
        multicalls[1] = Execution({
            target: address(tokenB), value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, tokenInRecipient, 25 ether)
        });

        MultiCallAdapter.FillData memory fillData = _createFillDataWithMulticalls(multicalls);

        // Approve for tokenOut
        vm.prank(solver);
        tokenA.approve(router, 100 ether);

        // Ensure multiCaller has enough tokenB to transfer and drain
        tokenB.mint(address(multiCallAdapter), 125 ether);

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
    }

    function test_multicall_handleFill_EmptyTokenArrays() public {
        uint256[2][] memory emptyTokens = new uint256[2][](0);
        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: emptyTokens, tokenOut: emptyTokens, multicalls: multicalls, account: account, value: 0 });

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
    }

    function test_multicall_handleFill_RevertsWhen_InsufficientBalance() public {
        // Create fill data requiring more tokens than solver has
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 2000 ether]; // More than solver has

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenB))), 100 ether];

        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 0 });

        vm.prank(solver);
        tokenA.approve(router, 2000 ether);

        vm.expectRevert(); // Should revert due to insufficient balance
        _executeHandleFill(fillData);
    }

    function test_multicall_handleFill_WithETHValue() public {
        // Create fill data with ETH value
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 50 ether];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenB))), 100 ether];

        Execution[] memory multicalls = new Execution[](1);
        multicalls[0] = Execution({
            target: account,
            value: 1 ether,
            callData: "" // Simple ETH transfer
        });

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 1 ether });

        // Approve tokens
        vm.prank(solver);
        tokenA.approve(router, 50 ether);

        // Fund router with ETH
        vm.deal(router, 2 ether);

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
        assertEq(account.balance, 1 ether, "Account should receive ETH");
    }

    function test_multicall_handleFill_MultipleCallsWithETH() public {
        // Create multicalls with ETH transfers
        Execution[] memory multicalls = new Execution[](3);
        multicalls[0] = Execution({ target: account, value: 0.5 ether, callData: "" });
        multicalls[1] = Execution({
            target: address(tokenA), value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, tokenInRecipient, 25 ether)
        });
        multicalls[2] = Execution({ target: tokenInRecipient, value: 0.3 ether, callData: "" });

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 100 ether];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 25 ether];

        MultiCallAdapter.FillData memory fillData = MultiCallAdapter.FillData({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            multicalls: multicalls,
            account: account,
            value: 0.8 ether // Total ETH to send
        });

        // Approve tokens
        vm.prank(solver);
        tokenA.approve(router, 100 ether);

        // Fund router with ETH
        vm.deal(router, 1 ether);

        // Fund multicaller with tokenA for the transfer
        tokenA.mint(address(multiCaller), 25 ether);

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
        assertEq(account.balance, 0.5 ether, "Account should receive 0.5 ETH");
        assertEq(tokenInRecipient.balance, 0.3 ether, "TokenInRecipient should receive 0.3 ETH");
    }

    function test_multicall_handleFill_RevertsWhen_InsufficientETH() public {
        uint256[2][] memory tokenOut = new uint256[2][](0);
        uint256[2][] memory tokenIn = new uint256[2][](0);

        Execution[] memory multicalls = new Execution[](1);
        multicalls[0] = Execution({ target: account, value: 4 ether, callData: "" });

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 2 ether });

        // Drain multicaller ETH
        vm.deal(address(multiCallAdapter), 0 ether);

        vm.expectRevert(); // Should revert due to insufficient ETH
        _executeHandleFill(fillData);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_multicall_handleFill(uint256 tokenOutAmount, uint256 tokenInAmount, address fuzzAccount) public {
        vm.assume(tokenOutAmount > 0 && tokenOutAmount <= 1000 ether);
        vm.assume(tokenInAmount > 0 && tokenInAmount <= 100 ether);
        vm.assume(uint160(fuzzAccount) > uint160(420_420_420_420)); // Avoid precompile addresses

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), tokenOutAmount];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenB))), tokenInAmount];

        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: fuzzAccount, value: 0 });

        vm.prank(solver);
        tokenA.approve(router, tokenOutAmount);

        bytes4 selector = _executeHandleFill(fillData);
        assertEq(selector, multiCallAdapter.multicall_handleFill.selector);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeHandleFill(MultiCallAdapter.FillData memory fillData) internal returns (bytes4) {
        // Encode solver context (tokenInRecipient)
        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);

        // Encode the function call
        bytes memory adapterCalldata = abi.encodeWithSelector(MultiCallAdapter.multicall_handleFill.selector, fillData);

        // Append solver context as router would do
        // Format: [original_calldata][solver_context][context_length]
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        // Etch adapter code to router address for delegate call simulation
        _prankDelegateCall();

        // Perform the delegate call as router with ETH value
        vm.prank(solver); // msg.sender should be solver
        (bool success, bytes memory returnData) = router.call{ value: fillData.value }(fullCalldata);
        require(success);

        return abi.decode(returnData, (bytes4));
    }

    function _createBasicFillData() internal view returns (MultiCallAdapter.FillData memory) {
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 100 ether];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenB))), 100 ether];

        Execution[] memory multicalls = new Execution[](0);

        return MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 0 });
    }

    function _createFillDataWithMulticalls(Execution[] memory multicalls) internal view returns (MultiCallAdapter.FillData memory) {
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(tokenA))), 100 ether];

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenB))), 100 ether];

        return MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: multicalls, account: account, value: 0 });
    }
}
