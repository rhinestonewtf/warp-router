import { FeeCollector } from "src/router/utils/FeeCollector.sol";
import { IDirectRoute } from "src/router/core/DirectRoutes.sol";
import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

contract SameChainBaseTest is CompactEnvironment {
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

    address constant FEE_RECIPIENT1 = address(0xFEE1);
    SameChainAdapter adapter;
    address arbiter;

    function setUp() public virtual {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);
        _lockAssets(env.smartAccount1, env.token1, 100 ether);

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

        // Log mandate hash to verify it's correct
        bytes32 mandateHash = hasher.hashMandate($intent.compact.elements[0].mandate);
        console2.log("TEST SIDE: Mandate hash:");
        console2.logBytes32(mandateHash);

        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(notarizedChain, $intent.claimHash);
        console2.log("TEST SIDE: ClaimHash:");
        console2.logBytes32($intent.claimHash);
        console2.log("TEST SIDE: Digest:");
        console2.logBytes32($intent.digest);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        env.alwaysOKAllocator = new AlwaysOKAllocator();
        vm.prank(address(env.alwaysOKAllocator));
        uint96 newId = env.compact.__registerAllocator(address(env.alwaysOKAllocator), "");
        bytes12 lockTag = IdLib.toLockTag(newId, env.scope, env.resetPeriod);
    }

    function test_fillSameChain_simple() public {
        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);

        vm.chainId(order.notarizedChainId);

        (bytes32 digest, bytes memory allocatorSig) = _allocatorSig(env.orchestrator, order.notarizedChainId, $intent.claimHash);

        (, bytes32[] memory otherElements) = $intent.elementHashes.withoutIndex(0);

        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(env.token1))), 100e18];
        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0] = [uint256(uint160(address(env.token1))), 1e18];
        tokenAndAmounts[1] = [uint256(uint160(address(env.token2))), 2e18];
        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts });

        bytes[] memory adapterCalldatas = new bytes[](2);
        adapterCalldatas[0] = abi.encodeCall(IDirectRoute.onFill_inRouter_collectFee, (fee));

        adapterCalldatas[1] = abi.encodeCall(
            SameChainAdapter.samechain_compact_handleFill,
            (SameChainAdapter.FillDataCompact({
                    order: order,
                    userSigs: Types.Signatures($intent.userEmissarySig, ""),
                    otherElements: otherElements,
                    allocatorData: allocatorSig
                }))
        );
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(env.solver.addr);

        // Fund the solver with tokens for fee payments
        env.token1.mint(env.solver.addr, 10e18);
        env.token2.mint(env.solver.addr, 10e18);

        // Approve the router to spend solver's tokens
        vm.startPrank(env.solver.addr);
        env.token1.approve(address(env.router), type(uint256).max);
        env.token2.approve(address(env.router), type(uint256).max);
        vm.stopPrank();

        // Record balances before
        uint256 recipient1Token1Before = env.token1.balanceOf(FEE_RECIPIENT1);
        uint256 recipient1Token2Before = env.token2.balanceOf(FEE_RECIPIENT1);

        uint256 gas = _fill({ chainId: order.notarizedChainId, relayerContexts: relayerContexts, adapterCalldatas: adapterCalldatas });

        // Verify fees were collected
        assertEq(env.token1.balanceOf(FEE_RECIPIENT1), recipient1Token1Before + 1e18, "FEE_RECIPIENT1 should receive 1e18 token1");
        assertEq(env.token2.balanceOf(FEE_RECIPIENT1), recipient1Token2Before + 2e18, "FEE_RECIPIENT1 should receive 2e18 token2");

        console2.log("gas", gas);
    }

    function test_fillSameChain_withMultipleFees() public {
        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

        (bytes32 digest, bytes memory allocatorSig) = _allocatorSig(env.orchestrator, order.notarizedChainId, $intent.claimHash);

        (, bytes32[] memory otherElements) = $intent.elementHashes.withoutIndex(0);

        // Create multiple fees for different recipients
        address FEE_RECIPIENT2 = address(0xFEE2);
        address FEE_RECIPIENT3 = address(0xFEE3);

        // Fee 1: token1 and token2 to RECIPIENT1
        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](2);
        tokenAndAmounts1[0] = [uint256(uint160(address(env.token1))), 1e18];
        tokenAndAmounts1[1] = [uint256(uint160(address(env.token2))), 2e18];
        FeeCollector.Fee memory fee1 = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts1 });

        // Fee 2: token1 and token3 to RECIPIENT2
        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](2);
        tokenAndAmounts2[0] = [uint256(uint160(address(env.token1))), 3e18];
        tokenAndAmounts2[1] = [uint256(uint160(address(env.token3))), 4e18];
        FeeCollector.Fee memory fee2 = FeeCollector.Fee({ recipient: FEE_RECIPIENT2, tokenAndAmounts: tokenAndAmounts2 });

        // Fee 3: just token2 to RECIPIENT3
        uint256[2][] memory tokenAndAmounts3 = new uint256[2][](1);
        tokenAndAmounts3[0] = [uint256(uint160(address(env.token2))), 5e18];
        FeeCollector.Fee memory fee3 = FeeCollector.Fee({ recipient: FEE_RECIPIENT3, tokenAndAmounts: tokenAndAmounts3 });

        // Create fees array
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](3);
        fees[0] = fee1;
        fees[1] = fee2;
        fees[2] = fee3;

        bytes[] memory adapterCalldatas = new bytes[](2);
        // Use the array version of fee collection
        adapterCalldatas[0] = abi.encodeCall(IDirectRoute.onFill_inRouter_collectFees, (fees));

        adapterCalldatas[1] = abi.encodeCall(
            SameChainAdapter.samechain_compact_handleFill,
            (SameChainAdapter.FillDataCompact({
                    order: order,
                    userSigs: Types.Signatures($intent.userEmissarySig, ""),
                    otherElements: otherElements,
                    allocatorData: allocatorSig
                }))
        );
        bytes[] memory relayerContexts = new bytes[](1);
        relayerContexts[0] = abi.encodePacked(env.solver.addr);

        // Fund the solver with tokens for fee payments
        env.token1.mint(env.solver.addr, 20e18);
        env.token2.mint(env.solver.addr, 20e18);
        env.token3.mint(env.solver.addr, 20e18);

        // Approve the router to spend solver's tokens
        vm.startPrank(env.solver.addr);
        env.token1.approve(address(env.router), type(uint256).max);
        env.token2.approve(address(env.router), type(uint256).max);
        env.token3.approve(address(env.router), type(uint256).max);
        vm.stopPrank();

        // Record balances before
        uint256 recipient1Token1Before = env.token1.balanceOf(FEE_RECIPIENT1);
        uint256 recipient1Token2Before = env.token2.balanceOf(FEE_RECIPIENT1);
        uint256 recipient2Token1Before = env.token1.balanceOf(FEE_RECIPIENT2);
        uint256 recipient2Token3Before = env.token3.balanceOf(FEE_RECIPIENT2);
        uint256 recipient3Token2Before = env.token2.balanceOf(FEE_RECIPIENT3);

        uint256 gas = _fill({ chainId: order.notarizedChainId, relayerContexts: relayerContexts, adapterCalldatas: adapterCalldatas });

        // Verify all fees were collected correctly
        assertEq(env.token1.balanceOf(FEE_RECIPIENT1), recipient1Token1Before + 1e18, "RECIPIENT1 should receive 1e18 token1");
        assertEq(env.token2.balanceOf(FEE_RECIPIENT1), recipient1Token2Before + 2e18, "RECIPIENT1 should receive 2e18 token2");
        assertEq(env.token1.balanceOf(FEE_RECIPIENT2), recipient2Token1Before + 3e18, "RECIPIENT2 should receive 3e18 token1");
        assertEq(env.token3.balanceOf(FEE_RECIPIENT2), recipient2Token3Before + 4e18, "RECIPIENT2 should receive 4e18 token3");
        assertEq(env.token2.balanceOf(FEE_RECIPIENT3), recipient3Token2Before + 5e18, "RECIPIENT3 should receive 5e18 token2");

        console2.log("gas (multiple fees)", gas);
    }

    function test_fillSameChain_withPreClaimOps() public {
        // Setup pre-claim operations
        Execution[] memory preClaimOps = new Execution[](2);

        // Mint tokens for the operations
        env.token3.mint(env.smartAccount1.account, 100 ether);

        // Pre-claim op 1: Approve token3
        preClaimOps[0] =
            Execution({ target: address(env.token3), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 50 ether)) });

        // Pre-claim op 2: Call target function with ETH value
        preClaimOps[1] =
            Execution({ target: address(env.target), value: 0.5 ether, callData: abi.encodeCall(MockTarget.targetFn, (12_345)) });

        // Deal ETH to the account for the value transfer
        vm.deal(env.smartAccount1.account, 1 ether);

        // Update the intent with pre-claim operations
        $intent.compact.elements[0].mandate.originOps = preClaimOps.toOperation();

        // Recompute hashes with pre-claim operations included
        ($intent.claimHash, $intent.elementHashes) = hashCompact(arbiter, $intent.compact);
        $intent.digest = _hashTypedData(chains.originChain1, $intent.claimHash);
        $intent.userEmissarySig = _emissarySig({ smartAccount: env.smartAccount1, with: env.eoa, digest: $intent.digest });

        // Check initial state
        uint256 token3AllowanceBefore = env.token3.allowance(env.smartAccount1.account, address(env.target));
        uint256 targetParamBefore = env.target.param();
        uint256 accountBalanceBefore = env.smartAccount1.account.balance;

        assertEq(token3AllowanceBefore, 0, "Token3 allowance should be 0 initially");

        // Create order and execute
        Types.Order memory order = _getOrder($intent.compact, 0, 300_000);
        vm.chainId(order.notarizedChainId);

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

        // Verify pre-claim operations were executed
        uint256 token3AllowanceAfter = env.token3.allowance(env.smartAccount1.account, address(env.target));
        uint256 targetParamAfter = env.target.param();
        uint256 accountBalanceAfter = env.smartAccount1.account.balance;

        assertEq(token3AllowanceAfter, 50 ether, "Token3 should be approved for 50 ether");
        assertEq(targetParamAfter, 12_345, "Target param should be set by pre-claim op");
        assertLt(accountBalanceAfter, accountBalanceBefore, "Account should have spent ETH");

        // Verify the main transfer still happened
        assertEq(env.token2.balanceOf(env.smartAccount1.account), 10, "Account should have received token2");

        console2.log("gas with pre-claim ops:", gas);
    }
}
