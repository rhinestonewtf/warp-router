import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { EIP712TypeHashLib } from "src/types/EIP712TypeHashLib.sol";

contract SameChainMultiTokenTest is CompactEnvironment {
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
        _lockAssets(env.smartAccount1, env.token2, 50 ether);

        adapter = env.sameChainAdapter;
        arbiter = address(adapter.ARBITER());

        _setFillRoute(SameChainAdapter.samechain_compact_handleFill.selector, address(adapter));

        // test
        _sampleExecERC20(env.token2, 10);

        address recipient = env.smartAccount1.account;
        uint256 depositId = 1337;

        $intent.compact.sponsor = env.smartAccount1.account;
        $intent.compact.nonce = 1337;
        $intent.compact.expires = 4141;

        uint256 notarizedChain = chains.originChain1;

        env.alwaysOKAllocator = new AlwaysOKAllocator();
        vm.prank(address(env.alwaysOKAllocator));
        uint96 newId = env.compact.__registerAllocator(address(env.alwaysOKAllocator), "");
        bytes12 lockTag = IdLib.toLockTag(newId, env.scope, env.resetPeriod);
    }

    function test_fillSameChain_SingleToken() public {
        address recipient = env.smartAccount1.account;
        uint256 notarizedChain = chains.originChain1;

        Execution[] memory targetExecutions = new Execution[](1);
        targetExecutions[0] =
            Execution({ target: address(env.token2), value: 0, callData: abi.encodeCall(IERC20.transfer, (address(env.target), 20)) });

        // Element for originChain 1 (Notarized chain) with SINGLE token
        $intent.compact.elements
            .push(
                Element({
                    arbiter: arbiter,
                    chainId: notarizedChain,
                    idsAndAmounts: [toId(env.token1), 100].into(), // Single token
                    mandate: Mandate({
                        target: Target({
                            recipient: recipient,
                            tokenOut: [toId(env.token2), 20].into(),
                            targetChain: notarizedChain,
                            fillExpiry: uint32(block.timestamp + 1 hours)
                        }),
                        minGas: 0,
                        originOps: intent.noExec.toOperation(),
                        destOps: targetExecutions.toOperation(),
                        q: ""
                    })
                })
            );

        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(notarizedChain, $intent.claimHash);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

        // Verify single token path will be used
        assertEq(order.tokenIn.length, 1, "Should have single token");

        bytes32 typehashCompact = EIP712TypeHashLib.TYPEHASH_COMPACT;

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

        console2.log("gas (single token)", gas);
    }

    function test_fillSameChain_MultipleTokens() public {
        address recipient = env.smartAccount1.account;
        uint256 notarizedChain = chains.originChain1;

        // Element for originChain 1 (Notarized chain) with MULTIPLE tokens
        uint256[2][] memory idsAndAmounts = new uint256[2][](2);
        idsAndAmounts[0] = [toId(env.token1), 100];
        idsAndAmounts[1] = [toId(env.token2), 50];

        $intent.compact.elements
            .push(
                Element({
                    arbiter: arbiter,
                    chainId: notarizedChain,
                    idsAndAmounts: idsAndAmounts, // Multiple tokens
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

        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(notarizedChain, $intent.claimHash);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

        // Verify multiple token path will be used
        assertEq(order.tokenIn.length, 2, "Should have multiple tokens");

        bytes32 typehashCompact = EIP712TypeHashLib.TYPEHASH_COMPACT;

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

        console2.log("gas (multiple tokens)", gas);
    }
}
