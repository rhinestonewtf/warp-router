// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import "../types/TheCompactStructs.sol";
import "the-compact/interfaces/ITheCompact.sol";
import { AddressBook, AddressBookHelper } from "./AddressBookHelper.sol";
import { AllocatorLib } from "../allocator/lib/AllocatorLib.sol";
import { AlwaysOKAllocator } from "the-compact/test/AlwaysOKAllocator.sol";
import { DebugEmissary } from "../tests/DebugEmissary.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Hasher } from "./Hasher.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IEmissary, Emissary } from "../emissary/Emissary.sol";
import { IIntentExecutor } from "@rhinestone/compact-utils/src/interfaces/IIntentExecutor.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { IntentExecutor } from "../executor/IntentExecutor.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { MockERC20 as Token } from "./MockERC20.sol";
import { MockSimpleAccount } from "./MockSimpleAccount.sol";
import { MockTarget } from "../tests/MockTarget.sol";
import { MockTokenReturnsFalse, MockTokenAlwaysReverts, MockTokenWithFees } from "./BadTokenMocks.sol";
import { MultiCallAdapter } from "../arbiters/multicall/MultiCallAdapter.sol";
import { MultichainCompact } from "../types/TheCompactStructs.sol";
import { OwnableValidator } from "./OwnableValidator.sol";
import { Proxy, UpgradeableBeacon } from "@rhinestone/compact-utils/src/aux/Proxy.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { Router } from "@rhinestone/compact-utils/src/router/Router.sol";
import { SameChainAdapter } from "../arbiters/samechain/SameChainAdapter.sol";
import { SameChainArbiter } from "../arbiters/samechain/SameChainArbiter.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Test } from "forge-std/Test.sol";
import { TestAllocator } from "../tests/DebugAllocator.sol";
import { TheCompact } from "the-compact/TheCompact.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Version } from "@rhinestone/compact-utils/src/Version.sol";
import { WETH } from "./MockWETH.sol";
import { console2 } from "forge-std/console2.sol";
import { Bytes32ArrayLib } from "@rhinestone/compact-utils/src/common/Bytes32ArrayLib.sol";
import { Paymaster } from "@rhinestone/compact-utils/src/executor/StandaloneIntent/aux/Paymaster.sol";

library TestHelperLib {
    function toOperation(Execution[] memory executions) internal pure returns (Types.Operation memory ops) {
        if (executions.length == 0) {
            return ops;
        } else {
            ops.data = abi.encodePacked(SmartExecutionLib.Type.ERC7579, SmartExecutionLib.SigMode.ERC1271_EMISSARY, abi.encode(executions));
        }
    }

    function toOperation(Execution[] memory executions, SmartExecutionLib.SigMode _mode)
        internal
        pure
        returns (Types.Operation memory ops)
    {
        ops.data = abi.encodePacked(SmartExecutionLib.Type.ERC7579, _mode, abi.encode(executions));
    }

    function toOperation(Execution[] memory executions, uint8 _mode) internal pure returns (Types.Operation memory ops) {
        ops.data = abi.encodePacked(SmartExecutionLib.Type.ERC7579, _mode, abi.encode(executions));
    }

    function toOperationMulticall(Execution[] memory executions) internal pure returns (Types.Operation memory ops) {
        ops.data = abi.encodePacked(SmartExecutionLib.Type.MultiCall, SmartExecutionLib.SigMode.EMISSARY_ERC1271, abi.encode(executions));
    }

    function into(uint256[2] memory val) internal pure returns (uint256[2][] memory out) {
        out = new uint256[2][](1);
        out[0] = val;
    }

    function withoutIndex(bytes32[] memory array, uint256 index) internal pure returns (uint256 _index, bytes32[] memory arrayOut) {
        uint256 length = array.length;
        require(index < length, "TEST SETUP: popAt() out of bounds");
        uint256 y;
        arrayOut = new bytes32[](length - 1);
        for (uint256 i; i < length; i++) {
            if (i != index) {
                arrayOut[y] = array[i];
                y++;
            }
        }
        if (index == 0) _index = index;
        else _index = index - 1;
    }
}

interface IArbiterHash {
    function __QUALIFIER_EIP712Hash(bytes calldata data) external view returns (bytes32);
}

contract InitialImplementation { }

abstract contract CompactEnvironment is Test, RhinestoneModuleKit, AddressBookHelper {
    using TestHelperLib for *;
    using SmartExecutionLib for *;
    using ModuleKitHelpers for *;
    using Types for Execution[];
    using IdLib for *;

    struct Environment {
        Router router;
        IPermit2 permit2;
        TheCompact compact;
        DebugEmissary emissary;
        AlwaysOKAllocator alwaysOKAllocator;
        MockSimpleAccount eoa7702;
        IntentExecutor intentExecutor;
        MultiCallAdapter multicallAdapter;
        TestAllocator allocator;
        uint96 allocatorId;
        Account atomicFillSigner;
        Account orchestrator;
        Account eoa;
        Account solver;
        Scope scope;
        ResetPeriod resetPeriod;
        AccountInstance smartAccount1;
        AccountInstance smartAccount2;
        OwnableValidator validator;
        uint8 emissaryId;
        bytes12 lockTag;
        MockTarget target;
        Token token1;
        Token token2;
        Token token3;
        MockTokenReturnsFalse badToken1;
        MockTokenAlwaysReverts badToken2;
        MockTokenWithFees badToken3;
        WETH weth;
        SameChainAdapter sameChainAdapter;
        Paymaster paymaster;
    }

    struct Chains {
        uint256 originChain1;
        uint256 originChain2;
        uint256 targetChain;
    }

    struct Intent {
        Execution[] preClaimExecution;
        Execution[] targetExecutions;
        Execution[] noExec;
        uint256[2][] tokenIn;
        uint256[2][] tokenOut;
        MultichainCompact compact;
        bytes32 digest;
        bytes32 claimHash;
        bytes32[] elementHashes;
        bytes userEmissarySig;
    }

    Environment internal env;
    Chains internal chains;
    Intent internal intent;

    Hasher internal hasher;

    modifier withChainId(uint256 chainId) {
        uint256 currentChainId = block.chainid;

        vm.chainId(chainId);
        _;
        vm.chainId(currentChainId);
    }

    function _claim(
        uint256 chainId,
        bytes memory relayerContext,
        bytes memory adapterCalldata
    )
        internal
        withChainId(chainId)
        returns (uint256 gas)
    {
        vm.prank(env.solver.addr);
        gas = gasleft();
        env.router.routeClaim({ relayerContext: relayerContext, adapterCalldata: adapterCalldata });
        gas = gas - gasleft();
    }

    function _fill(uint256 chainId, bytes[] memory relayerContexts, bytes[] memory adapterCalldatas) internal returns (uint256 gas) {
        return _fill(chainId, 0, relayerContexts, adapterCalldatas);
    }

    function _fill(
        uint256 chainId,
        uint256 value,
        bytes[] memory relayerContexts,
        bytes[] memory adapterCalldatas
    )
        internal
        withChainId(chainId)
        returns (uint256 gas)
    {
        bytes memory encoded = abi.encode(adapterCalldatas);

        bytes32 hash = keccak256(encoded);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        vm.deal(env.solver.addr, value);
        vm.prank(env.solver.addr);
        gas = gasleft();
        env.router.optimized_routeFill921336808{ value: value }({
            relayerContexts: relayerContexts, encodedAdapterCalldatas: encoded, atomicFillSignature: signature
        });
        gas = gas - gasleft();
    }

    function _fill(uint256 chainId, bytes memory relayerContext, bytes memory adapterCalldata) internal returns (uint256 gas) {
        return _fill(chainId, 0, relayerContext, adapterCalldata);
    }

    function _fill(
        uint256 chainId,
        uint256 value,
        bytes memory relayerContext,
        bytes memory adapterCalldata
    )
        internal
        withChainId(chainId)
        returns (uint256 gas)
    {
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = adapterCalldata;

        bytes memory encoded = abi.encode(adapterCalldatas);

        bytes32 hash = keccak256(encoded);
        bytes memory signature = _signHashRaw(env.atomicFillSigner, hash);

        bytes[] memory solverDataArray = new bytes[](1);
        solverDataArray[0] = relayerContext;
        return _fill(chainId, value, solverDataArray, adapterCalldatas);
    }

    function _setRouterTokenApproval(address spender, address token, uint256 amount) internal {
        env.router.setTokenApproval(spender, token, amount);
    }

    function _deployCompact() public virtual {
        env.permit2 = IPermit2(address(Constants.PERMIT2));
        _deployPermit2();
        env.orchestrator = makeAccount("orchestrator");
        env.solver = makeAccount("solver");
        env.eoa = makeAccount("eoa");
        env.atomicFillSigner = makeAccount("atomicFillSigner");
        env.compact = new TheCompact();
        env.emissary = new DebugEmissary(address(env.compact));
        env.allocator = new TestAllocator(address(env.compact), env.orchestrator.addr, env.orchestrator.addr);
        env.eoa7702 = new MockSimpleAccount(env.eoa.addr);
        vm.label(address(env.eoa7702), "EOA7702 MockSimpleAccount");
        env.allocatorId = env.allocator.ALLOCATOR_ID();
        env.validator = new OwnableValidator();
        env.resetPeriod = ResetPeriod.SevenDaysAndOneHour;
        env.scope = Scope.Multichain;
        env.lockTag = IdLib.toLockTag(env.allocatorId, env.scope, env.resetPeriod);

        env.target = new MockTarget();
        env.router = new Router(env.atomicFillSigner.addr, address(this), address(this));

        hasher = new Hasher();

        // Initialize intent arrays
        intent.noExec = new Execution[](0);

        env.multicallAdapter = new MultiCallAdapter(address(env.router));
        _setFillRoute(MultiCallAdapter.multicall_handleFill.selector, address(env.multicallAdapter));
        _setClaimRoute(MultiCallAdapter.multicall_handleJITClaim.selector, address(env.multicallAdapter));

        // Predict IntentExecutor address to break circular dependency
        bytes memory intentExecutorBytecode = type(IntentExecutor).creationCode;
        bytes memory intentExecutorArgs =
            abi.encode(address(env.router), address(env.compact), address(env.allocator), address(ADDRESSBOOK), address(env.emissary));

        // Debug: Check if prediction works
        require(intentExecutorBytecode.length > 0, "IntentExecutor bytecode is empty");
        require(intentExecutorArgs.length > 0, "IntentExecutor args are empty");

        address predictedIntentExecutor =
            predictCreate2(keccak256(abi.encodePacked("IntentExecutor")), intentExecutorBytecode, intentExecutorArgs);
        require(predictedIntentExecutor != address(0), "Predicted address is zero");

        // Register the predicted IntentExecutor address in the AddressBook first
        ADDRESSBOOK.setAddress(Constants.INTENT_EXECUTOR_ID, predictedIntentExecutor);

        // Deploy SameChain adapters first since IntentExecutor constructor needs them
        // Test if AddressBook lookup works
        address retrievedIntentExecutor = ADDRESSBOOK.getAddress(Constants.INTENT_EXECUTOR_ID);
        require(retrievedIntentExecutor == predictedIntentExecutor, "AddressBook lookup failed");

        address samechainArbiter = address(new SameChainArbiter(address(env.router), address(env.compact), address(ADDRESSBOOK)));

        env.sameChainAdapter = SameChainAdapter(
            create2(
                keccak256(abi.encodePacked("SameChainAdapter")),
                "SameChainAdapter",
                type(SameChainAdapter).creationCode,
                abi.encode(address(env.router), address(env.compact), address(0), address(ADDRESSBOOK))
            )
        );

        // Register the adapters in the AddressBook
        ADDRESSBOOK.setAddress(Constants.SAMECHAIN_ARBITER_ID, address(env.sameChainAdapter));

        // Deploy Paymaster first with predicted IntentExecutor address
        env.paymaster = new Paymaster(predictedIntentExecutor, address(this));

        // Register Paymaster in AddressBook so IntentExecutor can find it
        ADDRESSBOOK.setAddress(Constants.PAYMASTER_ID, address(env.paymaster));

        // Now deploy IntentExecutor after the adapters are deployed and registered
        env.intentExecutor = IntentExecutor(
            create2(keccak256(abi.encodePacked("IntentExecutor")), "IntentExecutor", intentExecutorBytecode, intentExecutorArgs)
        );

        // Verify the address matches our prediction
        require(address(env.intentExecutor) == predictedIntentExecutor, "IntentExecutor address mismatch");

        env.token1 = new Token("Token1", "TKN1", 18);
        vm.label(address(env.token1), "Token1");
        env.token2 = new Token("Token2", "TKN2", 18);
        vm.label(address(env.token2), "Token2");
        env.token3 = new Token("Token3", "TKN3", 18);
        vm.label(address(env.token3), "Token3");

        // Initialize bad tokens for testing edge cases
        env.badToken1 = new MockTokenReturnsFalse("BadToken1", "BAD1", 18);
        vm.label(address(env.badToken1), "BadToken1 (returns false)");
        env.badToken2 = new MockTokenAlwaysReverts("BadToken2", "BAD2", 18);
        vm.label(address(env.badToken2), "BadToken2 (always reverts)");
        env.badToken3 = new MockTokenWithFees("BadToken3", "BAD3", 18);
        vm.label(address(env.badToken3), "BadToken3 (with fees)");

        chains.originChain1 = 111;
        chains.originChain2 = 222;
        chains.targetChain = 1337;
        env.weth = new WETH();
        ADDRESSBOOK.setAddress(Constants.WETH_ID, address(env.weth));

        env.emissaryId = 1;

        env.token1.mint(env.solver.addr, 100 ether);
        env.token2.mint(env.solver.addr, 100 ether);
        env.token3.mint(env.solver.addr, 100 ether);

        vm.startPrank(env.solver.addr);
        env.token1.approve(address(env.router), type(uint256).max);
        env.token2.approve(address(env.router), type(uint256).max);
        env.token3.approve(address(env.router), type(uint256).max);
        vm.stopPrank();
    }

    function _sampleExecERC20(Token targetChainToken, uint256 amount) internal {
        intent.targetExecutions = new Execution[](2);
        intent.targetExecutions[0] = Execution({
            target: address(targetChainToken), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), amount))
        });

        intent.targetExecutions[1] = Execution({
            target: address(env.target), value: 0, callData: abi.encodeCall(MockTarget.deposit, (IERC20(address(targetChainToken)), amount))
        });
    }

    function _sampleExecNative(Token targetChainToken, uint256 amount, uint256 param) internal {
        intent.targetExecutions = new Execution[](1);
        intent.targetExecutions[0] =
            Execution({ target: address(env.target), value: amount, callData: abi.encodeCall(MockTarget.targetFn, (param)) });
    }

    function _deploySmartAccount(bool create) public virtual {
        env.smartAccount1 = makeAccountInstance("SmartAccount1");
        env.smartAccount2 = makeAccountInstance("SmartAccount2");
        if (create) {
            env.smartAccount1.deployAccount();
            env.smartAccount1.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(env.intentExecutor), data: "" });

            address[] memory signers = new address[](1);
            signers[0] = env.eoa.addr;
            bytes memory init = abi.encode(1, signers);
            env.smartAccount1.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(env.validator), data: init });
            env.smartAccount2.deployAccount();
            env.smartAccount2.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(env.intentExecutor), data: "" });
            env.smartAccount2.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(env.validator), data: init });
        }
    }

    function _setFillRoute(bytes4 selector, address route) internal {
        env.router.installFillAdapter(Version.PROTOCOL_V1, selector, route);
    }

    function _setClaimRoute(bytes4 selector, address route) internal {
        env.router.installClaimAdapter(Version.PROTOCOL_V1, selector, route);
    }

    function _setEmissary(AccountInstance storage instance, Account storage signer) internal virtual {
        address account = instance.account;
        vm.prank(account);
        env.compact.assignEmissary(env.lockTag, address(env.emissary));

        (,, address emissary) = env.compact.getEmissaryStatus(account, env.lockTag);
        assertEq(emissary, address(env.emissary), "emissary not set");

        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = chains.originChain1;
        chainIds[1] = chains.originChain2;
        chainIds[2] = chains.targetChain;

        address[] memory signers = new address[](1);
        signers[0] = signer.addr;

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: env.emissaryId,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(env.validator)),
            validatorConfig: abi.encode(uint256(1), signers)
        });

        IEmissary.EmissaryEnable memory enableData;

        enableData.chainIndex = 0;
        enableData.allChainIds = chainIds;
        enableData.expires = block.timestamp + 1;
        enableData.nonce = 1;

        env.emissary
            .mock_setConfig(account, env.emissaryId, env.lockTag, IStatelessValidator(address(env.validator)), config.validatorConfig);
    }

    function _signHashRaw(Account storage eoa, bytes32 digest) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoa.key, (digest));
        return abi.encodePacked(r, s, v);
    }

    function _signHash(Account storage eoa, bytes32 digest) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoa.key, ECDSA.toEthSignedMessageHash(digest));

        // Sanity checks
        address signer = ecrecover(ECDSA.toEthSignedMessageHash(digest), v, r, s);
        require(signer == vm.addr(eoa.key), "Invalid signature");

        return abi.encodePacked(r, s, v);
    }

    function _signOwnableValidator(Account storage eoa, bytes32 digest) internal view returns (bytes memory) {
        bytes memory sig = _signHash(eoa, digest);
        return abi.encodePacked(env.validator, sig);
    }

    function _emissarySig(AccountInstance storage smartAccount, Account storage with, bytes32 digest) internal returns (bytes memory) {
        // ensure that emissary was set
        bytes memory config =
            env.emissary._config(smartAccount.account, env.emissaryId, env.lockTag, IStatelessValidator(address(env.validator)));
        require(config.length != 0, "TEST SETUP: Emissary not Set");
        bytes memory ecdsaSig = _signHash(with, digest);
        return abi.encodePacked(env.validator, env.emissaryId, ecdsaSig);
    }

    function _allocatorSig(
        Account storage allocator,
        uint256 chainId,
        bytes32 claimHash,
        bytes32 qualificationHash
    )
        internal
        withChainId(chainId)
        returns (bytes32 digest, bytes memory sig)
    {
        bytes32 hash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));
        sig = _signHashRaw(allocator, digest);
    }

    function _allocatorSig(
        Account storage allocator,
        uint256 chainId,
        bytes32 claimHash
    )
        internal
        withChainId(chainId)
        returns (bytes32 digest, bytes memory sig)
    {
        digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), claimHash));
        sig = _signHashRaw(allocator, digest);
    }

    function _hashTypedData(uint256 chainId, bytes32 claimHash) internal returns (bytes32 digest) {
        uint256 currentChainId = block.chainid;
        vm.chainId(chainId);
        digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), claimHash));
        vm.chainId(currentChainId);
    }

    function _hashTypedDataPermit2(uint256 chainId, bytes32 permit2Hash) internal returns (bytes32 digest) {
        digest = hasher.hashTypedDataPermit2(chainId, permit2Hash);
    }

    function _lockAssets(AccountInstance storage instance, Token _token, uint256 amount) internal virtual returns (uint256 tokenId) {
        address account = instance.account;
        _token.mint(account, 100 ether);

        vm.startPrank(account);
        _token.approve(address(Constants.PERMIT2), 100 ether);
        _token.approve(address(env.compact), amount);
        tokenId = env.compact.depositERC20(address(_token), env.lockTag, amount, account);
        vm.stopPrank();
    }

    function _lockAssets(AccountInstance storage instance, address token, uint256 amount) internal virtual returns (uint256 tokenId) {
        if (token != Constants.NATIVE_TOKEN) {
            _lockAssets(instance, Token(token), amount);
        } else {
            address account = instance.account;
            vm.deal(account, amount);
            vm.prank(account);
            tokenId = env.compact.depositNative{ value: amount }(env.lockTag, account);
        }
    }

    function _getOrder(MultichainCompact storage compact, uint256 elementIndex) internal virtual returns (Types.Order memory order) {
        return _getOrder(compact, elementIndex, 300_000);
    }

    function _getOrder(
        MultichainCompact storage compact,
        uint256 elementIndex,
        uint128 gasStipend
    )
        internal
        virtual
        returns (Types.Order memory order)
    {
        uint256 notarizedChainId = compact.elements[0].chainId;
        Element storage element = compact.elements[elementIndex];

        order = Types.Order({
            sponsor: compact.sponsor,
            recipient: element.mandate.target.recipient,
            nonce: compact.nonce,
            expires: compact.expires,
            fillDeadline: element.mandate.target.fillExpiry,
            notarizedChainId: notarizedChainId,
            targetChainId: element.mandate.target.targetChain,
            tokenIn: element.idsAndAmounts,
            tokenOut: element.mandate.target.tokenOut,
            preClaimOps: element.mandate.originOps,
            targetOps: element.mandate.destOps,
            qualifier: element.mandate.q,
            packedGasValues: Types.packGasValues(gasStipend, element.mandate.minGas)
        });
    }

    function hashCompact(
        address arbiter,
        MultichainCompact storage compact
    )
        internal
        returns (bytes32 claimHash, bytes32[] memory elementHashes)
    {
        elementHashes = new bytes32[](compact.elements.length);

        for (uint256 i; i < compact.elements.length; i++) {
            Types.Order memory order = _getOrder(compact, i, 0);
            elementHashes[i] = hasher.hashElement(order, compact.elements[i].arbiter, compact.elements[i].chainId);
            bytes32 mandateHash = hasher.hashMandate(order);
            console2.log("TEST SIDE: Element hash", i);
            console2.logBytes32(elementHashes[i]);
        }

        bytes32 allElementsHash = keccak256(abi.encodePacked(elementHashes));
        console2.log("TEST SIDE: allElementsHash:");
        console2.logBytes32(allElementsHash);

        claimHash = EIP712TypeHashLib.hashCompact(compact.sponsor, compact.nonce, compact.expires, allElementsHash);
        console2.log("TEST SIDE: Final claimHash:");
        console2.logBytes32(claimHash);
    }

    function _getOrder(
        address sponsor,
        uint256 nonce,
        uint256 expires,
        address arbiter,
        Element storage element
    )
        internal
        returns (Types.Order memory order)
    {
        return _getOrder(sponsor, nonce, expires, arbiter, element, 300_000);
    }

    function _getOrder(
        address sponsor,
        uint256 nonce,
        uint256 expires,
        address arbiter,
        Element storage element,
        uint128 gasStipend
    )
        internal
        returns (Types.Order memory order)
    {
        order = Types.Order({
            sponsor: sponsor,
            recipient: element.mandate.target.recipient,
            nonce: nonce,
            expires: expires,
            fillDeadline: element.mandate.target.fillExpiry,
            notarizedChainId: element.chainId,
            targetChainId: element.mandate.target.targetChain,
            tokenIn: element.idsAndAmounts,
            tokenOut: element.mandate.target.tokenOut,
            preClaimOps: element.mandate.originOps,
            targetOps: element.mandate.destOps,
            qualifier: element.mandate.q,
            packedGasValues: Types.packGasValues(gasStipend, element.mandate.minGas)
        });
    }

    function hashPermit2(
        address sponsor,
        uint256 nonce,
        uint256 expires,
        address arbiter,
        Element storage element
    )
        internal
        returns (bytes32 hash)
    {
        Types.Order memory order = _getOrder(sponsor, nonce, expires, arbiter, element, 0);
        // Use the full Permit2 batch witness hash - this is what Permit2.permitWitnessTransferFrom expects!
        hash = hasher.permit2_hashBatchWithWitness(order, arbiter);
    }

    function _makeClaimHash(address arbiter) internal {
        MultichainCompact storage compact = intent.compact;
        (intent.claimHash, intent.elementHashes) = hashCompact(arbiter, compact);
    }

    function toId(Token token) internal view returns (uint256) {
        return toId(address(token));
    }

    function toId(address token) internal view returns (uint256) {
        return (uint256(env.scope) << 255) | (uint256(env.resetPeriod) << 252) | (uint256(env.allocatorId) << 160)
            | uint256(uint160(address(token)));
    }

    function _simulateClaim(address arbiter, MultichainCompact storage compact, uint256 elementIndex) internal {
        Element storage element = compact.elements[elementIndex];

        (bytes32 claimHash,) = hashCompact(arbiter, compact);
    }

    function _getEIP712Stubs_TargetOps(
        MultichainCompact storage compact,
        address claimHashProofer,
        uint256 elementIndex
    )
        internal
        returns (
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub
        )
    {
        Types.Order memory order = _getOrder(compact, elementIndex, 0);

        Element storage element = compact.elements[elementIndex];

        address arbiter = element.arbiter;

        (bytes32 claimhash, bytes32[] memory elementHashes) = hashCompact(arbiter, compact);

        (, elementHashes) = elementHashes.withoutIndex(elementIndex);

        compactStub.nonce = order.nonce;
        compactStub.expires = order.expires;
        compactStub.notarizedChainId = order.notarizedChainId;

        elementStub = ICompactIntentExecutor.EIP712ElementStubDestination({
            sponsor: compact.sponsor,
            otherElements: elementHashes,
            elementOffset: elementIndex,
            preClaimOpsHash: this.jump_hashEIP712(order.preClaimOps),
            tokenInHash: hasher.hashTokenIn(order.tokenIn),
            tokenOutHash: hasher.hashTokenOut(order.tokenOut),
            fillExpires: element.mandate.target.fillExpiry,
            qHash: hasher.hashQualifier(order.qualifier)
        });
    }

    function _getEIP712Stubs_PreClaimOps(
        MultichainCompact storage compact,
        uint256 elementIndex
    )
        internal
        returns (
            ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub
        )
    {
        Types.Order memory order = _getOrder(compact, elementIndex, 0);

        Element storage element = compact.elements[elementIndex];

        address arbiter = element.arbiter;

        (bytes32 claimhash, bytes32[] memory elementHashes) = hashCompact(arbiter, compact);

        (, elementHashes) = elementHashes.withoutIndex(elementIndex);

        compactStub.nonce = order.nonce;
        compactStub.expires = order.expires;
        compactStub.notarizedChainId = order.notarizedChainId;

        elementStub.otherElements = elementHashes;
        elementStub.elementOffset = elementIndex;
        elementStub.destOpsHash = this.jump_hashEIP712(order.targetOps);
        elementStub.targetAttributesHash = hasher.hashTargetAttributes(order);

        elementStub.tokenInHash = hasher.hashTokenIn(order.tokenIn);
        elementStub.qHash = hasher.hashQualifier(order.qualifier);
    }

    function jump_hashEIP712(Types.Operation calldata ops) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOps(ops);
    }

    function _toIntentExecutorCall_targetOps(
        MultichainCompact storage compact,
        address proofSender,
        bytes memory signature
    )
        internal
        returns (bytes memory call)
    {
        (
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub
        ) = _getEIP712Stubs_TargetOps(compact, address(0), 0);
        call = abi.encodeCall(
            ICompactIntentExecutor.executeTargetOpsWithCompactStub,
            (
                compact.elements[0].mandate.target.recipient,
                compact.elements[0].arbiter,
                compactStub,
                elementStub,
                compact.elements[0].mandate.destOps,
                signature
            )
        );
    }

    function _toIntentExecutorCall_preClaimOps(
        MultichainCompact storage compact,
        uint256 elementIndex,
        bytes memory signature
    )
        internal
        returns (bytes memory call)
    {
        (ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub, ICompactIntentExecutor.EIP712CompactStub memory compactStub) =
            _getEIP712Stubs_PreClaimOps(compact, elementIndex);
        call = abi.encodeCall(
            ICompactIntentExecutor.executePreClaimOpsWithCompactStub,
            (
                compact.elements[elementIndex].mandate.target.recipient,
                compactStub,
                elementStub,
                compact.elements[elementIndex].mandate.originOps,
                signature
            )
        );
    }

    function _newProxy(bytes32 name) internal returns (address) {
        return deploy(name, type(InitialImplementation).creationCode);
    }

    function _setProxyImpl(bytes32 name, address newImpl) internal {
        address initialAddr = predictDeploymentAddress(name, type(InitialImplementation).creationCode);
        UpgradeableBeacon(initialAddr).upgradeTo(newImpl);
    }

    function _deployPermit2() internal {
        address permit2Deployer = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        address deployedPermit2Deployer;
        address permit2DeployerDeployer = address(0x3fAB184622Dc19b6109349B94811493BF2a45362);
        bytes memory permit2DeployerCreationCode =
            hex"604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";
        vm.deal(permit2DeployerDeployer, 1e18);
        vm.prank(permit2DeployerDeployer);
        assembly ("memory-safe") {
            deployedPermit2Deployer := create(0, add(permit2DeployerCreationCode, 0x20), mload(permit2DeployerCreationCode))
        }

        require(deployedPermit2Deployer != permit2Deployer, "Contract deployment failed");

        if (true) {
            bytes memory permit2CreationCalldata =
                hex"0000000000000000000000000000000000000000d3af2663da51c1021500000060c0346100bb574660a052602081017f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86681527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a60408301524660608301523060808301526080825260a082019180831060018060401b038411176100a557826040525190206080526123c090816100c1823960805181611b47015260a05181611b210152f35b634e487b7160e01b600052604160045260246000fd5b600080fdfe6040608081526004908136101561001557600080fd5b600090813560e01c80630d58b1db1461126c578063137c29fe146110755780632a2d80d114610db75780632b67b57014610bde57806330f28b7a14610ade5780633644e51514610a9d57806336c7851614610a285780633ff9dcb1146109a85780634fe02b441461093f57806365d9723c146107ac57806387517c451461067a578063927da105146105c3578063cc53287f146104a3578063edd9444b1461033a5763fe8ec1a7146100c657600080fd5b346103365760c07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff833581811161033257610114903690860161164b565b60243582811161032e5761012b903690870161161a565b6101336114e6565b9160843585811161032a5761014b9036908a016115c1565b98909560a43590811161032657610164913691016115c1565b969095815190610173826113ff565b606b82527f5065726d697442617463685769746e6573735472616e7366657246726f6d285460208301527f6f6b656e5065726d697373696f6e735b5d207065726d69747465642c61646472838301527f657373207370656e6465722c75696e74323536206e6f6e63652c75696e74323560608301527f3620646561646c696e652c000000000000000000000000000000000000000000608083015282519a8b9181610222602085018096611f93565b918237018a8152039961025b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe09b8c8101835282611437565b5190209085515161026b81611ebb565b908a5b8181106102f95750506102f6999a6102ed9183516102a081610294602082018095611f66565b03848101835282611437565b519020602089810151858b015195519182019687526040820192909252336060820152608081019190915260a081019390935260643560c08401528260e081015b03908101835282611437565b51902093611cf7565b80f35b8061031161030b610321938c5161175e565b51612054565b61031b828661175e565b52611f0a565b61026e565b8880fd5b8780fd5b8480fd5b8380fd5b5080fd5b5091346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff9080358281116103325761038b903690830161164b565b60243583811161032e576103a2903690840161161a565b9390926103ad6114e6565b9160643590811161049f576103c4913691016115c1565b949093835151976103d489611ebb565b98885b81811061047d5750506102f697988151610425816103f9602082018095611f66565b037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08101835282611437565b5190206020860151828701519083519260208401947ffcf35f5ac6a2c28868dc44c302166470266239195f02b0ee408334829333b7668652840152336060840152608083015260a082015260a081526102ed8161141b565b808b61031b8261049461030b61049a968d5161175e565b9261175e565b6103d7565b8680fd5b5082346105bf57602090817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103325780359067ffffffffffffffff821161032e576104f49136910161161a565b929091845b848110610504578580f35b8061051a610515600193888861196c565b61197c565b61052f84610529848a8a61196c565b0161197c565b3389528385528589209173ffffffffffffffffffffffffffffffffffffffff80911692838b528652868a20911690818a5285528589207fffffffffffffffffffffffff000000000000000000000000000000000000000081541690558551918252848201527f89b1add15eff56b3dfe299ad94e01f2b52fbcb80ae1a3baea6ae8c04cb2b98a4853392a2016104f9565b8280fd5b50346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610676816105ff6114a0565b936106086114c3565b6106106114e6565b73ffffffffffffffffffffffffffffffffffffffff968716835260016020908152848420928816845291825283832090871683528152919020549251938316845260a083901c65ffffffffffff169084015260d09190911c604083015281906060820190565b0390f35b50346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336576106b26114a0565b906106bb6114c3565b916106c46114e6565b65ffffffffffff926064358481169081810361032a5779ffffffffffff0000000000000000000000000000000000000000947fda9fa7c1b00402c17d0161b249b1ab8bbec047c5a52207b9c112deffd817036b94338a5260016020527fffffffffffff0000000000000000000000000000000000000000000000000000858b209873ffffffffffffffffffffffffffffffffffffffff809416998a8d5260205283878d209b169a8b8d52602052868c209486156000146107a457504216925b8454921697889360a01b16911617179055815193845260208401523392a480f35b905092610783565b5082346105bf5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576107e56114a0565b906107ee6114c3565b9265ffffffffffff604435818116939084810361032a57338852602091600183528489209673ffffffffffffffffffffffffffffffffffffffff80911697888b528452858a20981697888a5283528489205460d01c93848711156109175761ffff9085840316116108f05750907f55eb90d810e1700b35a8e7e25395ff7f2b2259abd7415ca2284dfb1c246418f393929133895260018252838920878a528252838920888a5282528389209079ffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffff000000000000000000000000000000000000000000000000000083549260d01b16911617905582519485528401523392a480f35b84517f24d35a26000000000000000000000000000000000000000000000000000000008152fd5b5084517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b503461033657807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336578060209273ffffffffffffffffffffffffffffffffffffffff61098f6114a0565b1681528084528181206024358252845220549051908152f35b5082346105bf57817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf577f3704902f963766a4e561bbaab6e6cdc1b1dd12f6e9e99648da8843b3f46b918d90359160243533855284602052818520848652602052818520818154179055815193845260208401523392a280f35b8234610a9a5760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610a9a57610a606114a0565b610a686114c3565b610a706114e6565b6064359173ffffffffffffffffffffffffffffffffffffffff8316830361032e576102f6936117a1565b80fd5b503461033657817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657602090610ad7611b1e565b9051908152f35b508290346105bf576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf57610b1a3661152a565b90807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c36011261033257610b4c611478565b9160e43567ffffffffffffffff8111610bda576102f694610b6f913691016115c1565b939092610b7c8351612054565b6020840151828501519083519260208401947f939c21a48a8dbe3a9a2404a1d46691e4d39f6583d6ec6b35714604c986d801068652840152336060840152608083015260a082015260a08152610bd18161141b565b51902091611c25565b8580fd5b509134610336576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610c186114a0565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc360160c08112610332576080855191610c51836113e3565b1261033257845190610c6282611398565b73ffffffffffffffffffffffffffffffffffffffff91602435838116810361049f578152604435838116810361049f57602082015265ffffffffffff606435818116810361032a5788830152608435908116810361049f576060820152815260a435938285168503610bda576020820194855260c4359087830182815260e43567ffffffffffffffff811161032657610cfe90369084016115c1565b929093804211610d88575050918591610d786102f6999a610d7e95610d238851611fbe565b90898c511690519083519260208401947ff3841cd1ff0085026a6327b620b67997ce40f282c88a8e905a7a5626e310f3d086528401526060830152608082015260808152610d70816113ff565b519020611bd9565b916120c7565b519251169161199d565b602492508a51917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b5091346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc93818536011261033257610df36114a0565b9260249081359267ffffffffffffffff9788851161032a578590853603011261049f578051978589018981108282111761104a578252848301358181116103265785019036602383011215610326578382013591610e50836115ef565b90610e5d85519283611437565b838252602093878584019160071b83010191368311611046578801905b828210610fe9575050508a526044610e93868801611509565b96838c01978852013594838b0191868352604435908111610fe557610ebb90369087016115c1565b959096804211610fba575050508998995151610ed681611ebb565b908b5b818110610f9757505092889492610d7892610f6497958351610f02816103f98682018095611f66565b5190209073ffffffffffffffffffffffffffffffffffffffff9a8b8b51169151928551948501957faf1b0d30d2cab0380e68f0689007e3254993c596f2fdd0aaa7f4d04f794408638752850152830152608082015260808152610d70816113ff565b51169082515192845b848110610f78578580f35b80610f918585610f8b600195875161175e565b5161199d565b01610f6d565b80610311610fac8e9f9e93610fb2945161175e565b51611fbe565b9b9a9b610ed9565b8551917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b8a80fd5b6080823603126110465785608091885161100281611398565b61100b85611509565b8152611018838601611509565b838201526110278a8601611607565b8a8201528d611037818701611607565b90820152815201910190610e7a565b8c80fd5b84896041867f4e487b7100000000000000000000000000000000000000000000000000000000835252fd5b5082346105bf576101407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576110b03661152a565b91807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c360112610332576110e2611478565b67ffffffffffffffff93906101043585811161049f5761110590369086016115c1565b90936101243596871161032a57611125610bd1966102f6983691016115c1565b969095825190611134826113ff565b606482527f5065726d69745769746e6573735472616e7366657246726f6d28546f6b656e5060208301527f65726d697373696f6e73207065726d69747465642c6164647265737320737065848301527f6e6465722c75696e74323536206e6f6e63652c75696e7432353620646561646c60608301527f696e652c0000000000000000000000000000000000000000000000000000000060808301528351948591816111e3602085018096611f93565b918237018b8152039361121c7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe095868101835282611437565b5190209261122a8651612054565b6020878101518589015195519182019687526040820192909252336060820152608081019190915260a081019390935260e43560c08401528260e081016102e1565b5082346105bf576020807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033257813567ffffffffffffffff92838211610bda5736602383011215610bda5781013592831161032e576024906007368386831b8401011161049f57865b8581106112e5578780f35b80821b83019060807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc83360301126103265761139288876001946060835161132c81611398565b611368608461133c8d8601611509565b9485845261134c60448201611509565b809785015261135d60648201611509565b809885015201611509565b918291015273ffffffffffffffffffffffffffffffffffffffff80808093169516931691166117a1565b016112da565b6080810190811067ffffffffffffffff8211176113b457604052565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6060810190811067ffffffffffffffff8211176113b457604052565b60a0810190811067ffffffffffffffff8211176113b457604052565b60c0810190811067ffffffffffffffff8211176113b457604052565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176113b457604052565b60c4359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b600080fd5b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6024359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6044359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc01906080821261149b576040805190611563826113e3565b8082941261149b57805181810181811067ffffffffffffffff8211176113b457825260043573ffffffffffffffffffffffffffffffffffffffff8116810361149b578152602435602082015282526044356020830152606435910152565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020838186019501011161149b57565b67ffffffffffffffff81116113b45760051b60200190565b359065ffffffffffff8216820361149b57565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020808501948460061b01011161149b57565b91909160608184031261149b576040805191611666836113e3565b8294813567ffffffffffffffff9081811161149b57830182601f8201121561149b578035611693816115ef565b926116a087519485611437565b818452602094858086019360061b8501019381851161149b579086899897969594939201925b8484106116e3575050505050855280820135908501520135910152565b90919293949596978483031261149b578851908982019082821085831117611730578a928992845261171487611509565b81528287013583820152815201930191908897969594936116c6565b602460007f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b80518210156117725760209160051b010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b92919273ffffffffffffffffffffffffffffffffffffffff604060008284168152600160205282828220961695868252602052818120338252602052209485549565ffffffffffff8760a01c16804211611884575082871696838803611812575b5050611810955016926118b5565b565b878484161160001461184f57602488604051907ff96fb0710000000000000000000000000000000000000000000000000000000082526004820152fd5b7fffffffffffffffffffffffff000000000000000000000000000000000000000084846118109a031691161790553880611802565b602490604051907fd81b2f2e0000000000000000000000000000000000000000000000000000000082526004820152fd5b9060006064926020958295604051947f23b872dd0000000000000000000000000000000000000000000000000000000086526004860152602485015260448401525af13d15601f3d116001600051141617161561190e57565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601460248201527f5452414e534645525f46524f4d5f4641494c45440000000000000000000000006044820152fd5b91908110156117725760061b0190565b3573ffffffffffffffffffffffffffffffffffffffff8116810361149b5790565b9065ffffffffffff908160608401511673ffffffffffffffffffffffffffffffffffffffff908185511694826020820151169280866040809401511695169560009187835260016020528383208984526020528383209916988983526020528282209184835460d01c03611af5579185611ace94927fc6a377bfc4eb120024a8ac08eef205be16b817020812c73223e81d1bdb9708ec98979694508715600014611ad35779ffffffffffff00000000000000000000000000000000000000009042165b60a01b167fffffffffffff00000000000000000000000000000000000000000000000000006001860160d01b1617179055519384938491604091949373ffffffffffffffffffffffffffffffffffffffff606085019616845265ffffffffffff809216602085015216910152565b0390a4565b5079ffffffffffff000000000000000000000000000000000000000087611a60565b600484517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b467f000000000000000000000000000000000000000000000000000000000000000003611b69577f000000000000000000000000000000000000000000000000000000000000000090565b60405160208101907f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86682527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a604082015246606082015230608082015260808152611bd3816113ff565b51902090565b611be1611b1e565b906040519060208201927f190100000000000000000000000000000000000000000000000000000000000084526022830152604282015260428152611bd381611398565b9192909360a435936040840151804211611cc65750602084510151808611611c955750918591610d78611c6594611c60602088015186611e47565b611bd9565b73ffffffffffffffffffffffffffffffffffffffff809151511692608435918216820361149b57611810936118b5565b602490604051907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b602490604051907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b959093958051519560409283830151804211611e175750848803611dee57611d2e918691610d7860209b611c608d88015186611e47565b60005b868110611d42575050505050505050565b611d4d81835161175e565b5188611d5a83878a61196c565b01359089810151808311611dbe575091818888886001968596611d84575b50505050505001611d31565b611db395611dad9273ffffffffffffffffffffffffffffffffffffffff6105159351169561196c565b916118b5565b803888888883611d78565b6024908651907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b600484517fff633a38000000000000000000000000000000000000000000000000000000008152fd5b6024908551907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b9073ffffffffffffffffffffffffffffffffffffffff600160ff83161b9216600052600060205260406000209060081c6000526020526040600020818154188091551615611e9157565b60046040517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b90611ec5826115ef565b611ed26040519182611437565b8281527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0611f0082946115ef565b0190602036910137565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114611f375760010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b805160208092019160005b828110611f7f575050505090565b835185529381019392810192600101611f71565b9081519160005b838110611fab575050016000815290565b8060208092840101518185015201611f9a565b60405160208101917f65626cad6cb96493bf6f5ebea28756c966f023ab9e8a83a7101849d5573b3678835273ffffffffffffffffffffffffffffffffffffffff8082511660408401526020820151166060830152606065ffffffffffff9182604082015116608085015201511660a082015260a0815260c0810181811067ffffffffffffffff8211176113b45760405251902090565b6040516020808201927f618358ac3db8dc274f0cd8829da7e234bd48cd73c4a740aede1adec9846d06a1845273ffffffffffffffffffffffffffffffffffffffff81511660408401520151606082015260608152611bd381611398565b919082604091031261149b576020823592013590565b6000843b61222e5750604182036121ac576120e4828201826120b1565b939092604010156117725760209360009360ff6040608095013560f81c5b60405194855216868401526040830152606082015282805260015afa156121a05773ffffffffffffffffffffffffffffffffffffffff806000511691821561217657160361214c57565b60046040517f815e1d64000000000000000000000000000000000000000000000000000000008152fd5b60046040517f8baa579f000000000000000000000000000000000000000000000000000000008152fd5b6040513d6000823e3d90fd5b60408203612204576121c0918101906120b1565b91601b7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff84169360ff1c019060ff8211611f375760209360009360ff608094612102565b60046040517f4be6321b000000000000000000000000000000000000000000000000000000008152fd5b929391601f928173ffffffffffffffffffffffffffffffffffffffff60646020957fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0604051988997889687947f1626ba7e000000000000000000000000000000000000000000000000000000009e8f8752600487015260406024870152816044870152868601378b85828601015201168101030192165afa9081156123a857829161232a575b507fffffffff000000000000000000000000000000000000000000000000000000009150160361230057565b60046040517fb0669cbc000000000000000000000000000000000000000000000000000000008152fd5b90506020813d82116123a0575b8161234460209383611437565b810103126103365751907fffffffff0000000000000000000000000000000000000000000000000000000082168203610a9a57507fffffffff0000000000000000000000000000000000000000000000000000000090386122d4565b3d9150612337565b6040513d84823e3d90fdfea164736f6c6343000811000a";

            (bool ok,) = permit2Deployer.call(permit2CreationCalldata);
            require(ok && address(Constants.PERMIT2).code.length != 0, "permit2 deployment failed");
        }
        vm.label(address(Constants.PERMIT2), "PERMIT2");
    }

    function _redeployPermit2(uint256 chainId) internal {
        uint256 currentChainId = block.chainid;
        vm.chainId(chainId);

        // Clear existing permit2 code
        vm.etch(address(Constants.PERMIT2), "");

        // Re-deploy permit2 with the correct domain separator for the target chain
        _deployPermit2();

        vm.chainId(currentChainId);
    }

    function _createDigest(bytes32 domainSeparator, bytes32 hashValue) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, hashValue));
    }

    function insertAtAndHash(bytes32[] calldata array, uint256 index, bytes32 element) external pure returns (bytes32) {
        return Bytes32ArrayLib.insertAtAndHash(array, index, element);
    }
}
