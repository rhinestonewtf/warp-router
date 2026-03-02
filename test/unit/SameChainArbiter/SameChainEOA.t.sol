import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

contract SameChainEOABaseTest is CompactEnvironment {
    using ModuleKitHelpers for *;
    using TestHelperLib for *;
    using Types for Execution[];
    using Types for Execution;

    struct UserIntent {
        MultichainCompact compact;
        bytes32[] elementHashes;
        bytes32 claimHash;
        bytes32 digest;
        bytes userEmissarySig;
    }

    UserIntent $intent;

    SameChainAdapter adapter;
    address arbiter;

    Execution[] targetOpsOnEOA;

    function setUp() public virtual {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);
        _lockAssets(env.smartAccount1, env.token1, 100 ether);

        adapter = env.sameChainAdapter;
        arbiter = address(adapter.ARBITER());

        _setFillRoute(SameChainAdapter.samechain_compact_handleFill.selector, address(adapter));
        // _setClaimRoute(SameChainOrderType, address(route));

        // test
        _sampleExecERC20(env.token2, 10);

        address recipient = address(env.eoa7702);
        uint256 depositId = 1337;

        $intent.compact.sponsor = env.smartAccount1.account;
        $intent.compact.nonce = 1337;
        $intent.compact.expires = 4141;

        uint256 notarizedChain = chains.originChain1;

        targetOpsOnEOA = new Execution[](1);
        targetOpsOnEOA[0] = Execution({
            target: recipient,
            value: 0,
            callData: abi.encodeCall(
                MockSimpleAccount.executeOne,
                (address(env.token2), abi.encodeCall(IERC20.transfer, (makeAddr("foobar"), 10)), hex"41414141")
            )
        });

        // Element for originChain 1 (Notarized chain)
        $intent.compact.elements
            .push(
                Element({
                    arbiter: arbiter,
                    chainId: notarizedChain,
                    idsAndAmounts: [toId(env.token1), 100].into(),
                    mandate: Mandate({
                        target: Target({
                            recipient: recipient,
                            tokenOut: [toId(env.token2), 20].into(),
                            targetChain: notarizedChain,
                            fillExpiry: uint32(block.timestamp + 1 hours)
                        }),
                        minGas: 0,
                        originOps: intent.noExec.toOperation(),
                        destOps: targetOpsOnEOA.toOperation(),
                        q: ""
                    })
                })
            );

        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(notarizedChain, $intent.claimHash);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        // env.smartAccount1.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: arbiter, data: "" });

        env.alwaysOKAllocator = new AlwaysOKAllocator();
        vm.prank(address(env.alwaysOKAllocator));
        uint96 newId = env.compact.__registerAllocator(address(env.alwaysOKAllocator), "");
        console2.log("New Allocator ID: %s", newId);
        bytes12 lockTag = IdLib.toLockTag(newId, env.scope, env.resetPeriod);
        console2.logBytes12(lockTag);
    }

    function test_fillSameChain() public {
        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

        order.targetOps = targetOpsOnEOA.toOperation();

        (bytes32 digest, bytes memory allocatorSig) = _allocatorSig(env.orchestrator, order.notarizedChainId, $intent.claimHash);

        (, bytes32[] memory otherElements) = $intent.elementHashes.withoutIndex(0);

        _fill({
            chainId: order.notarizedChainId,
            relayerContext: abi.encodePacked(env.solver.addr),
            adapterCalldata: abi.encodeCall(
                SameChainAdapter.samechain_compact_handleFill,
                (SameChainAdapter.FillDataCompact({
                        order: order,
                        userSigs: Types.Signatures($intent.userEmissarySig, ""),
                        otherElements: otherElements,
                        allocatorData: allocatorSig
                    }))
            )
        });
    }

    // Test with pre-claim ops where recipient != sponsor (target ops won't execute)
    function test_fillSameChain_EOA_withPreClaimOps_SkipsNoTargetExec() public {
        // First, ensure the sponsor account has tokens
        env.token3.mint(env.smartAccount1.account, 100 ether);
        env.token2.mint(env.smartAccount1.account, 100 ether);

        // Setup pre-claim operations that will call executeOne on the EOA
        Execution[] memory preClaimOps = new Execution[](2);

        // Pre-claim op 1: Call executeOne on EOA to transfer token2 somewhere
        bytes memory transferCalldata = abi.encodeCall(IERC20.transfer, (address(env.target), 5));
        bytes memory sig1 = _signHashRaw(env.eoa, keccak256(abi.encode(address(env.token2), transferCalldata)));

        preClaimOps[0] = Execution({
            target: address(env.eoa7702),
            value: 0,
            callData: abi.encodeCall(MockSimpleAccount.executeOne, (address(env.token2), transferCalldata, sig1))
        });

        // Pre-claim op 2: Call executeOne on EOA to approve token2
        bytes memory approveCalldata = abi.encodeCall(IERC20.approve, (address(env.target), 15));
        bytes memory sig2 = _signHashRaw(env.eoa, keccak256(abi.encode(address(env.token2), approveCalldata)));

        preClaimOps[1] = Execution({
            target: address(env.eoa7702),
            value: 0,
            callData: abi.encodeCall(MockSimpleAccount.executeOne, (address(env.token2), approveCalldata, sig2))
        });

        // Transfer token2 to the EOA so it can execute the operations
        vm.prank(env.smartAccount1.account);
        env.token2.transfer(address(env.eoa7702), 30);

        // Update the intent with pre-claim operations using MultiCall type
        $intent.compact.elements[0].mandate.originOps = preClaimOps.toOperationMulticall();

        // Recompute hashes with pre-claim operations included
        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(chains.originChain1, $intent.claimHash);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        // Check initial state
        uint256 targetToken2Before = env.token2.balanceOf(address(env.target));
        uint256 eoaToken2Before = env.token2.balanceOf(address(env.eoa7702));
        uint256 token2ApprovalBefore = env.token2.allowance(address(env.eoa7702), address(env.target));

        assertEq(targetToken2Before, 0, "Target should not have token2 initially");
        assertEq(eoaToken2Before, 30, "EOA should have 30 token2");
        assertEq(token2ApprovalBefore, 0, "Token2 approval should be 0 initially");

        // Create order and execute
        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

        // Override the preClaimOps encoding to use MultiCall type
        order.preClaimOps = preClaimOps.toOperationMulticall();

        // Target operations remain as defined
        order.targetOps = targetOpsOnEOA.toOperation();

        (bytes32 digest, bytes memory allocatorSig) = _allocatorSig(env.orchestrator, order.notarizedChainId, $intent.claimHash);
        (, bytes32[] memory otherElements) = $intent.elementHashes.withoutIndex(0);

        uint256 gas = _fill({
            chainId: order.notarizedChainId,
            relayerContext: abi.encodePacked(env.solver.addr),
            adapterCalldata: abi.encodeCall(
                SameChainAdapter.samechain_compact_handleFill,
                (SameChainAdapter.FillDataCompact({
                        order: order,
                        userSigs: Types.Signatures($intent.userEmissarySig, ""),
                        otherElements: otherElements,
                        allocatorData: allocatorSig
                    }))
            )
        });

        // Verify pre-claim operations were executed through EOA
        uint256 targetToken2After = env.token2.balanceOf(address(env.target));
        uint256 eoaToken2After = env.token2.balanceOf(address(env.eoa7702));
        uint256 token2ApprovalAfter = env.token2.allowance(address(env.eoa7702), address(env.target));

        assertEq(targetToken2After, 5, "Target should have received 5 token2 from EOA");
        // EOA should have: 30 (initial) + 20 (from solver) - 5 (transferred) = 45
        assertEq(eoaToken2After, 45, "EOA should have 45 token2 (30 initial + 20 from solver - 5 transferred)");
        assertEq(token2ApprovalAfter, 15, "Token2 approval should be set to 15");

        // Verify that target ops didn't execute (since recipient != sponsor)
        assertEq(env.token2.balanceOf(makeAddr("foobar")), 0, "Target ops should not have executed (recipient != sponsor)");
    }
}
