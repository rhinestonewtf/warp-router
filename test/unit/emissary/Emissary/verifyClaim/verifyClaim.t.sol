// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Emissary_Unit_Test, MockStatelessValidatorForEmissary, RejectingStatelessValidator, RevertingStatelessValidator } from "test/unit/emissary/Emissary/Emissary.t.sol";
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";

contract VerifyClaim_Unit_Test is Emissary_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        ECDSA VERIFY CLAIM
    //////////////////////////////////////////////////////////////*/

    function _setupECDSAConfig() internal {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);

        bytes32 digest =
            env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    function test_verifyClaim_ECDSA_ValidSigner() public {
        _setupECDSAConfig();

        bytes32 testDigest = keccak256("test claim");
        bytes memory ecdsaSig = _signHashRaw(newSigner, testDigest);
        bytes memory emissaryData = abi.encodePacked(address(0x1), uint8(1), ecdsaSig);

        bytes4 ret =
            env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, env.emissary.verifyClaim.selector);
    }

    function test_verifyClaim_ECDSA_InvalidSigner() public {
        _setupECDSAConfig();

        // Sign with the wrong signer
        bytes32 testDigest = keccak256("test claim");
        bytes memory ecdsaSig = _signHashRaw(wrongSigner, testDigest);
        bytes memory emissaryData = abi.encodePacked(address(0x1), uint8(1), ecdsaSig);

        bytes4 ret =
            env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, bytes4(0xFFFFFFFF));
    }

    function test_verifyClaim_ECDSA_NoConfig_RevertsWithNotSet() public {
        // Don't configure any ECDSA signer - loadAddress reverts with NotSet()
        bytes32 testDigest = keccak256("test claim");
        bytes memory ecdsaSig = _signHashRaw(newSigner, testDigest);
        bytes memory emissaryData = abi.encodePacked(address(0x1), uint8(1), ecdsaSig);

        // ECDSA path: loadAddress reverts because no signer is stored (address(0))
        vm.expectRevert();
        env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
    }

    /* //////////////////////////////////////////////////////////////
                    CUSTOM VALIDATOR VERIFY CLAIM
    //////////////////////////////////////////////////////////////*/

    function test_verifyClaim_CustomValidator_Valid() public {
        bytes memory customConfig = abi.encodePacked("custom config");
        env.emissary.mock_setConfig(
            env.smartAccount1.account, 3, env.lockTag, IStatelessValidator(address(mockValidator)), customConfig
        );

        bytes32 testDigest = keccak256("test claim");
        bytes memory emissaryData = abi.encodePacked(address(mockValidator), uint8(3), hex"aabbccdd");

        bytes4 ret =
            env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, env.emissary.verifyClaim.selector);
    }

    function test_verifyClaim_CustomValidator_NoConfig_ReturnsFalse() public {
        // Don't set any config for the custom validator (configData will be empty)
        bytes32 testDigest = keccak256("test claim");
        bytes memory emissaryData = abi.encodePacked(address(mockValidator), uint8(3), hex"aabbccdd");

        bytes4 ret =
            env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, bytes4(0xFFFFFFFF));
    }

    function test_verifyClaim_CustomValidator_ValidatorReturnsFalse() public {
        bytes memory customConfig = abi.encodePacked("custom config");
        env.emissary.mock_setConfig(
            env.smartAccount1.account, 3, env.lockTag, IStatelessValidator(address(rejectingValidator)), customConfig
        );

        bytes32 testDigest = keccak256("test claim");
        bytes memory emissaryData = abi.encodePacked(address(rejectingValidator), uint8(3), hex"aabbccdd");

        bytes4 ret =
            env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, bytes4(0xFFFFFFFF));
    }

    function test_verifyClaim_CustomValidator_ValidatorReverts() public {
        bytes memory customConfig = abi.encodePacked("custom config");
        env.emissary.mock_setConfig(
            env.smartAccount1.account, 3, env.lockTag, IStatelessValidator(address(revertingValidator)), customConfig
        );

        bytes32 testDigest = keccak256("test claim");
        bytes memory emissaryData = abi.encodePacked(address(revertingValidator), uint8(3), hex"aabbccdd");

        // Custom validator reverts - this should propagate the revert
        vm.expectRevert("validator reverted");
        env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
    }
}
