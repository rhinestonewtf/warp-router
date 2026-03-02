// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    PreClaimExecution_Unit_Test,
    MockArbiterForPreClaim,
    MockAddressBookForPreClaim,
    MockCompactIntentExecutorForPreClaim
} from "test/unit/base/arbiter/lib/PreClaimExecution/PreClaimExecution.t.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";

contract HandlePreClaimOpsCompactERC7579_Unit_Test is PreClaimExecution_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    MockCompactIntentExecutorForPreClaim internal mockCompactExecutor;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Deploy a fresh address book and compact executor
        addressBook = new MockAddressBookForPreClaim();
        mockCompactExecutor = new MockCompactIntentExecutorForPreClaim();
        addressBook.setExecutor(address(mockCompactExecutor));
        arbiter = new MockArbiterForPreClaim(address(addressBook));
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createTestOrder() internal view returns (Types.Order memory) {
        Types.Operation memory preClaimOps = _buildERC7579Ops();
        Types.Operation memory targetOps = Types.Operation({ data: "" });
        uint256[2][] memory emptyTokens = new uint256[2][](0);

        return Types.Order({
            sponsor: account,
            recipient: account,
            nonce: 1,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 1800,
            notarizedChainId: block.chainid,
            targetChainId: block.chainid,
            tokenIn: emptyTokens,
            tokenOut: emptyTokens,
            packedGasValues: 0,
            preClaimOps: preClaimOps,
            targetOps: targetOps,
            qualifier: ""
        });
    }

    function _createElementStub() internal pure returns (ICompactIntentExecutor.EIP712ElementStubOrigin memory) {
        bytes32[] memory otherElements = new bytes32[](1);
        otherElements[0] = keccak256("element1");

        return ICompactIntentExecutor.EIP712ElementStubOrigin({
            otherElements: otherElements,
            minGas: 0,
            elementOffset: 0,
            destOpsHash: keccak256("dest"),
            tokenInHash: keccak256("token"),
            targetAttributesHash: keccak256("attrs"),
            qHash: keccak256("q")
        });
    }

    /* //////////////////////////////////////////////////////////////
                            BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handlePreClaimOpsCompactERC7579_Success() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        assertTrue(success);
    }

    function test_handlePreClaimOpsCompactERC7579_RevertsWhen_InsufficientGas() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        try arbiter.callHandlePreClaimOpsCompactERC7579{ gas: 10_000 }(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        ) {
            fail("Should have reverted with InsufficientGasForMinGas");
        } catch (bytes memory revertData) {
            bytes4 selector = bytes4(revertData);
            assertEq(selector, bytes4(keccak256("InsufficientGasForMinGas(uint256,uint256)")));
        }
    }

    function test_handlePreClaimOpsCompactERC7579_ExecutorReverts_ReturnsFalse_ClaimFirst() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // In claim-first: success = okGas && okSig. Executor reverted so okGas=false => false.
        assertFalse(success);
    }

    /* //////////////////////////////////////////////////////////////
                     SIGNATURE SELECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handlePreClaimOpsCompactERC7579_UsesPreClaimSig_WhenNonEmpty() public {
        Types.Order memory order = _createTestOrder();
        bytes memory preClaimSig = hex"aabbccdd";
        bytes memory notarizedSig = hex"11223344";
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: preClaimSig, notarizedClaimSig: notarizedSig });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        assertTrue(success);

        // Verify the executor received preClaimSig (not notarizedClaimSig)
        bytes memory received = mockCompactExecutor.lastSignatureReceived();
        assertEq(keccak256(received), keccak256(preClaimSig), "Should use preClaimSig when non-empty");
    }

    function test_handlePreClaimOpsCompactERC7579_FallsBackToNotarizedClaimSig_WhenPreClaimSigEmpty() public {
        Types.Order memory order = _createTestOrder();
        bytes memory notarizedSig = hex"11223344";
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: notarizedSig });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        assertTrue(success);

        // Verify the executor received notarizedClaimSig as fallback
        bytes memory received = mockCompactExecutor.lastSignatureReceived();
        assertEq(keccak256(received), keccak256(notarizedSig), "Should fall back to notarizedClaimSig when preClaimSig is empty");
    }

    /* //////////////////////////////////////////////////////////////
                    SIGMODE BRANCHING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice EMISSARY mode: success = !okGas || okSig
    ///         When okGas=true and okSig=false => !true || false = false (not revert)
    function test_handlePreClaimOpsCompactERC7579_EmissaryMode_FailureTolerant() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor succeeds (okGas=true) but reports invalid signature (okSig=false)
        mockCompactExecutor.setSigOkReturn(false);
        mockCompactExecutor.setExecOkReturn(false);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // EMISSARY: !okGas || okSig = !true || false = false
        // Returns false but does NOT revert
        assertFalse(success);
    }

    /// @notice EMISSARY mode: when executor call itself fails (reverts), okGas=false
    ///         success = !okGas || okSig = !false || false = true
    ///         This demonstrates EMISSARY's failure tolerance: skips pre-claim on call failure
    function test_handlePreClaimOpsCompactERC7579_EmissaryMode_CallFails_SkipsPreClaim() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor reverts => excessivelySafeCall returns okGas=false
        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        // EMISSARY: !okGas || okSig = !false || false = true (skip pre-claim gracefully)
        assertTrue(success);
    }

    /// @notice EMISSARY mode: okGas=true, okSig=true => !true || true = true
    function test_handlePreClaimOpsCompactERC7579_EmissaryMode_AllSuccess() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );

        assertTrue(success);
    }

    /// @notice Claim-first mode (ERC1271): success = okGas && okSig
    ///         When okGas=true and okSig=false => true && false = false
    function test_handlePreClaimOpsCompactERC7579_ClaimFirstMode_SigInvalid_ReturnsFalse() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor succeeds (okGas=true) but reports invalid signature (okSig=false)
        mockCompactExecutor.setSigOkReturn(false);
        mockCompactExecutor.setExecOkReturn(false);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // Claim-first: okGas && okSig = true && false = false
        assertFalse(success);
    }

    /// @notice Claim-first mode (ERC1271): when executor call itself fails (reverts), okGas=false
    ///         success = okGas && okSig = false && false = false
    function test_handlePreClaimOpsCompactERC7579_ClaimFirstMode_CallFails_ReturnsFalse() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );

        // Claim-first: okGas && okSig = false && false = false
        assertFalse(success);
    }

    /// @notice EMISSARY_ERC1271 mode uses the same EMISSARY-like branch (failure-tolerant)
    ///         According to the source: only EMISSARY gets the !okGas || okSig path.
    ///         EMISSARY_ERC1271 uses the claim-first path: okGas && okSig.
    function test_handlePreClaimOpsCompactERC7579_EmissaryErc1271Mode_UsesClaimFirstLogic() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor reverts => okGas=false
        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY_ERC1271
        );

        // EMISSARY_ERC1271 != EMISSARY, so claim-first logic applies: okGas && okSig = false && false = false
        assertFalse(success);
    }

    /// @notice ERC1271_EMISSARY mode also uses claim-first path (only exact EMISSARY gets tolerance)
    function test_handlePreClaimOpsCompactERC7579_Erc1271EmissaryMode_UsesClaimFirstLogic() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor reverts => okGas=false
        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271_EMISSARY
        );

        // ERC1271_EMISSARY != EMISSARY, so claim-first logic: okGas && okSig = false && false = false
        assertFalse(success);
    }

    /// @notice EMISSARY_EXECUTION mode also uses claim-first path
    function test_handlePreClaimOpsCompactERC7579_EmissaryExecutionMode_UsesClaimFirstLogic() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        // Executor reverts => okGas=false
        mockCompactExecutor.setShouldRevert(true);

        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY_EXECUTION
        );

        // EMISSARY_EXECUTION != EMISSARY, so claim-first logic: false && false = false
        assertFalse(success);
    }

    /// @notice Verify EMISSARY is the only mode that tolerates call failures
    ///         When executor reverts, EMISSARY returns true but all other modes return false
    function test_handlePreClaimOpsCompactERC7579_OnlyEmissaryToleratesCallFailure() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setShouldRevert(true);

        // EMISSARY tolerates call failure
        bool emissaryResult = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY
        );
        assertTrue(emissaryResult, "EMISSARY should tolerate call failure");

        // All other modes fail on call failure
        bool erc1271Result = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271
        );
        assertFalse(erc1271Result, "ERC1271 should NOT tolerate call failure");

        bool emissaryErc1271Result = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY_ERC1271
        );
        assertFalse(emissaryErc1271Result, "EMISSARY_ERC1271 should NOT tolerate call failure");

        bool erc1271EmissaryResult = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.ERC1271_EMISSARY
        );
        assertFalse(erc1271EmissaryResult, "ERC1271_EMISSARY should NOT tolerate call failure");

        bool emissaryExecResult = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, GAS_STIPEND, SmartExecutionLib.SigMode.EMISSARY_EXECUTION
        );
        assertFalse(emissaryExecResult, "EMISSARY_EXECUTION should NOT tolerate call failure");
    }

    /* //////////////////////////////////////////////////////////////
                        ZERO GAS STIPEND TEST
    //////////////////////////////////////////////////////////////*/

    function test_handlePreClaimOpsCompactERC7579_ZeroGasStipend_SkipsGasCheck() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        // Zero gas stipend skips _requireValidGasLeft but forwards 0 gas to subcall
        // The subcall will fail (okGas=false) since 0 gas is forwarded
        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, 0, SmartExecutionLib.SigMode.EMISSARY
        );

        // EMISSARY: !okGas || okSig = !false || false = true (tolerance for call failure)
        assertTrue(success);
    }

    function test_handlePreClaimOpsCompactERC7579_ZeroGasStipend_ClaimFirst_Fails() public {
        Types.Order memory order = _createTestOrder();
        Types.Signatures memory sigs = Types.Signatures({ preClaimSig: "", notarizedClaimSig: hex"5678" });
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub = _createElementStub();

        mockCompactExecutor.setSigOkReturn(true);
        mockCompactExecutor.setExecOkReturn(true);

        // Zero gas stipend: subcall gets 0 gas so it fails (okGas=false)
        bool success = arbiter.callHandlePreClaimOpsCompactERC7579(
            account, order, sigs, elementStub, block.chainid, 0, SmartExecutionLib.SigMode.ERC1271
        );

        // Claim-first: okGas && okSig = false && false = false
        assertFalse(success);
    }
}
