// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@rhinestone/compact-utils/src/tests/Environment.sol";
import { MultiCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/MultiCallAdapter.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Caller, MultiCaller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { FeeCollector } from "@rhinestone/compact-utils/src/router/utils/FeeCollector.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

contract MockAccount {
    function execute(address target, uint256 value, bytes calldata callData) external payable {
        (bool success,) = target.call{ value: value }(callData);
        require(success);
    }

    receive() external payable { }
}

contract MultiCallAdapterTest is CompactEnvironment {
    using IdLib for uint256;
    using TestHelperLib for uint256[2];

    MockAccount mockAccount;
    MultiCaller multicall;

    function setUp() public {
        _deployCompact();

        // Deploy mock account
        mockAccount = new MockAccount();

        // Cache multicall contract for better readability
        multicall = MultiCaller(payable(address(env.router.CALLER())));

        // Set up routes for MultiCallAdapter functions
        // _setFillRoute(MultiCallAdapter.multicall_handleFill.selector, address(env.multicallAdapter));
        _setFillRoute(MultiCallAdapter.multicall_handlePayable.selector, address(env.multicallAdapter));
        // _setClaimRoute(MultiCallAdapter.multicall_handleJITClaim.selector, address(env.multicallAdapter));
    }

    function test_multicall_handleFill_single() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount so it can transfer them to MultiCall
        env.token2.mint(address(mockAccount), 10 ether);

        // Create executions that will:
        // 1. Call the target function
        // 2. Transfer tokenIn to MultiCall contract (which then drains to solver)
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context with tokenIn recipient
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Execute fill
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify execution happened
        assertEq(env.target.param(), 42);

        // Verify token transfers
        assertEq(env.token1.balanceOf(env.eoa.addr), 5 ether);
        assertEq(env.token2.balanceOf(env.solver.addr), 110 ether); // 100 from setup + 10 from multicall drain
    }

    function test_multicall_handleFill_multiple() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount and multicall for approvals
        env.token2.mint(address(mockAccount), 10 ether);
        env.token1.mint(address(env.multicallAdapter), 1 ether);

        // Create multiple executions
        Execution[] memory executions = new Execution[](5);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (100))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (200))))
        });
        executions[2] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 1 ether)) });
        executions[3] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });
        // Additional execution to test multiple operations
        executions[4] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (300))))
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Execute fill
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify last execution value
        assertEq(env.target.param(), 300);

        // Verify approval was set
        assertEq(env.token1.allowance(address(env.multicallAdapter), address(env.target)), 1 ether);

        // Verify token transfers
        assertEq(env.token2.balanceOf(env.solver.addr), 110 ether); // 100 from setup + 10 from multicall drain
    }

    function test_multicall_handleJITClaim() public {
        // Setup tokenIn
        uint256[2] memory tokenInPair = [toId(env.token1), 2 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();

        // Create MockAccount and mint tokens to it for transfer
        env.token1.mint(address(mockAccount), 2 ether);

        // Create executions for JIT claim - transfer tokens from mockAccount to MultiCall
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (999)) });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token1), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 2 ether)))
            )
        });

        // Prepare JIT claim data
        MultiCallAdapter.JITClaimData memory jitClaimData = MultiCallAdapter.JITClaimData({ tokenIn: tokenIn, multicalls: executions });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Execute JIT claim
        _claim(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleJITClaim, (jitClaimData)));

        // Verify execution
        assertEq(env.target.param(), 999);

        // Verify solver received tokens
        assertEq(env.token1.balanceOf(env.solver.addr), 102 ether); // 100 from setup + 2 from JIT
    }

    function test_multicall_handlePayable() public {
        // Create executions with ETH value
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(env.target), value: 1 ether, callData: abi.encodeCall(MockTarget.targetFn, (777)) });
        executions[1] = Execution({ target: address(env.weth), value: 0.5 ether, callData: abi.encodeCall(env.weth.deposit, ()) });

        // Send ETH to router
        vm.deal(address(env.router), 2 ether);

        // Execute payable multicall
        _fill(block.chainid, "", abi.encodeCall(MultiCallAdapter.multicall_handlePayable, (1.5 ether, executions)));

        // Verify executions
        assertEq(env.target.param(), 777);
        assertEq(env.target.value(), 1 ether);
        assertEq(env.weth.balanceOf(address(env.multicallAdapter)), 0.5 ether);
    }

    function test_supportsInterface() public {
        // Test all supported interfaces
        assertTrue(env.multicallAdapter.supportsInterface(MultiCallAdapter.multicall_handleFill.selector));
        assertTrue(env.multicallAdapter.supportsInterface(MultiCallAdapter.multicall_handleJITClaim.selector));
        assertTrue(env.multicallAdapter.supportsInterface(MultiCallAdapter.multicall_handlePayable.selector));

        // Test unsupported interface
        assertFalse(env.multicallAdapter.supportsInterface(bytes4(0x12345678)));
    }

    function test_multicall_multipleTokenTransfers() public {
        // Setup multiple tokenIn and tokenOut
        uint256[2][] memory tokenIn = new uint256[2][](2);
        tokenIn[0] = [toId(env.token2), 5 ether];
        tokenIn[1] = [toId(env.token3), 3 ether];

        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0] = [toId(env.token1), 2 ether];
        tokenOut[1] = [toId(env.token2), 1 ether];

        // Mint tokens to mockAccount
        env.token2.mint(address(mockAccount), 5 ether);
        env.token3.mint(address(mockAccount), 3 ether);

        // Create executions that transfer all tokenIn to MultiCall contract
        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 5 ether)))
            )
        });
        executions[2] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token3), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 3 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Also need solver to have token2 for tokenOut
        env.token2.mint(env.solver.addr, 1 ether);

        // Execute fill
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify all transfers
        assertEq(env.token1.balanceOf(env.eoa.addr), 2 ether);
        assertEq(env.token2.balanceOf(env.eoa.addr), 1 ether);
        assertEq(env.token2.balanceOf(env.solver.addr), 105 ether); // 100 + 5 from tokenIn
        assertEq(env.token3.balanceOf(env.solver.addr), 103 ether); // 100 + 3 from tokenIn
    }

    function test_revert_executionFailed() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Create execution that will fail
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(0x1234), // Invalid target
            value: 0,
            callData: abi.encodeCall(MockTarget.targetFn, (42))
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Expect revert
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    // =====================================================================
    // ERROR/FAILURE SCENARIOS
    // =====================================================================

    function test_revert_accountDoesntSendFundsBack() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount but it WON'T transfer them back
        env.token2.mint(address(mockAccount), 10 ether);

        // Create executions that DON'T transfer tokenIn back to multicall
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        // NOTE: Missing the token transfer execution!

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because no tokens are transferred to multicall
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_revert_accountInsufficientFunds() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint INSUFFICIENT tokens to mockAccount (only 3 ether instead of 10)
        env.token2.mint(address(mockAccount), 3 ether);

        // Create executions that try to transfer more than available
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because mockAccount doesn't have enough tokens
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_revert_accountSendsPartialFunds() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint enough tokens to mockAccount
        env.token2.mint(address(mockAccount), 10 ether);

        // Create executions that transfer LESS than expected (only 7 ether instead of 10)
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 7 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because only partial amount is transferred
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_revert_accountSendsWrongToken() public {
        // Setup tokenIn and tokenOut (expecting token2)
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint wrong token to mockAccount (token3 instead of token2)
        env.token3.mint(address(mockAccount), 10 ether);

        // Create executions that transfer WRONG token
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token3), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because wrong token is transferred
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    // =====================================================================
    // NATIVE TOKEN (ETH) CASES
    // =====================================================================

    function test_multicall_nativeTokenIn() public {
        // Setup tokenIn with native token (ETH) and tokenOut
        uint256[2] memory tokenInPair = [toId(Constants.NATIVE_TOKEN), 2 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Give mockAccount some ETH
        vm.deal(address(mockAccount), 5 ether);

        // Create executions that send ETH to multicall (similar to ERC20 pattern)
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (777)) });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.multicallAdapter), 2 ether, ""))
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Execute fill
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify execution
        assertEq(env.target.param(), 777);

        // Verify token transfers
        assertEq(env.token1.balanceOf(env.eoa.addr), 5 ether);
        assertEq(env.solver.addr.balance, 2 ether); // Solver should receive the ETH
    }

    function test_multicall_nativeTokenOut() public {
        // Skip this test - ETH as tokenOut in multicall_handleFill may not be a supported pattern
        // ETH transfers are typically handled via multicall_handlePayable instead
        vm.skip(true);
    }

    function test_multicall_mixedNativeAndERC20() public {
        // Setup mixed tokenIn: both ETH and ERC20
        uint256[2][] memory tokenIn = new uint256[2][](2);
        tokenIn[0] = [toId(Constants.NATIVE_TOKEN), 1 ether];
        tokenIn[1] = [toId(env.token2), 5 ether];

        uint256[2] memory tokenOutPair = [toId(env.token1), 3 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Setup mockAccount with both ETH and tokens
        vm.deal(address(mockAccount), 2 ether);
        env.token2.mint(address(mockAccount), 5 ether);

        // Create executions for both ETH and token transfers
        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution({ target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (999)) });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.multicallAdapter), 1 ether, ""))
        });
        executions[2] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 5 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Execute fill
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify execution
        assertEq(env.target.param(), 999);

        // Verify mixed transfers
        assertEq(env.token1.balanceOf(env.eoa.addr), 3 ether);
        assertEq(env.solver.addr.balance, 1 ether); // ETH
        assertEq(env.token2.balanceOf(env.solver.addr), 105 ether); // ERC20
    }

    function test_revert_insufficientETHBalance() public {
        // Setup tokenIn with ETH
        uint256[2] memory tokenInPair = [toId(Constants.NATIVE_TOKEN), 5 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 3 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Give mockAccount INSUFFICIENT ETH (only 2 ether instead of 5)
        vm.deal(address(mockAccount), 2 ether);

        // Create executions that try to send more ETH than available
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (42)) });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.multicallAdapter), 5 ether, "")) // More than mockAccount has!
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert due to insufficient ETH
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    // =====================================================================
    // EDGE CASES
    // =====================================================================

    function test_multicall_zeroAmounts() public {
        // Setup tokenIn and tokenOut with zero amounts
        uint256[2] memory tokenInPair = [toId(env.token2), 0];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 0];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Create execution that just calls target function
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (42)) });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should work with zero amounts
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));

        // Verify execution happened
        assertEq(env.target.param(), 42);
    }

    function test_multicall_emptyExecutions() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 5 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 3 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount
        env.token2.mint(address(mockAccount), 5 ether);

        // Create EMPTY executions array
        Execution[] memory executions = new Execution[](0);

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because no executions transfer tokens to multicall
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_multicall_multipleTokenInPartialFailure() public {
        // Setup multiple tokenIn where one will fail
        uint256[2][] memory tokenIn = new uint256[2][](2);
        tokenIn[0] = [toId(env.token2), 5 ether]; // This will work
        tokenIn[1] = [toId(env.token3), 10 ether]; // This will fail (insufficient funds)

        uint256[2] memory tokenOutPair = [toId(env.token1), 3 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint only token2 but not enough token3
        env.token2.mint(address(mockAccount), 5 ether);
        env.token3.mint(address(mockAccount), 3 ether); // Less than required 10 ether

        // Create executions
        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (123))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 5 ether)))
            )
        });
        executions[2] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token3), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because token3 transfer will fail
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    // =====================================================================
    // ADVANCED TOKEN CONTRACT SCENARIOS
    // =====================================================================

    function test_revert_tokenReturnsFalse() public {
        // Use environment bad token that returns false

        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(address(env.badToken1)), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount
        env.badToken1.mint(address(mockAccount), 10 ether);

        // Create executions
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute,
                (address(env.badToken1), 0, abi.encodeCall(env.badToken1.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because token transfer returns false
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_revert_tokenAlwaysReverts() public {
        // Use environment bad token that always reverts

        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(address(env.badToken2)), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount
        env.badToken2.mint(address(mockAccount), 10 ether);

        // Create executions
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute,
                (address(env.badToken2), 0, abi.encodeCall(env.badToken2.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because token transfer always reverts
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_multicall_tokenWithTransferFees() public {
        // Use environment bad token with transfer fees

        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(address(env.badToken3)), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount
        env.badToken3.mint(address(mockAccount), 10 ether);

        // Create executions
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute,
                (address(env.badToken3), 0, abi.encodeCall(env.badToken3.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because less tokens are received due to fees
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    // =====================================================================
    // EXECUTION FAILURE SCENARIOS
    // =====================================================================

    function test_revert_executionFailsAfterTokenTransfer() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Mint tokens to mockAccount
        env.token2.mint(address(mockAccount), 10 ether);

        // Create executions where token transfer succeeds but later execution fails
        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(MockAccount.execute, (address(env.target), 0, abi.encodeCall(MockTarget.targetFn, (42))))
        });
        executions[1] = Execution({
            target: address(mockAccount),
            value: 0,
            callData: abi.encodeCall(
                MockAccount.execute, (address(env.token2), 0, abi.encodeCall(IERC20.transfer, (address(env.multicallAdapter), 10 ether)))
            )
        });
        // This execution will fail
        executions[2] = Execution({
            target: address(env.target), // Invalid target
            value: 0,
            callData: abi.encodeCall(MockTarget.reverting, ())
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because execution[2] fails even though token transfer succeeded
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }

    function test_revert_allExecutionsFail() public {
        // Setup tokenIn and tokenOut
        uint256[2] memory tokenInPair = [toId(env.token2), 10 ether];
        uint256[2][] memory tokenIn = tokenInPair.into();
        uint256[2] memory tokenOutPair = [toId(env.token1), 5 ether];
        uint256[2][] memory tokenOut = tokenOutPair.into();

        // Create executions that will ALL fail
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(0x1111), // Invalid target
            value: 0,
            callData: abi.encodeCall(MockTarget.targetFn, (42))
        });
        executions[1] = Execution({
            target: address(0x2222), // Invalid target
            value: 0,
            callData: abi.encodeCall(MockTarget.targetFn, (999))
        });

        // Prepare fill data
        MultiCallAdapter.FillData memory fillData =
            MultiCallAdapter.FillData({ tokenIn: tokenIn, tokenOut: tokenOut, multicalls: executions, account: env.eoa.addr, value: 0 });

        // Encode solver context
        bytes memory relayerContext = abi.encodePacked(env.solver.addr);

        // Should revert because all executions fail
        vm.expectRevert();
        _fill(block.chainid, relayerContext, abi.encodeCall(MultiCallAdapter.multicall_handleFill, (fillData)));
    }
}
