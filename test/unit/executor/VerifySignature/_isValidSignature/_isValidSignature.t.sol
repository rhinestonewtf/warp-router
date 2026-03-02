// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { VerifySignature_Unit_Test, MockEmissaryForVerify, MockSmartSessionEmissaryForVerify, Mock1271AccountForVerify, MockTheCompactForVerify } from "test/unit/executor/VerifySignature/VerifySignature.t.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract IsValidSignature_Unit_Test is VerifySignature_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        PURE ERC1271 MODE
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_ERC1271_ValidSig() public {
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_ERC1271_InvalidSig() public {
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                        PURE EMISSARY MODE
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_EMISSARY_ValidClaim() public {
        mockEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARY_NoEmissaryConfigured_ReturnsFalse() public {
        mockCompact.setEmissary(address(0));
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    function test_isValidSignature_EMISSARY_GetEmissaryStatusReverts_ReturnsFalse() public {
        mockCompact.setShouldRevert(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    function test_isValidSignature_EMISSARY_VerifyClaimReverts_ReturnsFalse() public {
        // getEmissaryStatus succeeds but verifyClaim on the emissary reverts
        mockEmissary.setShouldRevert(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                    PURE EMISSARY_EXECUTION MODE
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_EMISSARY_EXECUTION_ValidExecution() public {
        mockSmartSessionEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_EXECUTION);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARY_EXECUTION_RejectedExecution() public {
        mockSmartSessionEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_EXECUTION);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    function test_isValidSignature_EMISSARY_EXECUTION_VerifyExecutionReverts_ReturnsFalse() public {
        mockSmartSessionEmissary.setShouldRevert(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_EXECUTION);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                    HYBRID: EMISSARY_ERC1271
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_EMISSARY_ERC1271_EmissarySucceeds() public {
        mockEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_ERC1271);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARY_ERC1271_EmissaryFails_ERC1271Succeeds() public {
        mockEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_ERC1271);
        // Account's ERC1271 returns valid
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARY_ERC1271_BothFail() public {
        mockEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARY_ERC1271);
        // Account's ERC1271 also returns invalid
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                    HYBRID: ERC1271_EMISSARY
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_ERC1271_EMISSARY_ERC1271Succeeds() public {
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARY);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_ERC1271_EMISSARY_ERC1271Fails_EmissarySucceeds() public {
        mockEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARY);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_ERC1271_EMISSARY_BothFail() public {
        mockEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARY);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                HYBRID: EMISSARYEXECUTION_ERC1271
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_EMISSARYEXECUTION_ERC1271_ExecSucceeds() public {
        mockSmartSessionEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARYEXECUTION_ERC1271_ExecFails_ERC1271Succeeds() public {
        mockSmartSessionEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_EMISSARYEXECUTION_ERC1271_BothFail() public {
        mockSmartSessionEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.EMISSARYEXECUTION_ERC1271);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                HYBRID: ERC1271_EMISSARYEXECUTION
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_ERC1271_EMISSARYEXECUTION_ERC1271Succeeds() public {
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION);
        bool result = verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_ERC1271_EMISSARYEXECUTION_ERC1271Fails_ExecSucceeds() public {
        mockSmartSessionEmissary.setValid(true);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertTrue(result);
    }

    function test_isValidSignature_ERC1271_EMISSARYEXECUTION_BothFail() public {
        mockSmartSessionEmissary.setValid(false);
        Types.Operation memory ops = _buildOps(SmartExecutionLib.SigMode.ERC1271_EMISSARYEXECUTION);
        bool result = verifier.isValidSignature(address(invalidAccount), lockTag, digest, claimHash, ops, defaultSig);
        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_UnknownSigMode_Panics() public {
        // Build ops with an invalid sig mode byte (7, which is out of range for the enum)
        // Solidity panics with 0x21 when casting an invalid value to an enum type
        bytes memory data = abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(7), hex"00");
        Types.Operation memory ops = Types.Operation({ data: data });
        vm.expectRevert();
        verifier.isValidSignature(address(validAccount), lockTag, digest, claimHash, ops, defaultSig);
    }
}
