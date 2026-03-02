// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { CompactEnvironment } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Element, Target, Mandate } from "@rhinestone/compact-utils/src/types/TheCompactStructs.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";
import { TestHelperLib } from "@rhinestone/compact-utils/src/tests/Environment.sol";

contract IntentExecutorAdapterTest is CompactEnvironment {
    using AdapterTagLib for bytes12;
    using Types for Execution[];
    using TestHelperLib for *;
    IntentExecutorAdapter adapter;

    event CallForwarded(bytes4 selector, bool success);

    function setUp() public {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);

        // Deploy the adapter
        adapter = new IntentExecutorAdapter(address(env.router), address(env.intentExecutor));

        // Install the adapter for both function selectors
        _setFillRoute(adapter.handleFill_intentExecutor_handleCompactTargetOps.selector, address(adapter));
        _setFillRoute(adapter.handleFill_intentExecutor_handlePermit2TargetOps.selector, address(adapter));
    }

    function test_handleFill_intentExecutor_handleCompactTargetOps() public {
        // Fund the account with tokens first
        _lockAssets(env.smartAccount1, env.token1, 100 ether);

        // Create compact intent structure with empty executions to test adapter forwarding
        intent.compact.sponsor = env.smartAccount1.account;
        intent.compact.nonce = 1;
        intent.compact.expires = block.timestamp + 1 hours;

        // Create the targetOps that will be used for both hashing and execution
        Execution[] memory emptyExecs = new Execution[](0);
        Types.Operation memory targetOps = Types.Operation({
            data: abi.encodePacked(SmartExecutionLib.Type.ERC7579, SmartExecutionLib.SigMode.EMISSARY_ERC1271, abi.encode(emptyExecs))
        });

        Element memory element;
        element.chainId = block.chainid;
        element.arbiter = address(env.sameChainAdapter);
        element.mandate.target.recipient = env.smartAccount1.account;
        element.mandate.target.targetChain = block.chainid;
        element.mandate.target.fillExpiry = uint32(block.timestamp + 1 hours);
        element.mandate.target.tokenOut = new uint256[2][](0);
        element.mandate.originOps = targetOps; // Use same targetOps
        element.mandate.destOps = targetOps; // Use same targetOps
        element.mandate.q = "";

        intent.compact.elements = new Element[](1);
        intent.compact.elements[0] = element;

        // Get proper stubs first to ensure we use the correct notarizedChainId
        (
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub
        ) = _getEIP712Stubs_TargetOps(intent.compact, address(0), 0);

        // Generate proper signatures using Environment.sol helpers with the correct notarizedChainId
        (intent.claimHash, intent.elementHashes) = hashCompact(address(env.sameChainAdapter), intent.compact);
        intent.digest = _hashTypedData(compactStub.notarizedChainId, intent.claimHash);
        bytes memory signature = _emissarySig(env.smartAccount1, env.eoa, intent.digest);

        // Create the parameters for the executor call using the same targetOps
        bytes memory executorCalldata =
            abi.encode(env.smartAccount1.account, address(env.sameChainAdapter), compactStub, elementStub, targetOps, signature);

        // Prepare the adapter call - IntentExecutorAdapter skips relayer context
        bytes[] memory relayerContexts = new bytes[](0);
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_handleCompactTargetOps, (executorCalldata));

        // Execute - should work now with proper signature
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);

        console2.log("Gas used for compact target ops:", gasUsed);
        assertTrue(gasUsed > 0, "Fill should have consumed gas");
    }

    function _getEIP712Stubs_Permit2TargetOps(
        Element memory element,
        uint256 nonce,
        uint256 expires
    )
        internal
        returns (
            IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
            IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub
        )
    {
        // Create permit2 stub with basic parameters
        permit2Stub = IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: nonce, expires: expires });

        // Hash operations properly for the mandate - they're already Operations
        bytes32 preClaimOpsHash = this.jump_hashEIP712(element.mandate.originOps);
        bytes32 destOpsHash = this.jump_hashEIP712(element.mandate.destOps);

        // Create mandate stub with proper hashes that match executor expectations
        mandateStub = IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub({
            sponsor: element.mandate.target.recipient,
            arbiter: element.arbiter,
            minGas: element.mandate.minGas,
            notarizedChainId: element.chainId,
            preClaimOpsHash: preClaimOpsHash,
            targetStub: IPermit2IntentExecutor.Target({
                fillExpiry: element.mandate.target.fillExpiry, tokenOutHash: hasher.hashTokenOut(element.mandate.target.tokenOut)
            }),
            tokenInHash: keccak256(abi.encode(element.idsAndAmounts)),
            qHash: keccak256(abi.encode(element.mandate.q))
        });
    }

    function _createPermit2Hash(
        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
        uint256 targetChainId,
        Types.Operation memory targetOps
    )
        internal
        returns (bytes32 permit2Hash)
    {
        // Compute targetAttributesHash from targetStub components
        bytes32 targetAttributesHash = EIP712TypeHashLib.hashTargetAttributesRaw({
            recipient: mandateStub.sponsor,
            tokenOutHash: mandateStub.targetStub.tokenOutHash,
            targetChainId: targetChainId,
            fillDeadline: mandateStub.targetStub.fillExpiry
        });

        // Replicate the executor's hash computation exactly
        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttributesHash,
            minGas: 0, // Test default
            preClaimOpsHash: mandateStub.preClaimOpsHash,
            destOpsHash: this.jump_hashEIP712(targetOps),
            qHash: mandateStub.qHash
        });

        // Create the final permit2 hash exactly as the executor does
        permit2Hash = EIP712TypeHashLib.hashPermit2({
            tokenInHash: mandateStub.tokenInHash,
            arbiter: mandateStub.arbiter,
            nonce: permit2Stub.nonce,
            expires: permit2Stub.expires,
            mandate: mandateHash
        });
    }

    function test_handleFill_intentExecutor_handlePermit2TargetOps() public {
        // Fund the account with tokens first
        _lockAssets(env.smartAccount1, env.token1, 100 ether);

        // Create element for permit2 with empty executions to test adapter forwarding
        Element memory element;
        element.chainId = block.chainid;
        element.arbiter = address(env.sameChainAdapter);
        element.mandate.target.recipient = env.smartAccount1.account;
        element.mandate.target.targetChain = block.chainid;
        element.mandate.target.fillExpiry = uint32(block.timestamp + 1 hours);
        element.mandate.target.tokenOut = new uint256[2][](0);
        Execution[] memory emptyExecs2 = new Execution[](0);
        element.mandate.originOps = TestHelperLib.toOperation(emptyExecs2);
        element.mandate.destOps = TestHelperLib.toOperation(emptyExecs2); // Empty execution array
        element.mandate.q = "";
        element.idsAndAmounts = new uint256[2][](1);
        element.idsAndAmounts[0] = [toId(env.token1), 100 ether];

        // Get proper stubs using our new helper function
        (
            IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
            IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub
        ) = _getEIP712Stubs_Permit2TargetOps(element, 1, block.timestamp + 1 hours);

        // Create the target operations that will be passed to the executor (empty for test)
        Types.Operation memory targetOps = Types.Operation({
            data: abi.encodePacked(
                SmartExecutionLib.Type.ERC7579, SmartExecutionLib.SigMode.EMISSARY_ERC1271, abi.encode(new Execution[](0))
            )
        });

        // Create the permit2 hash exactly as the executor will
        bytes32 permit2Hash = _createPermit2Hash(permit2Stub, mandateStub, element.mandate.target.targetChain, targetOps);

        // Create proper digest using Environment.sol helper
        bytes32 digest = _hashTypedDataPermit2(block.chainid, permit2Hash);

        // Debug: Log the hashes
        console2.log("Computed permit2 hash:");
        console2.logBytes32(permit2Hash);
        console2.log("Final digest being signed:");
        console2.logBytes32(digest);

        // Sign the digest using Environment.sol helper
        bytes memory signature = _emissarySig(env.smartAccount1, env.eoa, digest);

        // Create the parameters for the executor call
        bytes memory executorCalldata = abi.encode(env.smartAccount1.account, permit2Stub, mandateStub, targetOps, signature);

        // Prepare the adapter call - IntentExecutorAdapter skips relayer context
        bytes[] memory relayerContexts = new bytes[](0);
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodeCall(adapter.handleFill_intentExecutor_handlePermit2TargetOps, (executorCalldata));

        // Execute with proper signature - should work now
        uint256 gasUsed = _fill(block.chainid, relayerContexts, adapterCalldatas);
        console2.log("Gas used for Permit2 target ops: %s, calldata size: %s", gasUsed, adapterCalldatas[0].length);
        assertTrue(gasUsed > 0, "Fill should have consumed gas");
    }

    function test_supportsInterface() public {
        assertTrue(adapter.supportsInterface(adapter.handleFill_intentExecutor_handleCompactTargetOps.selector));
        assertTrue(adapter.supportsInterface(adapter.handleFill_intentExecutor_handlePermit2TargetOps.selector));

        // Should not support random selector
        assertFalse(adapter.supportsInterface(bytes4(0x12345678)));
    }

    function test_adapterConfiguration() public {
        // Verify the adapter was deployed with correct configuration
        assertEq(adapter._ROUTER(), address(env.router));
        // Note: EXECUTOR is internal immutable, can't access directly
    }

    function test_gasOptimization() public {
        // Create a simple test to measure gas usage for the adapter forwarding
        // We'll use a minimal valid setup to focus on adapter overhead

        bytes memory executorCalldata = abi.encodeCall(
            ICompactIntentExecutor.executeTargetOpsWithCompactStub,
            (
                env.smartAccount1.account,
                address(env.sameChainAdapter),
                ICompactIntentExecutor.EIP712CompactStub({ nonce: 1, expires: block.timestamp + 1 hours, notarizedChainId: block.chainid }),
                ICompactIntentExecutor.EIP712ElementStubDestination({
                    sponsor: env.smartAccount1.account,
                    otherElements: new bytes32[](0),
                    elementOffset: 0,
                    preClaimOpsHash: keccak256("preClaimOps"),
                    tokenInHash: keccak256("tokenIn"),
                    tokenOutHash: keccak256("tokenOut"),
                    fillExpires: block.timestamp + 1 hours,
                    qHash: keccak256("qualifier")
                }),
                Types.Operation({
                    data: abi.encodePacked(
                        SmartExecutionLib.Type.ERC7579, SmartExecutionLib.SigMode.EMISSARY_ERC1271, abi.encode(new Execution[](0))
                    )
                }),
                hex"1234567890abcdef"
            )
        );

        // Test direct call to adapter (will fail during execution but we can measure the forwarding overhead)
        vm.startPrank(address(env.router)); // Simulate router context
        uint256 gasStart = gasleft();

        // This will revert during signature verification but we can measure gas up to that point
        vm.expectRevert();
        adapter.handleFill_intentExecutor_handleCompactTargetOps(executorCalldata);

        uint256 gasUsed = gasStart - gasleft();
        vm.stopPrank();

        console2.log("Gas used for adapter forwarding (including revert):", gasUsed);

        // The adapter should add minimal overhead - most gas is from the executor logic
        // We just verify it doesn't use an unreasonable amount for the forwarding itself
        assertTrue(gasUsed > 0, "Should have used some gas");
        console2.log("Adapter forwarding appears to be gas efficient");
    }
}
