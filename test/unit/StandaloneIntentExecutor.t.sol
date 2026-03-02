// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IStandaloneIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IStandaloneIntent.sol";
import { ConsumeNonceLib } from "@rhinestone/compact-utils/src/executor/lib/ConsumeNonceLib.sol";
import { CompactEnvironment } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { EIP712Lib } from "@rhinestone/compact-utils/src/executor/StandaloneIntent/lib/EIP712Lib.sol";
import { IntentExecutor } from "@rhinestone/compact-utils/src/executor/IntentExecutor.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { ValidateSignature } from "@rhinestone/compact-utils/src/executor/VerifySignature/VerifySignature.sol";
import { IntentExecutorBase } from "@rhinestone/compact-utils/src/executor/IntentExecutorBase.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Hasher } from "@rhinestone/compact-utils/src/tests/Hasher.sol";

contract StandaloneIntentHashHelper is IntentExecutor {
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

    function hashChainOps(uint256 chainId, uint256 nonce, Execution[] calldata ops) external view returns (bytes32) {
        Types.Operation memory operation = SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops);
        return this.hashChainOpsWithOp(chainId, nonce, operation);
    }

    function hashChainOpsWithOp(uint256 chainId, uint256 nonce, Types.Operation calldata ops) external pure returns (bytes32) {
        return EIP712Lib.hashChainOps(chainId, nonce, ops, EIP712Lib.NO_GASREFUND);
    }

    function getDigest(bytes32 hash) external view returns (bytes32) {
        return _hashTypedDataSansChainId(hash);
    }
}

contract MockAccount {
    function execute(address target, uint256 value, bytes calldata callData) external payable {
        (bool success,) = target.call{ value: value }(callData);
        require(success, "MockAccount: execution failed");
    }

    receive() external payable { }
}

contract StandaloneIntentExecutorTest is CompactEnvironment {
    using ModuleKitHelpers for *;
    using EIP712Lib for IStandaloneIntentExecutor.MultiChainOps;

    StandaloneIntentHashHelper hashHelper;

    function setUp() public {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);
        _setEmissary(env.smartAccount2, env.orchestrator);

        // Deploy hash helper
        hashHelper = new StandaloneIntentHashHelper(address(env.router), address(env.compact), address(ADDRESSBOOK), address(env.allocator));

        // Fund accounts with tokens
        env.token1.mint(env.smartAccount1.account, 1000 ether);
        env.token2.mint(env.smartAccount1.account, 1000 ether);
        env.token3.mint(env.smartAccount1.account, 1000 ether);

        env.token1.mint(env.smartAccount2.account, 1000 ether);
        env.token2.mint(env.smartAccount2.account, 1000 ether);
        env.token3.mint(env.smartAccount2.account, 1000 ether);
    }

    function test_executeMultichainOps_singleOperation() public {
        // Test single operation execution
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

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

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        // Record balances before
        uint256 balanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 accountBalanceBefore = env.token1.balanceOf(account);

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(1, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), balanceBefore + amount);
        assertEq(env.token1.balanceOf(account), accountBalanceBefore - amount);

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(1, account), "Nonce should be consumed after execution");
    }

    function test_executeMultichainOps_batchOperations() public {
        // Test batch operations execution
        address account = env.smartAccount1.account;
        uint256 amount1 = 50 ether;
        uint256 amount2 = 75 ether;

        Execution[] memory ops = new Execution[](3);
        ops[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), amount1)) });
        ops[1] = Execution({
            target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.deposit, (IERC20(address(env.token1)), amount1))
        });
        ops[2] = Execution({ target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount2)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 2,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(account);
        uint256 targetToken1BalanceBefore = env.token1.balanceOf(address(env.target));
        uint256 token2BalanceBefore = env.token2.balanceOf(env.solver.addr);

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(2, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify executions
        // Token1 was transferred to the target via deposit
        assertEq(env.token1.balanceOf(account), token1BalanceBefore - amount1);
        assertEq(env.token1.balanceOf(address(env.target)), targetToken1BalanceBefore + amount1);
        // Token2 was transferred to the solver
        assertEq(env.token2.balanceOf(env.solver.addr), token2BalanceBefore + amount2);

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(2, account), "Nonce should be consumed after execution");
    }

    function test_executeMultichainOps_multiChainSetup() public {
        // Test multichain operation setup
        address account = env.smartAccount1.account;
        uint256 nonce = 3;

        // Chain 1 operations
        Execution[] memory chain1Ops = new Execution[](1);
        chain1Ops[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, 10 ether)) });

        // Chain 2 operations
        Execution[] memory chain2Ops = new Execution[](1);
        chain2Ops[0] = Execution({
            target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.orchestrator.addr, 20 ether))
        });

        // Hash operations for each chain
        bytes32 chain1Hash = hashHelper.hashChainOps(chains.originChain1, nonce, chain1Ops);
        bytes32 chain2Hash = hashHelper.hashChainOps(chains.originChain2, nonce, chain2Ops);

        // Current chain operations
        Execution[] memory currentChainOps = new Execution[](1);
        currentChainOps[0] = Execution({
            target: address(env.token3), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.atomicFillSigner.addr, 30 ether))
        });

        bytes32[] memory otherChains = new bytes32[](2);
        otherChains[0] = chain1Hash;
        otherChains[1] = chain2Hash;

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 2, // Current chain is at index 2
            otherChains: otherChains,
            nonce: nonce,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, currentChainOps),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        // Prank to router
        vm.prank(address(env.router));

        // Execute current chain operations
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify execution
        assertEq(env.token3.balanceOf(env.atomicFillSigner.addr), 30 ether);
    }

    function test_executeMultichainOps_revertInvalidSignature() public {
        address account = env.smartAccount1.account;

        Execution[] memory ops = new Execution[](1);
        ops[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, 100 ether)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 4,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash with correct account
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);

        // Create a signature with wrong validator address
        multichainOps.signature = abi.encodePacked(address(0xdead), _signHash(env.eoa, digest));

        // Prank to router
        vm.prank(address(env.router));

        // Should revert with InvalidSignature error
        vm.expectRevert(ValidateSignature.InvalidSignature.selector);
        env.intentExecutor.executeMultichainOps(multichainOps);
    }

    function test_executeMultichainOps_revertNonceReuse() public {
        address account = env.smartAccount1.account;
        uint256 nonce = 5;

        Execution[] memory ops = new Execution[](1);
        ops[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, 50 ether)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: nonce,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(nonce, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute first time - should succeed
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(nonce, account), "Nonce should be consumed after execution");

        // Try to execute again with same nonce - should revert
        // Note: The error may not be NonceAlreadyUsed if the signature validation fails first
        // For now, just check that it reverts
        vm.expectRevert();
        env.intentExecutor.executeMultichainOps(multichainOps);
    }

    function test_executeMultichainOps_withETHTransfer() public {
        address account = env.smartAccount1.account;

        // Fund account with ETH
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: env.solver.addr, value: 1 ether, callData: "" });
        ops[1] = Execution({ target: address(env.target), value: 0.5 ether, callData: abi.encodeCall(MockTarget.targetFn, (12_345)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 6,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        uint256 solverBalanceBefore = env.solver.addr.balance;
        uint256 targetBalanceBefore = address(env.target).balance;

        // Prank to router
        vm.prank(address(env.router));

        // Execute
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify ETH transfers
        assertEq(env.solver.addr.balance, solverBalanceBefore + 1 ether);
        assertEq(address(env.target).balance, targetBalanceBefore + 0.5 ether);
    }

    function test_executeMultichainOps_differentAccounts() public {
        // Test operations from different accounts
        uint256 amount1 = 25 ether;
        uint256 amount2 = 35 ether;

        // Account 1 operations
        Execution[] memory ops1 = new Execution[](1);
        ops1[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount1)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps1 = IStandaloneIntentExecutor.MultiChainOps({
            account: env.smartAccount1.account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 7,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops1),
            signature: ""
        });

        // Account 2 operations
        Execution[] memory ops2 = new Execution[](1);
        ops2[0] = Execution({
            target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.orchestrator.addr, amount2))
        });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps2 = IStandaloneIntentExecutor.MultiChainOps({
            account: env.smartAccount2.account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 1,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops2),
            signature: ""
        });

        // Hash and sign for account 1
        bytes32 hash1 = hashHelper.hash(multichainOps1);
        bytes32 digest1 = _hashTypedDataSansChainId(hash1);
        multichainOps1.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest1));

        // Hash and sign for account 2
        bytes32 hash2 = hashHelper.hash(multichainOps2);
        bytes32 digest2 = _hashTypedDataSansChainId(hash2);
        multichainOps2.signature = abi.encodePacked(address(env.smartAccount2.defaultValidator), _signHash(env.orchestrator, digest2));

        // Record balances before
        uint256 solverToken1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 orchestratorToken2BalanceBefore = env.token2.balanceOf(env.orchestrator.addr);

        // Execute both
        env.intentExecutor.executeMultichainOps(multichainOps1);
        env.intentExecutor.executeMultichainOps(multichainOps2);

        // Verify executions
        assertEq(env.token1.balanceOf(env.solver.addr), solverToken1BalanceBefore + amount1);
        assertEq(env.token2.balanceOf(env.orchestrator.addr), orchestratorToken2BalanceBefore + amount2);
    }

    function testFuzz_executeMultichainOps_variousAmounts(uint256 amount) public {
        amount = bound(amount, 1 ether, 100 ether);
        address account = env.smartAccount1.account;

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 100 + amount, // Unique nonce based on amount
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        uint256 balanceBefore = env.token1.balanceOf(env.solver.addr);

        // Prank to router
        vm.prank(address(env.router));

        // Execute
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify
        assertEq(env.token1.balanceOf(env.solver.addr), balanceBefore + amount);
    }

    function testFuzz_executeMultichainOps_multipleOperations(uint8 numOps) public {
        numOps = uint8(bound(numOps, 1, 10));
        address account = env.smartAccount1.account;

        Execution[] memory ops = new Execution[](numOps);
        uint256 totalAmount = 0;

        for (uint8 i = 0; i < numOps; i++) {
            uint256 amount = uint256(i + 1) * 1 ether;
            totalAmount += amount;
            ops[i] = Execution({
                target: address(env.token1),
                value: 0,
                callData: abi.encodeCall(IERC20.transfer, (address(uint160(env.solver.addr) + i), amount))
            });
        }

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 1000 + numOps,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Hash and sign
        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        uint256 accountBalanceBefore = env.token1.balanceOf(account);

        // Prank to router
        vm.prank(address(env.router));

        // Execute
        env.intentExecutor.executeMultichainOps(multichainOps);

        // Verify total amount transferred
        assertEq(env.token1.balanceOf(account), accountBalanceBefore - totalAmount);
    }

    function test_executeMultichainOps_emptyOperations() public {
        address account = env.smartAccount1.account;

        Execution[] memory ops = new Execution[](0);

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 51,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        vm.prank(address(env.router));
        env.intentExecutor.executeMultichainOps(multichainOps);

        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(51, account), "Nonce should be consumed even with empty ops");
    }

    function test_executeMultichainOps_revertOnFailedExecution() public {
        address account = env.smartAccount1.account;

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({
            target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, 10_000 ether))
        });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 53,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        bytes32 hash = hashHelper.hash(multichainOps);
        bytes32 digest = _hashTypedDataSansChainId(hash);
        multichainOps.signature = abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));

        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeMultichainOps(multichainOps);

        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(53, account), "Nonce should not be consumed on failed execution");
    }

    function test_executeMultichainOps_withGasRefund() public {
        // Test multichain ops with gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        // Using max approval since gas is calculated dynamically based on actual usage
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 60,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund - using helper to get proper hash
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token2BalanceBefore = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token2.balanceOf(env.atomicFillSigner.addr);

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(60, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ERC20 variant)
        env.intentExecutor.executeMultichainOpsWithGasRefund_ERC20(multichainOps, gasRefund, env.atomicFillSigner.addr);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Gas is now calculated dynamically based on actual gas used and exchange rate
        // Verify that gas was deducted from account and paid to recipient
        uint256 token2BalanceAfter = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token2.balanceOf(env.atomicFillSigner.addr);
        uint256 gasDeducted = token2BalanceBefore - token2BalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(60, account), "Nonce should be consumed after execution");
    }

    function test_executeSinglechainOps_withGasRefund() public {
        // Test single chain ops with gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 80 ether;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        // Using max approval since gas is calculated dynamically based on actual usage
        vm.prank(account);
        env.token3.approve(address(env.paymaster), type(uint256).max);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 71, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token3), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token3BalanceBefore = env.token3.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token3.balanceOf(env.orchestrator.addr);

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(71, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ERC20 variant)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.orchestrator.addr);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Gas is now calculated dynamically based on actual gas used and exchange rate
        // Verify that gas was deducted from account and paid to recipient
        uint256 token3BalanceAfter = env.token3.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token3.balanceOf(env.orchestrator.addr);
        uint256 gasDeducted = token3BalanceBefore - token3BalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(71, account), "Nonce should be consumed after execution");
    }

    function test_executeSinglechainOps_batchWithGasRefund() public {
        // Test single chain batch operations with gas refund
        address account = env.smartAccount1.account;
        uint256 amount1 = 50 ether;
        uint256 amount2 = 30 ether;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        // Using max approval since gas is calculated dynamically based on actual usage
        vm.prank(account);
        env.token1.approve(address(env.paymaster), type(uint256).max);

        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount1)) });
        ops[1] = Execution({ target: address(env.token3), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount2)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 72, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token1), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token2BalanceBefore = env.token2.balanceOf(env.solver.addr);
        uint256 token3BalanceBefore = env.token3.balanceOf(env.solver.addr);
        uint256 gasTokenBalanceBefore = env.token1.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token1.balanceOf(env.atomicFillSigner.addr);

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ERC20 variant)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.atomicFillSigner.addr);

        // Verify executions
        assertEq(env.token2.balanceOf(env.solver.addr), token2BalanceBefore + amount1, "Token2 transfer should succeed");
        assertEq(env.token3.balanceOf(env.solver.addr), token3BalanceBefore + amount2, "Token3 transfer should succeed");

        // Gas is now calculated dynamically based on actual gas used and exchange rate
        // Verify that gas was deducted from account and paid to recipient
        uint256 gasTokenBalanceAfter = env.token1.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token1.balanceOf(env.atomicFillSigner.addr);
        uint256 gasDeducted = gasTokenBalanceBefore - gasTokenBalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");
    }

    function test_executeMultichainOps_withGasRefund_ETH() public {
        // Test multichain ops with native ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 61,
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
        uint256 refundRecipientETHBefore = env.atomicFillSigner.addr.balance;

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(61, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ETH variant)
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify ETH gas refund was transferred
        uint256 accountETHAfter = account.balance;
        uint256 refundRecipientETHAfter = env.atomicFillSigner.addr.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = refundRecipientETHAfter - refundRecipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(61, account), "Nonce should be consumed after execution");
    }

    function test_executeSinglechainOps_withGasRefund_ETH() public {
        // Test single chain ops with native ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 80 ether;

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 73, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Native ETH gas refund - token is NATIVE_TOKEN (address(0)), exchangeRate is 1e18 (1:1)
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 accountETHBefore = account.balance;
        uint256 refundRecipientETHBefore = env.orchestrator.addr.balance;

        // Verify nonce is not consumed before execution
        assertFalse(env.intentExecutor.isStandaloneIntentNonceConsumed(73, account), "Nonce should not be consumed before execution");

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ETH variant)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);

        // Verify execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify ETH gas refund was transferred
        uint256 accountETHAfter = account.balance;
        uint256 refundRecipientETHAfter = env.orchestrator.addr.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = refundRecipientETHAfter - refundRecipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");

        // Verify nonce is consumed after execution
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(73, account), "Nonce should be consumed after execution");
    }

    function test_executeMultichainOps_withGasRefund_ETH_withOverhead() public {
        // Test multichain ops with native ETH gas refund and overhead
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 overhead = 10_000; // 10k gas overhead

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 62,
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
        uint256 refundRecipientETHBefore = env.atomicFillSigner.addr.balance;

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ETH variant)
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);

        // Verify ETH gas refund was transferred (should include overhead)
        uint256 accountETHAfter = account.balance;
        uint256 refundRecipientETHAfter = env.atomicFillSigner.addr.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = refundRecipientETHAfter - refundRecipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
        // The refund should include at least the overhead amount (overhead * gasPrice)
        assertGe(ethDeducted, overhead * tx.gasprice, "Refund should include overhead");
    }

    function test_executeSinglechainOps_withGasRefund_ETH_withOverhead() public {
        // Test single chain ops with native ETH gas refund and overhead
        address account = env.smartAccount1.account;
        uint256 amount = 60 ether;
        uint256 overhead = 15_000; // 15k gas overhead

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 74, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Native ETH gas refund with overhead
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: overhead });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 accountETHBefore = account.balance;
        uint256 refundRecipientETHBefore = env.orchestrator.addr.balance;

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ETH variant)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);

        // Verify ETH gas refund was transferred (should include overhead)
        uint256 accountETHAfter = account.balance;
        uint256 refundRecipientETHAfter = env.orchestrator.addr.balance;
        uint256 ethDeducted = accountETHBefore - accountETHAfter;
        uint256 ethReceived = refundRecipientETHAfter - refundRecipientETHBefore;

        assertGt(ethDeducted, 0, "ETH should be deducted from account for gas refund");
        assertEq(ethDeducted, ethReceived, "ETH deducted should equal ETH received by recipient");
        // The refund should include at least the overhead amount (overhead * gasPrice)
        assertGe(ethDeducted, overhead * tx.gasprice, "Refund should include overhead");
    }

    function test_revert_executeMultichainOpsWithGasRefund_ERC20_withNativeToken() public {
        // Test that ERC20 variant reverts when native token is used
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set gas price
        vm.txGasPrice(50 gwei);

        // Fund account with ETH
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 63,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Try to use native token with ERC20 variant - should revert
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        vm.prank(address(env.router));
        vm.expectRevert(IStandaloneIntentExecutor.InvalidGasToken.selector);
        env.intentExecutor.executeMultichainOpsWithGasRefund_ERC20(multichainOps, gasRefund, env.atomicFillSigner.addr);
    }

    function test_revert_executeSinglechainOpsWithGasRefund_ERC20_withNativeToken() public {
        // Test that ERC20 variant reverts when native token is used
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set gas price
        vm.txGasPrice(50 gwei);

        // Fund account with ETH
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 75, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Try to use native token with ERC20 variant - should revert
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        vm.prank(address(env.router));
        vm.expectRevert(IStandaloneIntentExecutor.InvalidGasToken.selector);
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.orchestrator.addr);
    }

    function test_executeMultichainOps_withGasRefund_ETH_zeroOverhead() public {
        // Test that zero overhead works correctly - only base gas cost is charged
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set gas price
        vm.txGasPrice(50 gwei);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 64,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Zero overhead
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        uint256 accountETHBefore = account.balance;

        vm.prank(address(env.router));
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, 0, env.atomicFillSigner.addr);

        uint256 ethDeducted = accountETHBefore - account.balance;
        // With zero overhead, the gas refund should only include the actual gas used
        assertGt(ethDeducted, 0, "Gas refund should be non-zero even with zero overhead");
    }

    function test_revert_executeMultichainOps_withGasRefund_ETH_insufficientETH() public {
        // Test that execution reverts when account has insufficient ETH for gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set high gas price to make refund expensive
        vm.txGasPrice(1000 gwei);

        // Fund account with very little ETH (not enough for gas refund)
        vm.deal(account, 0.0001 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 65,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        vm.prank(address(env.router));
        // Should revert due to insufficient ETH balance
        vm.expectRevert();
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, 0, env.atomicFillSigner.addr);
    }

    function test_revert_executeSinglechainOps_withGasRefund_ETH_insufficientETH() public {
        // Test that execution reverts when account has insufficient ETH for gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        // Set high gas price to make refund expensive
        vm.txGasPrice(1000 gwei);

        // Fund account with very little ETH (not enough for gas refund)
        vm.deal(account, 0.0001 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 76, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        vm.prank(address(env.router));
        // Should revert due to insufficient ETH balance
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, 0, env.orchestrator.addr);
    }

    // ============================================
    // Execution Emissary Mode Tests (Paymaster callback path)
    // ============================================

    function test_executeSinglechainOps_withGasRefund_ERC20_executionEmissary() public {
        // Test execution emissary mode with ERC20 gas refund
        // This mode requires Paymaster.callbackAllowMaxAmount to be called during execution
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 maxGasRefund = 10 ether; // Max gas refund the account authorizes

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Setup: Account needs to approve Paymaster to spend gas tokens
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        // Operations include:
        // 1. Token transfer (the actual intent)
        // 2. callbackAllowMaxAmount to authorize gas refund (required for execution emissary mode)
        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });
        ops[1] = Execution({
            target: address(env.paymaster),
            value: 0,
            callData: abi.encodeWithSignature("callbackAllowMaxAmount(address,uint256)", address(env.token2), maxGasRefund)
        });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 300, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token2BalanceBefore = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token2.balanceOf(env.orchestrator.addr);

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ERC20 variant - execution emissary mode uses settleGasRefund_requireCallback)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.orchestrator.addr);

        // Verify token execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify gas refund was paid
        uint256 token2BalanceAfter = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceAfter = env.token2.balanceOf(env.orchestrator.addr);
        uint256 gasDeducted = token2BalanceBefore - token2BalanceAfter;
        uint256 gasReceived = refundRecipientBalanceAfter - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");
        assertLe(gasDeducted, maxGasRefund, "Gas refund should not exceed max authorized amount");
    }

    function test_executeSinglechainOps_withGasRefund_ETH_executionEmissary() public {
        // Test execution emissary mode with native ETH gas refund
        // This mode requires Paymaster.callbackAllowMaxAmount to be called during execution
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 maxGasRefund = 1 ether; // Max gas refund the account authorizes

        // Set gas price for dynamic gas calculation (50 gwei)
        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Fund account with ETH for gas refund
        vm.deal(account, 10 ether);

        // Operations include:
        // 1. Token transfer (the actual intent)
        // 2. callbackAllowMaxAmount with ETH value to deposit + authorize gas refund
        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });
        ops[1] = Execution({
            target: address(env.paymaster),
            value: maxGasRefund, // Send ETH with the call to deposit into Paymaster
            callData: abi.encodeWithSignature("callbackAllowMaxAmount(address,uint256)", address(0), maxGasRefund)
        });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 301, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops), signature: ""
        });

        // Native ETH gas refund
        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with gas refund
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Record balances before
        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 refundRecipientETHBefore = env.orchestrator.addr.balance;

        // Prank to router
        vm.prank(address(env.router));

        // Execute with gas refund (ETH variant - execution emissary mode uses settleGasRefund_requireCallback)
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);

        // Verify token execution
        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        // Verify ETH gas refund was paid
        uint256 refundRecipientETHAfter = env.orchestrator.addr.balance;
        uint256 ethReceived = refundRecipientETHAfter - refundRecipientETHBefore;

        assertGt(ethReceived, 0, "ETH gas refund should be paid to recipient");
        assertLe(ethReceived, maxGasRefund, "Gas refund should not exceed max authorized amount");
    }

    function test_executeMultichainOps_withGasRefund_ERC20_executionEmissary() public {
        // Test execution emissary mode with ERC20 gas refund for multichain ops
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 maxGasRefund = 10 ether;

        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Setup token approval
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });
        ops[1] = Execution({
            target: address(env.paymaster),
            value: 0,
            callData: abi.encodeWithSignature("callbackAllowMaxAmount(address,uint256)", address(env.token2), maxGasRefund)
        });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 302,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 token2BalanceBefore = env.token2.balanceOf(account);
        uint256 refundRecipientBalanceBefore = env.token2.balanceOf(env.atomicFillSigner.addr);

        vm.prank(address(env.router));
        env.intentExecutor.executeMultichainOpsWithGasRefund_ERC20(multichainOps, gasRefund, env.atomicFillSigner.addr);

        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        uint256 gasDeducted = token2BalanceBefore - env.token2.balanceOf(account);
        uint256 gasReceived = env.token2.balanceOf(env.atomicFillSigner.addr) - refundRecipientBalanceBefore;

        assertGt(gasDeducted, 0, "Gas token should be deducted from account");
        assertEq(gasDeducted, gasReceived, "Gas deducted should equal gas received by recipient");
        assertLe(gasDeducted, maxGasRefund, "Gas refund should not exceed max authorized amount");
    }

    function test_executeMultichainOps_withGasRefund_ETH_executionEmissary() public {
        // Test execution emissary mode with native ETH gas refund for multichain ops
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 maxGasRefund = 1 ether;

        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Fund account with ETH
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });
        ops[1] = Execution({
            target: address(env.paymaster),
            value: maxGasRefund,
            callData: abi.encodeWithSignature("callbackAllowMaxAmount(address,uint256)", address(0), maxGasRefund)
        });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 303,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        uint256 token1BalanceBefore = env.token1.balanceOf(env.solver.addr);
        uint256 refundRecipientETHBefore = env.atomicFillSigner.addr.balance;

        vm.prank(address(env.router));
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);

        assertEq(env.token1.balanceOf(env.solver.addr), token1BalanceBefore + amount, "Token transfer should succeed");

        uint256 ethReceived = env.atomicFillSigner.addr.balance - refundRecipientETHBefore;

        assertGt(ethReceived, 0, "ETH gas refund should be paid to recipient");
        assertLe(ethReceived, maxGasRefund, "Gas refund should not exceed max authorized amount");
    }

    // ============================================
    // Revert / Negative Tests
    // ============================================

    function test_revert_executeMultichainOps_withGasRefund_ETH_invalidSignature() public {
        // Test that invalid signature reverts for ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 400,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with WRONG gas refund (different overhead) to create invalid signature
        IStandaloneIntentExecutor.GasRefund memory wrongGasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 99_999 });
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, wrongGasRefund);

        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);
    }

    function test_revert_executeSinglechainOps_withGasRefund_ETH_invalidSignature() public {
        // Test that invalid signature reverts for ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 401, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        // Sign with WRONG gas refund (different overhead) to create invalid signature
        IStandaloneIntentExecutor.GasRefund memory wrongGasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 99_999 });
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, wrongGasRefund);

        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);
    }

    function test_revert_executeMultichainOps_withGasRefund_ETH_nonceReplay() public {
        // Test that reusing a nonce reverts for ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 402,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, gasRefund);

        // First execution should succeed
        vm.prank(address(env.router));
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);

        // Verify nonce is consumed
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(402, account), "Nonce should be consumed");

        // Second execution with same nonce should revert
        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, gasRefund.overhead, env.atomicFillSigner.addr);
    }

    function test_revert_executeSinglechainOps_withGasRefund_ETH_nonceReplay() public {
        // Test that reusing a nonce reverts for ETH gas refund
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 403, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // First execution should succeed
        vm.prank(address(env.router));
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);

        // Verify nonce is consumed
        assertTrue(env.intentExecutor.isStandaloneIntentNonceConsumed(403, account), "Nonce should be consumed");

        // Second execution with same nonce should revert
        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);
    }

    function test_revert_executeMultichainOps_withGasRefund_ETH_mismatchedOverhead() public {
        // Test that passing different overhead than signed causes revert
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.MultiChainOps memory multichainOps = IStandaloneIntentExecutor.MultiChainOps({
            account: account,
            chainIndex: 0,
            otherChains: new bytes32[](0),
            nonce: 404,
            ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops),
            signature: ""
        });

        // Sign with overhead = 10000
        IStandaloneIntentExecutor.GasRefund memory signedGasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 10_000 });
        multichainOps.signature = _signMultichainOpsWithGasRefund(multichainOps, signedGasRefund);

        // But pass overhead = 50000 (different from signed)
        uint256 differentOverhead = 50_000;

        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeMultichainOpsWithGasRefund_ETH(multichainOps, differentOverhead, env.atomicFillSigner.addr);
    }

    function test_revert_executeSinglechainOps_withGasRefund_ETH_mismatchedOverhead() public {
        // Test that passing different overhead than signed causes revert
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);
        vm.deal(account, 10 ether);

        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 405, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_ERC1271, ops), signature: ""
        });

        // Sign with overhead = 10000
        IStandaloneIntentExecutor.GasRefund memory signedGasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 10_000 });
        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, signedGasRefund);

        // But pass overhead = 50000 (different from signed)
        uint256 differentOverhead = 50_000;

        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, differentOverhead, env.orchestrator.addr);
    }

    function test_revert_executionEmissary_ERC20_missingCallback() public {
        // Test that execution emissary mode reverts if callbackAllowMaxAmount is not called
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Setup token approval
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        // Operations do NOT include callbackAllowMaxAmount - this should cause revert
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 406, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Should revert because callbackAllowMaxAmount was not called during execution
        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.orchestrator.addr);
    }

    function test_revert_executionEmissary_ETH_missingCallback() public {
        // Test that execution emissary mode reverts if callbackAllowMaxAmount is not called for ETH
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;

        vm.txGasPrice(50 gwei);

        // Enable debug emissary to pass verifyExecution
        env.emissary.overwrite(true);

        // Fund account with ETH
        vm.deal(account, 10 ether);

        // Operations do NOT include callbackAllowMaxAmount - this should cause revert
        Execution[] memory ops = new Execution[](1);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 407, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(0), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Should revert because callbackAllowMaxAmount was not called during execution
        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ETH(singlechainOps, gasRefund.overhead, env.orchestrator.addr);
    }

    function test_revert_executionEmissary_verifyExecutionFails() public {
        // Test that execution emissary mode reverts if verifyExecution returns failure
        address account = env.smartAccount1.account;
        uint256 amount = 50 ether;
        uint256 maxGasRefund = 10 ether;

        vm.txGasPrice(50 gwei);

        // Do NOT enable debug emissary override - verifyExecution should fail
        env.emissary.overwrite(false);

        // Setup token approval
        vm.prank(account);
        env.token2.approve(address(env.paymaster), type(uint256).max);

        Execution[] memory ops = new Execution[](2);
        ops[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (env.solver.addr, amount)) });
        ops[1] = Execution({
            target: address(env.paymaster),
            value: 0,
            callData: abi.encodeWithSignature("callbackAllowMaxAmount(address,uint256)", address(env.token2), maxGasRefund)
        });

        IStandaloneIntentExecutor.SingleChainOps memory singlechainOps = IStandaloneIntentExecutor.SingleChainOps({
            account: account, nonce: 408, ops: SmartExecutionLib.encode(SmartExecutionLib.SigMode.EMISSARY_EXECUTION, ops), signature: ""
        });

        IStandaloneIntentExecutor.GasRefund memory gasRefund =
            IStandaloneIntentExecutor.GasRefund({ token: address(env.token2), exchangeRate: 1e18, overhead: 0 });

        singlechainOps.signature = _signSinglechainOpsWithGasRefund(singlechainOps, gasRefund);

        // Should revert because verifyExecution returns failure (0xFFFFFFFF instead of selector)
        vm.prank(address(env.router));
        vm.expectRevert();
        env.intentExecutor.executeSinglechainOpsWithGasRefund_ERC20(singlechainOps, gasRefund, env.orchestrator.addr);
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

        // Get digest without chain ID (chain-agnostic signature for multichain)
        bytes32 digest = _hashTypedDataSansChainId(hash);

        return abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));
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
        bytes32 digest = _hashTypedData(hash);

        return abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));
    }

    // External helper to convert memory array to calldata for hasher
    function _hashMultiChainOpsExternal(address account, bytes32[] memory allChains) external view returns (bytes32) {
        return hasher.hashMultiChainOps(account, allChains);
    }

    // Helper function to compute EIP-712 typed data hash with chain ID (for singlechain ops)
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    // Helper function to compute EIP-712 typed data hash WITHOUT chain ID (for multichain ops)
    function _hashTypedDataSansChainId(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorSansChainId(), structHash));
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IntentExecutor"),
                keccak256("v0.0.1"),
                block.chainid,
                address(env.intentExecutor)
            )
        );
    }

    // Domain separator WITHOUT chain ID for chain-agnostic multichain signatures
    function _domainSeparatorSansChainId() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,address verifyingContract)"),
                keccak256("IntentExecutor"),
                keccak256("v0.0.1"),
                address(env.intentExecutor)
            )
        );
    }

    function _signSinglechainOps(IStandaloneIntentExecutor.SingleChainOps memory singlechainOps) internal returns (bytes memory) {
        bytes32 hash = hasher.hashSingleChainOps(singlechainOps.account, singlechainOps.nonce, singlechainOps.ops, EIP712Lib.NO_GASREFUND);
        bytes32 digest = _hashTypedData(hash);
        return abi.encodePacked(address(env.validator), _signHash(env.eoa, digest));
    }
}
