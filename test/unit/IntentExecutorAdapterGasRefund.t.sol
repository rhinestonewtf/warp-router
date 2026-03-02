// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CompactEnvironment } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { IntentExecutorAdapterGasRefund } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapterGasRefund.sol";
import { IStandaloneIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IStandaloneIntent.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";
import { TestHelperLib } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { EIP712Lib } from "@rhinestone/compact-utils/src/executor/StandaloneIntent/lib/EIP712Lib.sol";
import { IntentExecutor } from "@rhinestone/compact-utils/src/executor/IntentExecutor.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract StandaloneHashHelper is IntentExecutor {
    using EIP712Lib for IStandaloneIntentExecutor.MultiChainOps;
    using SmartExecutionLib for *;

    constructor(
        address router,
        address compact,
        address addressBook,
        address allocator
    )
        IntentExecutor(router, compact, allocator, addressBook, address(0))
    { }

    function hash(IStandaloneIntentExecutor.MultiChainOps calldata ops) external view returns (bytes32) {
        (bytes32 _hash,) = ops.hashAndDecode(EIP712Lib.NO_GASREFUND);
        return _hash;
    }

    function hashWithGasRefund(IStandaloneIntentExecutor.MultiChainOps calldata ops, bytes32 gasRefundHash)
        external
        view
        returns (bytes32)
    {
        (bytes32 _hash,) = ops.hashAndDecode(gasRefundHash);
        return _hash;
    }

    function getDigest(bytes32 hash) external view returns (bytes32) {
        return _hashTypedDataSansChainId(hash);
    }

    function getDigestWithChainId(bytes32 hash) external view returns (bytes32) {
        return _hashTypedData(hash);
    }
}

contract IntentExecutorAdapterGasRefundTest is CompactEnvironment {
    using AdapterTagLib for bytes12;
    using Types for Execution[];
    using TestHelperLib for *;

    IntentExecutorAdapterGasRefund adapter;
    StandaloneHashHelper hashHelper;

    function setUp() public {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);

        // Deploy the adapter
        adapter = new IntentExecutorAdapterGasRefund(address(env.router), address(env.intentExecutor));

        // Deploy hash helper
        hashHelper = new StandaloneHashHelper(address(env.router), address(env.compact), address(ADDRESSBOOK), address(env.allocator));

        // Install the adapter for gas refund selectors
        _setFillRoute(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund.selector, address(adapter));
        _setFillRoute(adapter.handleFill_intentExecutor_executeSinglechainOps_gasRefund.selector, address(adapter));

        // Fund accounts with tokens
        env.token1.mint(env.smartAccount1.account, 1000 ether);
        env.token2.mint(env.smartAccount1.account, 1000 ether);
    }

    function test_handleFill_executeMultichainOps_gasRefund() public {
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;
        address gasRefundRecipient = env.solver.addr;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        // Using max approval since gas is calculated dynamically based on actual usage
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        // Create operations
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 1,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // exchangeRate of 1e18 means 1:1 ratio (token amount = wei cost)
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token2BalanceBefore = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token2.balanceOf(gasRefundRecipient);

        // Prepare the adapter call - gas refund adapter requires 20 bytes relayer context (recipient address)
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund, (multichainOps, gasRefund));

        // Execute
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);

        console2.log("Gas used for multichain ops with gas refund:", gasUsed);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Gas is calculated dynamically based on actual gas used and exchange rate
        // Verify that gas was deducted from account and paid to recipient
        uint256 token2BalanceAfter = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token2.balanceOf(gasRefundRecipient);
        uint256 gasDeducted = token2BalanceBefore - token2BalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");
    }

    function test_handleFill_executeSinglechainOps_gasRefund() public {
        address account = env.smartAccount1.account;
        uint256 amount = 80 ether;
        address gasRefundRecipient = env.orchestrator.addr;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        // Using max approval since gas is calculated dynamically based on actual usage
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        // Create operations
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 2, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // exchangeRate of 1e18 means 1:1 ratio (token amount = wei cost)
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token2BalanceBefore = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token2.balanceOf(gasRefundRecipient);

        // Prepare the adapter call - gas refund adapter requires 20 bytes relayer context (recipient address)
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeSinglechainOps_gasRefund, (singlechainOps, gasRefund));

        // Execute
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);

        console2.log("Gas used for singlechain ops with gas refund:", gasUsed);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Gas is calculated dynamically based on actual gas used and exchange rate
        // Verify that gas was deducted from account and paid to recipient
        uint256 token2BalanceAfter = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token2.balanceOf(gasRefundRecipient);
        uint256 gasDeducted = token2BalanceBefore - token2BalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");
    }

    function test_supportsInterface() public view {
        assertTrue(adapter.supportsInterface(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund.selector));
        assertTrue(adapter.supportsInterface(adapter.handleFill_intentExecutor_executeSinglechainOps_gasRefund.selector));

        // Should not support random selector
        assertFalse(adapter.supportsInterface(bytes4(0x12345678)));
    }

    function test_adapterConfiguration() public view {
        // Verify the adapter was deployed with correct configuration
        assertEq(adapter._ROUTER(), address(env.router));
    }

    function test_revert_invalidRelayerContextLength() public {
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;
        uint256 gasAmount = 1 ether;

        // Setup
        vm.prank(account);
        env.token2.approve(address(env.paymaster), gasAmount);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 3,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: gasAmount, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // Prepare the adapter call with WRONG relayer context length (not 20 bytes)
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(uint256(123)); // 32 bytes instead of 20

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund, (multichainOps, gasRefund));

        // Should revert with InvalidRelayerContext
        vm.expectRevert();
        _fill(block.chainid, relayerContexts, adapterCalldatas);
    }

    function test_handleFill_executeMultichainOps_gasRefund_nativeETH() public {
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;
        address gasRefundRecipient = env.solver.addr;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        // Create operations (token transfer)
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 10,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Native ETH gas refund - token is NATIVE_TOKEN (address(0)), exchangeRate is 1e18 (1:1)
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 accountETHBefore = account.balance;
        uint256 recipientETHBefore = gasRefundRecipient.balance;

        // Prepare the adapter call - gas refund adapter requires 20 bytes relayer context (recipient address)
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund, (multichainOps, gasRefund));

        // Execute
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);

        console2.log("Gas used for multichain ops with native ETH gas refund:", gasUsed);

        // Verify token execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify ETH gas refund was transferred
        uint256 accountETHAfter = account.balance;
        uint256 recipientETHAfter = gasRefundRecipient.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = recipientETHAfter - recipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
    }

    function test_handleFill_executeSinglechainOps_gasRefund_nativeETH() public {
        address account = env.smartAccount1.account;
        uint256 amount = 80 ether;
        address gasRefundRecipient = env.orchestrator.addr;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        // Create operations (token transfer)
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 11, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Native ETH gas refund - token is NATIVE_TOKEN (address(0)), exchangeRate is 1e18 (1:1)
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 accountETHBefore = account.balance;
        uint256 recipientETHBefore = gasRefundRecipient.balance;

        // Prepare the adapter call - gas refund adapter requires 20 bytes relayer context (recipient address)
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeSinglechainOps_gasRefund, (singlechainOps, gasRefund));

        // Execute
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);

        console2.log("Gas used for singlechain ops with native ETH gas refund:", gasUsed);

        // Verify token execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify ETH gas refund was transferred
        uint256 accountETHAfter = account.balance;
        uint256 recipientETHAfter = gasRefundRecipient.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = recipientETHAfter - recipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
    }

    function test_handleFill_executeMultichainOps_gasRefund_nativeETH_withOverhead() public {
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        address gasRefundRecipient = env.solver.addr;
        uint256 overhead = 10_000; // 10k gas overhead

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        // Create operations (token transfer)
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 12,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Native ETH gas refund with overhead
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: overhead });

        // Sign with gas refund
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // Record balances before
        uint256 accountETHBefore = account.balance;
        uint256 recipientETHBefore = gasRefundRecipient.balance;

        // Prepare the adapter call
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeMultichainOps_gasRefund, (multichainOps, gasRefund));

        // Execute
        _fill(block.chainid, relayerContexts, adapterCalldatas);

        // Verify ETH gas refund was transferred (should include overhead)
        uint256 accountETHAfter = account.balance;
        uint256 recipientETHAfter = gasRefundRecipient.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = recipientETHAfter - recipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
        // The refund should include at least the overhead amount (overhead * gasPrice)
        assertGe(ethDeducted, overhead * tx.gasprice, "Refund should include overhead");
    }

    function test_handleFill_executeSinglechainOps_gasRefund_nativeETH_withOverhead() public {
        address account = env.smartAccount1.account;
        uint256 amount = 60 ether;
        address gasRefundRecipient = env.orchestrator.addr;
        uint256 overhead = 15_000; // 15k gas overhead

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        // Create operations (token transfer)
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 13, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Native ETH gas refund with overhead
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: overhead });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 accountETHBefore = account.balance;
        uint256 recipientETHBefore = gasRefundRecipient.balance;

        // Prepare the adapter call
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(gasRefundRecipient);

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_executeSinglechainOps_gasRefund, (singlechainOps, gasRefund));

        // Execute
        _fill(block.chainid, relayerContexts, adapterCalldatas);

        // Verify ETH gas refund was transferred (should include overhead)
        uint256 accountETHAfter = account.balance;
        uint256 recipientETHAfter = gasRefundRecipient.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = recipientETHAfter - recipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
        // The refund should include at least the overhead amount (overhead * gasPrice)
        assertGe(ethDeducted, overhead * tx.gasprice, "Refund should include overhead");
    }

    // Helper functions for signing with gas refund
    function _signMultichainOpsWithGasRefund(
        IStandaloneIntentExecutor.MultiChainOps memory multichainOps,
        IStandaloneIntentExecutor.GasRefund memory gasRefund
    )
        internal
        returns (bytes memory)
    {
        // Compute gas refund hash
        bytes32 gasRefundHash = hasher.hashGasRefund(gasRefund.token, gasRefund.exchangeRate, gasRefund.overhead);

        // Compute chain ops hash with gas refund using external call to convert memory to calldata
        bytes32 chainOpsHash = hasher.hashChainOps(block.chainid, multichainOps.nonce, multichainOps.ops, gasRefundHash);

        // Construct allChains array with just this chain
        bytes32[] memory allChains = new bytes32[](1);
        allChains[0] = chainOpsHash;

        // Compute multichain ops hash - need external call to pass calldata array
        bytes32 hash = this._hashMultiChainOpsExternal(multichainOps.account, allChains);

        // Get digest without chain ID (chain-agnostic signature)
        bytes32 digest = hashHelper.getDigest(hash);

        return abi.encodePacked(address(env.smartAccount1.defaultValidator), _signHash(env.eoa, digest));
    }

    function _signSinglechainOpsWithGasRefund(
        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps,
        IStandaloneIntentExecutor.GasRefund memory gasRefund
    )
        internal
        returns (bytes memory)
    {
        // Compute gas refund hash
        bytes32 gasRefundHash = hasher.hashGasRefund(gasRefund.token, gasRefund.exchangeRate, gasRefund.overhead);

        // Compute single chain ops hash using external call to convert memory to calldata
        bytes32 hash = hasher.hashSingleChainOps(singlechainOps.account, singlechainOps.nonce, singlechainOps.ops, gasRefundHash);

        // Get digest with chain ID (chain-specific signature for single chain)
        bytes32 digest = hashHelper.getDigestWithChainId(hash);

        return abi.encodePacked(address(env.smartAccount1.defaultValidator), _signHash(env.eoa, digest));
    }

    // External helper to convert memory array to calldata for hasher
    function _hashMultiChainOpsExternal(address account, bytes32[] memory allChains) external view returns (bytes32) {
        return hasher.hashMultiChainOps(account, allChains);
    }
}
