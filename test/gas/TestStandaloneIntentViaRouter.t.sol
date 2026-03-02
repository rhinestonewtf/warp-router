// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CompactEnvironment, TestHelperLib } from "../../src/tests/Environment.sol";
import { IStandaloneIntentExecutor } from "../../src/executor/interfaces/IStandaloneIntent.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Caller, ISingleCaller } from "../../src/router/utils/Caller.sol";
import { MockERC20 as Token } from "../../src/tests/MockERC20.sol";
import { Types } from "../../src/types/OrderTypes.sol";
import { Hasher } from "../../src/tests/Hasher.sol";
import { SmartExecutionLib } from "../../src/common/SmartExecutionLib.sol";
import { EIP712Lib } from "../../src/executor/StandaloneIntent/lib/EIP712Lib.sol";

/**
 * @title TestStandaloneIntentViaRouter
 * @notice Gas test comparing direct StandaloneIntentExecutor calls vs routing through the Router
 * @dev Uses the Caller.singleCall selector to route through the Router without needing an adapter
 */
contract TestStandaloneIntentViaRouter is CompactEnvironment {
    using TestHelperLib for *;

    uint256 private constant TEST_AMOUNT = 100 ether;

    function setUp() public {
        // Deploy the Compact environment with router and intent executor
        _deployCompact();
        _deploySmartAccount(true);
        _setEmissary(env.smartAccount1, env.eoa);

        // Fund the smart account with tokens
        env.token1.mint(env.smartAccount1.account, TEST_AMOUNT * 10);

        // Fund solver with tokens for potential transfers
        env.token1.mint(env.solver.addr, TEST_AMOUNT * 10);

        // Approve router from solver
        vm.startPrank(env.solver.addr);
        env.token1.approve(address(env.router), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice Helper to create a simple ERC20 transfer MultiChainOps
     */
    function _createSimpleTransferOps(uint256 nonce, uint256 amount)
        internal
        view
        returns (IStandaloneIntentExecutor.MultiChainOps memory)
    {
        address account = env.smartAccount1.account;

        // Create a single ERC20 transfer operation
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        return IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: nonce,
            ops: ops.toOperation(3),
            signature: "" // Will be filled later
        });
    }

    /**
     * @notice Helper to sign MultiChainOps
     */
    function _signMultiChainOps(IStandaloneIntentExecutor.MultiChainOps memory multichainOps) internal view returns (bytes memory) {
        // Call our helper to get the hash
        bytes32 hash = this.hashMultiChainOps(multichainOps);

        // Get EIP-712 digest (chain-agnostic)
        // Since _hashTypedDataSansChainId uses domain separator but without chain id, we need to replicate that
        // For chain-agnostic, it typically just signs the raw hash
        bytes32 digest = hash;

        // Sign with the account's validator
        return abi.encodePacked(address(env.smartAccount1.defaultValidator), _signHash(env.eoa, digest));
    }

    function hashMultiChainOps(IStandaloneIntentExecutor.MultiChainOps calldata multichainOps) external view returns (bytes32) {
        (bytes32 hash,) = EIP712Lib.hashAndDecode(multichainOps, EIP712Lib.NO_GASREFUND);
        return hash;
    }

    function _hashOperations(Types.Operation memory ops) internal view returns (bytes32) {
        // Decode the operations
        Execution[] memory execs = this.decodeExecutions(ops);

        // Use the inherited hasher instance to hash operations
        return hasher.hashOps(execs);
    }

    function decodeExecutions(Types.Operation calldata ops) public pure returns (Execution[] memory execs) {
        (, execs) = SmartExecutionLib.decode(ops);
    }

    function _hashExecutions(Execution[] memory execs) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](execs.length);
        for (uint256 i = 0; i < execs.length; i++) {
            hashes[i] = keccak256(
                abi.encode(
                    keccak256("Execution(address target,uint256 value,bytes callData)"),
                    execs[i].target,
                    execs[i].value,
                    keccak256(execs[i].callData)
                )
            );
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /**
     * @notice Use routeClaim to route the call through the router (non-array implementation)
     */
    function _routeClaimWithSingleCall(bytes memory adapterCalldata) internal returns (uint256 gas) {
        // Empty solver context since singleCall doesn't consume any
        bytes memory emptyrelayerContext = "";

        vm.prank(env.solver.addr);
        gas = gasleft();
        env.router.routeClaim(emptyrelayerContext, adapterCalldata);
        gas = gas - gasleft();
    }

    /**
     * @notice Test gas usage for a simple ERC20 transfer via StandaloneIntentExecutor routed through Router
     */
    function test_SimpleERC20TransferViaRouter() public {
        uint256 nonce = 1;
        uint256 amount = 10 ether;

        console2.log("\n=== Simple ERC20 Transfer via Router ===");
        console2.log("Transfer amount:", amount);

        // Create and sign MultiChainOps for a simple transfer
        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = _createSimpleTransferOps(nonce, amount);
        multichainOps.signature = _signMultiChainOps(multichainOps);

        // Encode the call to IntentExecutor.executeMultichainOps
        bytes memory executeCalldata = abi.encodeCall(IStandaloneIntentExecutor.executeMultichainOps, multichainOps);

        // Wrap in Caller.singleCall selector
        // The Caller fallback expects: first 20 bytes = target address, rest = calldata
        // So we need: selector + packed(address) + executeCalldata
        bytes memory adapterCalldata = bytes.concat(
            abi.encodePacked(ISingleCaller.singleCall.selector), abi.encodePacked(address(env.intentExecutor)), executeCalldata
        );

        // Record balance before
        uint256 solverBalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 accountBalanceBefore = env.token1.balanceOf(env.smartAccount1.account);

        console2.log("Solver balance before:", solverBalanceBefore);
        console2.log("Account balance before:", accountBalanceBefore);

        // Execute through router using routeClaim
        uint256 gasUsed = _routeClaimWithSingleCall(adapterCalldata);

        // Verify execution
        uint256 solverBalanceAfter = env.token1.balanceOf(env.solver.addr);
        uint256 accountBalanceAfter = env.token1.balanceOf(env.smartAccount1.account);

        console2.log("Solver balance after:", solverBalanceAfter);
        console2.log("Account balance after:", accountBalanceAfter);

        assertEq(solverBalanceAfter, solverBalanceBefore + amount, "Solver should receive tokens");
        assertEq(accountBalanceAfter, accountBalanceBefore - amount, "Account should send tokens");

        console2.log("\nGas used for routed ERC20 transfer:", gasUsed);
        console2.log("================================\n");
    }

    /**
     * @notice Test direct call for comparison
     */
    function test_DirectERC20Transfer() public {
        uint256 nonce = 2;
        uint256 amount = 10 ether;

        console2.log("\n=== Direct ERC20 Transfer ===");
        console2.log("Transfer amount:", amount);

        // Create and sign MultiChainOps
        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = _createSimpleTransferOps(nonce, amount);
        multichainOps.signature = _signMultiChainOps(multichainOps);

        // Record balance before
        uint256 solverBalanceBefore = env.token1.balanceOf(env.solver.addr);

        // Measure gas for direct call
        uint256 gasStart = gasleft();
        env.intentExecutor.executeMultichainOps(multichainOps);
        uint256 gasUsed = gasStart - gasleft();

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), solverBalanceBefore + amount);

        console2.log("Gas used for direct ERC20 transfer:", gasUsed);
        console2.log("================================\n");
    }

    /**
     * @notice Compare both methods
     */
    function test_CompareGasUsage() public {
        console2.log("\n=== Gas Comparison: Direct vs Routed ===");

        // Direct call
        uint256 directNonce = 3;
        IStandaloneIntentExecutor.MultiChainOps memory directOps = _createSimpleTransferOps(directNonce, 10 ether);
        directOps.signature = _signMultiChainOps(directOps);
        console2.log("here");

        uint256 directGasStart = gasleft();
        env.intentExecutor.executeMultichainOps(directOps);
        uint256 directGasUsed = directGasStart - gasleft();

        // Routed call
        uint256 routedNonce = 4;
        IStandaloneIntentExecutor.MultiChainOps memory routedOps = _createSimpleTransferOps(routedNonce, 10 ether);
        routedOps.signature = _signMultiChainOps(routedOps);

        bytes memory executeCalldata = abi.encodeCall(IStandaloneIntentExecutor.executeMultichainOps, routedOps);
        bytes memory adapterCalldata = bytes.concat(
            abi.encodePacked(ISingleCaller.singleCall.selector), abi.encodePacked(address(env.intentExecutor)), executeCalldata
        );

        uint256 routedGasUsed = _routeClaimWithSingleCall(adapterCalldata);

        // Display results
        console2.log("Direct call gas:        ", directGasUsed);
        console2.log("Routed call gas:        ", routedGasUsed);

        if (routedGasUsed > directGasUsed) {
            uint256 overhead = routedGasUsed - directGasUsed;
            uint256 overheadPercent = (overhead * 100) / directGasUsed;
            console2.log("Routing overhead:       ", overhead, "gas");
            console2.log("Overhead percentage:    ", overheadPercent, "%");
        } else {
            uint256 savings = directGasUsed - routedGasUsed;
            uint256 savingsPercent = (savings * 100) / directGasUsed;
            console2.log("Routing saved:          ", savings, "gas");
            console2.log("Savings percentage:     ", savingsPercent, "%");
        }
        console2.log("================================\n");
    }
}
