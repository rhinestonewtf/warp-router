import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

contract SameChainJITTest is CompactEnvironment {
    using ModuleKitHelpers for *;
    using TestHelperLib for *;
    using Types for Execution[];

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

    function setUp() public virtual {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);
        _lockAssets(env.smartAccount1, env.token1, 100 ether);

        adapter = env.sameChainAdapter;
        arbiter = address(env.router.CALLER());

        _setFillRoute(SameChainAdapter.samechain_compact_handleFill.selector, address(adapter));

        // test
        _sampleExecERC20(env.token2, 10);

        address recipient = env.smartAccount1.account;
        uint256 depositId = 1337;

        $intent.compact.sponsor = env.smartAccount1.account;
        $intent.compact.nonce = 1337;
        $intent.compact.expires = 4141;

        uint256 notarizedChain = chains.originChain1;

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
                        originOps: intent.targetExecutions.toOperation(),
                        destOps: intent.targetExecutions.toOperation(),
                        q: ""
                    })
                })
            );

        Execution[] memory sendFundsToSolver = new Execution[](1);
        sendFundsToSolver[0] = Execution({
            target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (address(env.router.CALLER()), 100))
        });

        // Element for originChain 1 (this wont go over the compact)
        $intent.compact.elements
            .push(
                Element({
                    arbiter: arbiter,
                    chainId: notarizedChain,
                    idsAndAmounts: new uint256[2][](0),
                    mandate: Mandate({
                        target: Target({
                            recipient: recipient,
                            tokenOut: new uint256[2][](0),
                            targetChain: notarizedChain,
                            fillExpiry: uint32(block.timestamp + 1 hours)
                        }),
                        minGas: 0,
                        originOps: sendFundsToSolver.toOperation(),
                        destOps: intent.noExec.toOperation(),
                        q: ""
                    })
                })
            );

        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(notarizedChain, $intent.claimHash);
        console2.logBytes32($intent.digest);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        env.alwaysOKAllocator = new AlwaysOKAllocator();
        vm.prank(address(env.alwaysOKAllocator));
        uint96 newId = env.compact.__registerAllocator(address(env.alwaysOKAllocator), "");
        console2.log("New Allocator ID: %s", newId);
        bytes12 lockTag = IdLib.toLockTag(newId, env.scope, env.resetPeriod);
        console2.logBytes12(lockTag);
    }

    // function test_execViaMulticallAdapter() public {
    // Types.Order memory order = _getOrder($intent.compact, 1, 300_000);
    // vm.chainId(order.notarizedChainId);

    // bytes32 qualifiedHash;
    // (bytes32 digest, bytes memory allocatorSig) = _allocatorSig(env.orchestrator, order.notarizedChainId, $intent.claimHash);

    // env.token1.mint(env.smartAccount1.account, 100 ether);
    // // Mint token1 to MultiCallAdapter for the JIT claim transfer
    // env.token1.mint(address(env.multicallAdapter), 100);
    // // Mint token2 to solver so they can fulfill the order (recipient expects 20 token2)
    // env.token2.mint(env.solver.addr, 20 ether);

    // console2.log("ElementHashes");
    // for (uint256 i; i < $intent.elementHashes.length; i++) {
    // console2.logBytes32($intent.elementHashes[i]);
    //}

    // Execution[] memory multiCalls = new Execution[](1);
    // multiCalls[0] = Execution({
    // target: address(env.intentExecutor),
    // value: 0,
    // callData: _toIntentExecutorCall_preClaimOps($intent.compact, 1, $intent.userEmissarySig)
    // });

    // _claim({
    // chainId: order.notarizedChainId,
    // relayerContext: abi.encodePacked(env.solver.addr),
    // adapterCalldata: abi.encodeCall(
    // MultiCallAdapter.multicall_handleJITClaim,
    // (MultiCallAdapter.JITClaimData({ tokenIn: [toId(env.token1), 100].into(), multicalls: multiCalls }))
    //)
    // });
    //}
}
