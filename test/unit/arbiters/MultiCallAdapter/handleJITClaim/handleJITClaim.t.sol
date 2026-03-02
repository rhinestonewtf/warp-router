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

contract MultiCallAdapter_HandleJITClaim_Unit_Test is MultiCallAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multicall_handleJITClaim_RevertsWhen_NotCalledViaRouter() public {
        MultiCallAdapter.JITClaimData memory jitClaimData = _createBasicJITClaimData();

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        multiCallAdapter.multicall_handleJITClaim(jitClaimData);
    }

    function test_multicall_handleJITClaim_BasicClaim() public {
        // Setup JIT claim data
        MultiCallAdapter.JITClaimData memory jitClaimData = _createBasicJITClaimData();

        // Fund multicaller with tokens to drain
        tokenA.mint(address(multiCaller), 100 ether);

        // Execute with solver context
        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    function test_multicall_handleJITClaim_MultipleTokensIn() public {
        uint256[2][] memory tokenIn = new uint256[2][](2);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 50 ether];
        tokenIn[1] = [uint256(uint160(address(tokenB))), 30 ether];

        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: multicalls });

        // Fund multicaller
        tokenA.mint(address(multiCaller), 50 ether);
        tokenB.mint(address(multiCaller), 30 ether);

        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    function test_multicall_handleJITClaim_WithMulticalls() public {
        // Create multicalls that will be executed
        Execution[] memory multicalls = new Execution[](2);
        multicalls[0] = Execution({
            target: address(tokenA), value: 0, callData: abi.encodeWithSelector(IERC20.transfer.selector, address(multiCaller), 50 ether)
        });
        multicalls[1] = Execution({
            target: address(tokenB), value: 0, callData: abi.encodeWithSelector(IERC20.approve.selector, tokenInRecipient, 100 ether)
        });

        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 50 ether];

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: multicalls });

        // Setup initial token balances
        tokenA.mint(account, 100 ether); // Account that will transfer to multicaller
        tokenA.mint(address(multiCaller), 50 ether); // For draining

        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    function test_multicall_handleJITClaim_EmptyTokenIn() public {
        uint256[2][] memory emptyTokenIn = new uint256[2][](0);

        // Create multicall that does something
        Execution[] memory multicalls = new Execution[](1);
        multicalls[0] =
            Execution({ target: address(tokenA), value: 0, callData: abi.encodeWithSelector(IERC20.approve.selector, account, 10 ether) });

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: emptyTokenIn, multicalls: multicalls });

        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    function test_multicall_handleJITClaim_EmptyMulticalls() public {
        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 100 ether];

        Execution[] memory emptyMulticalls = new Execution[](0);

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: emptyMulticalls });

        // Fund multicaller for token drain
        tokenA.mint(address(multiCaller), 100 ether);

        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    function test_multicall_handleJITClaim_RevertsWhen_InsufficientTokens() public {
        // Request more tokens than available
        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 200 ether];

        Execution[] memory multicalls = new Execution[](0);

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: multicalls });

        // Only fund with 100 ether (less than requested)
        deal(address(tokenA), address(multiCaller), 100 ether);

        vm.expectRevert(); // Should revert due to insufficient balance
        _executeHandleJITClaim(jitClaimData);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_multicall_handleJITClaim(uint256 tokenAmount, uint8 numTokens, uint8 numCalls) public {
        vm.assume(tokenAmount > 0 && tokenAmount <= 100 ether);
        vm.assume(numTokens > 0 && numTokens <= 5);
        vm.assume(numCalls <= 5);

        // Create token in array
        uint256[2][] memory tokenIn = new uint256[2][](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            address token = i % 2 == 0 ? address(tokenA) : address(tokenB);
            uint256 amount = tokenAmount / numTokens;
            tokenIn[i] = [uint256(uint160(token)), amount];

            // Fund multicaller with required tokens
            MockERC20(token).mint(address(multiCaller), amount);
        }

        // Create multicalls
        Execution[] memory multicalls = new Execution[](numCalls);
        for (uint256 i = 0; i < numCalls; i++) {
            multicalls[i] = Execution({
                target: address(tokenA), value: 0, callData: abi.encodeWithSelector(IERC20.approve.selector, account, 1 ether)
            });
        }

        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: multicalls });

        bytes4 selector = _executeHandleJITClaim(jitClaimData);
        assertEq(selector, multiCallAdapter.multicall_handleJITClaim.selector);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeHandleJITClaim(MultiCallAdapter.JITClaimData memory jitClaimData) internal returns (bytes4) {
        // Encode solver context (tokenInRecipient)
        bytes memory relayerContext = abi.encodePacked(tokenInRecipient);

        // Encode the function call
        bytes memory adapterCalldata = abi.encodeWithSelector(MultiCallAdapter.multicall_handleJITClaim.selector, jitClaimData);

        // Append solver context as router would do
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        // Etch adapter code to router address for delegate call simulation
        _prankDelegateCall();

        // Perform the delegate call as router
        (bool success, bytes memory returnData) = router.call(fullCalldata);
        require(success);

        return abi.decode(returnData, (bytes4));
    }

    function _createBasicJITClaimData() internal view returns (MultiCallAdapter.JITClaimData memory) {
        uint256[2][] memory tokenIn = new uint256[2][](1);
        tokenIn[0] = [uint256(uint160(address(tokenA))), 100 ether];

        Execution[] memory multicalls = new Execution[](0);

        return MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: multicalls });
    }
}
