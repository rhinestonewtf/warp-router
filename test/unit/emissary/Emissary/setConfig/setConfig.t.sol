// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Emissary_Unit_Test } from "test/unit/emissary/Emissary/Emissary.t.sol";
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { Emissary } from "@rhinestone/compact-utils/src/emissary/Emissary.sol";

contract SetConfig_Unit_Test is Emissary_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        REVERT EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_RevertsWhen_WrongChainId() public {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));

        // Create chain IDs that don't contain the current chain ID
        uint256[] memory wrongChainIds = new uint256[](1);
        wrongChainIds[0] = block.chainid + 1; // wrong chain ID

        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, wrongChainIds, 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);

        vm.prank(env.smartAccount1.account);
        vm.expectRevert(Emissary.InvalidSignature.selector);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    function test_setConfig_RevertsWhen_Expired() public {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));

        // expires is in the past
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp - 1, _chainIds(), 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);

        vm.prank(env.smartAccount1.account);
        vm.expectRevert(Emissary.InvalidSignature.selector);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    function test_setConfig_RevertsWhen_NonceNotMonotonic() public {
        // First: do initial setup with nonce 5
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(5, block.timestamp + 1 hours, _chainIds(), 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Now try with same nonce (5), should fail
        Account memory updatedSigner = makeAccount("updatedSigner");
        config.validatorConfig = abi.encodePacked(updatedSigner.addr);
        enableData.nonce = 5; // same nonce - not monotonic
        enableData.allocatorSig = "";
        enableData.userSig = "";

        digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        vm.prank(env.smartAccount1.account);
        vm.expectRevert(IEmissary.InvalidNonce.selector);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Try with lower nonce (3) - also should fail
        enableData.nonce = 3;
        enableData.allocatorSig = "";
        enableData.userSig = "";
        digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        vm.prank(env.smartAccount1.account);
        vm.expectRevert(IEmissary.InvalidNonce.selector);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    /* //////////////////////////////////////////////////////////////
                    CUSTOM VALIDATOR CONFIG
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_CustomValidator_InitialSetup_NoAllocatorSig() public {
        bytes memory customConfig = abi.encodePacked("custom config data");
        IEmissary.EmissaryConfig memory config = _createConfig(IStatelessValidator(address(mockValidator)), 3, customConfig);
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator sig needed for init

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Verify config was stored
        bytes memory stored = env.emissary.getConfig(env.smartAccount1.account, 3, address(mockValidator), env.lockTag);
        assertEq(stored, customConfig);
    }

    function test_setConfig_CustomValidator_Update_RequiresAllocatorSig() public {
        // Initial setup
        test_setConfig_CustomValidator_InitialSetup_NoAllocatorSig();

        // Update with allocator sig
        bytes memory updatedConfig = abi.encodePacked("updated custom config");
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(mockValidator)), 3, updatedConfig);
        IEmissary.EmissaryEnable memory enableData = _createEnableData(2, block.timestamp + 1 hours, _chainIds(), 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        bytes memory stored = env.emissary.getConfig(env.smartAccount1.account, 3, address(mockValidator), env.lockTag);
        assertEq(stored, updatedConfig);
    }

    function test_setConfig_CustomValidator_Update_FailsWithoutAllocatorSig() public {
        // Initial setup
        test_setConfig_CustomValidator_InitialSetup_NoAllocatorSig();

        // Try update without allocator sig
        bytes memory updatedConfig = abi.encodePacked("updated custom config");
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(mockValidator)), 3, updatedConfig);
        IEmissary.EmissaryEnable memory enableData = _createEnableData(2, block.timestamp + 1 hours, _chainIds(), 0);

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator sig!

        vm.prank(env.smartAccount1.account);
        vm.expectRevert();
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    /* //////////////////////////////////////////////////////////////
                    SENDER IS ACCOUNT (SKIP USER SIG)
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_SkipsUserSig_WhenSenderIsAccount() public {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);

        // Don't set userSig - it should be skipped when sender == account

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Verify config was stored
        bytes memory stored = env.emissary.getConfig(env.smartAccount1.account, 1, address(0x1), env.lockTag);
        address signer = abi.decode(stored, (address));
        assertEq(signer, newSigner.addr);
    }

    /* //////////////////////////////////////////////////////////////
                ECDSA CONFIG UPDATE REQUIRES ALLOCATOR SIG
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_ECDSA_Update_RequiresAllocatorSig() public {
        // Initial ECDSA setup
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Update ECDSA config with new signer - requires allocator sig
        Account memory updatedSigner = makeAccount("updatedECDSASigner");
        config.validatorConfig = abi.encodePacked(updatedSigner.addr);
        enableData = _createEnableData(2, block.timestamp + 1 hours, _chainIds(), 0);
        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Verify updated config
        bytes memory stored = env.emissary.getConfig(env.smartAccount1.account, 1, address(0x1), env.lockTag);
        address signer = abi.decode(stored, (address));
        assertEq(signer, updatedSigner.addr);
    }

    function test_setConfig_ECDSA_Update_FailsWithoutAllocatorSig() public {
        // Initial ECDSA setup
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Try update without allocator sig
        Account memory updatedSigner = makeAccount("updatedECDSASigner2");
        config.validatorConfig = abi.encodePacked(updatedSigner.addr);
        enableData = _createEnableData(2, block.timestamp + 1 hours, _chainIds(), 0);
        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator sig!

        vm.prank(env.smartAccount1.account);
        vm.expectRevert();
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    /* //////////////////////////////////////////////////////////////
                        INVALID USER SIG
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_RevertsWhen_InvalidUserSig() public {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);
        // Set an invalid user signature
        enableData.userSig = hex"deadbeef";

        // Call from a different address (not the account) - user sig verification should fail
        vm.prank(address(0xBBBB));
        vm.expectRevert(Emissary.InvalidSignature.selector);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    /* //////////////////////////////////////////////////////////////
                        EVENT EMISSION
    //////////////////////////////////////////////////////////////*/

    function test_setConfig_EmitsEmissaryConfigUpdated() public {
        IEmissary.EmissaryConfig memory config =
            _createConfig(IStatelessValidator(address(0x1)), 1, abi.encodePacked(newSigner.addr));
        IEmissary.EmissaryEnable memory enableData = _createEnableData(1, block.timestamp + 1 hours, _chainIds(), 0);

        vm.expectEmit(true, true, true, true);
        emit Emissary.EmissaryConfigUpdated(env.smartAccount1.account, IStatelessValidator(address(0x1)), env.lockTag);

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }
}
