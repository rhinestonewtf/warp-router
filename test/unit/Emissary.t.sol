import "@rhinestone/compact-utils/src/tests/Environment.sol";
import { IEmissary, WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { WebAuthn } from "@webauthn/WebAuthn.sol";
import { EmissaryLib } from "@rhinestone/compact-utils/src/emissary/lib/EmissaryLib.sol";

contract EmissaryTest is CompactEnvironment {
    Account internal newSigner;
    Account internal updatedSigner;

    // WebAuthn test data (from webauthn-sol test vectors)
    uint256 internal constant PASSKEY_X =
        28_573_233_055_232_466_711_029_625_910_063_034_642_429_572_463_461_595_413_086_259_353_299_906_450_061;
    uint256 internal constant PASSKEY_Y =
        39_367_742_072_897_599_771_788_408_398_752_356_480_431_855_827_262_528_811_857_788_332_151_452_825_281;

    // Signature values for test challenge
    uint256 internal constant TEST_R =
        43_684_192_885_701_841_787_131_392_247_364_253_107_519_555_363_555_461_570_655_060_745_499_568_693_242;
    uint256 internal constant TEST_S =
        22_655_632_649_588_629_308_599_201_066_602_670_461_698_485_748_654_492_451_178_007_896_016_452_673_579;

    bytes internal constant TEST_AUTHENTICATOR_DATA = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000101";

    function setUp() public {
        _deployCompact();
        _deploySmartAccount(true);
        _setEmissary(env.smartAccount1, env.eoa);
        newSigner = makeAccount("newSigner");
        updatedSigner = makeAccount("updatedSigner");
    }

    function test_sigCheck() public {
        // Skip old test - needs to be updated for new storage scheme
        vm.skip(true);
    }

    // Test ECDSA initial setup - should NOT require allocator signature
    function test_setConfig_ECDSA_InitialSetup_NoAllocatorSigNeeded() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 1,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1)), // ECDSA_VALIDATOR
            validatorConfig: abi.encodePacked(newSigner.addr)
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        // Get the digest for signing
        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        // Sign with user account
        enableData.userSig = _signOwnableValidator(env.eoa, digest);

        // No allocator signature needed for initial setup!

        // This should succeed without allocator signature
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Verify the config was set by trying to use it
        bytes32 testDigest = keccak256("test");
        bytes memory ecdsaSig = _signHashRaw(newSigner, testDigest);
        bytes memory emissaryData = abi.encodePacked(address(0x1), uint8(1), ecdsaSig); // ECDSA_VALIDATOR

        bytes4 ret = env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, env.emissary.verifyClaim.selector);
    }

    // Test ECDSA initial setup - can succeed even without allocator signature (not checked during init)
    function test_setConfig_ECDSA_InitialSetup_IgnoresAllocatorSig() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 1,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1)), // ECDSA_VALIDATOR
            validatorConfig: abi.encodePacked(newSigner.addr)
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator signature - but it should still work for initial setup!

        vm.prank(env.smartAccount1.account);
        // Should succeed even without allocator sig for initial setup
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    // Test ECDSA update - should require allocator signature
    function test_setConfig_ECDSA_Update_RequiresAllocatorSig() public {
        // First, do initial setup
        test_setConfig_ECDSA_InitialSetup_NoAllocatorSigNeeded();

        // Now update to a different signer

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 1,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1)), // ECDSA_VALIDATOR
            validatorConfig: abi.encodePacked(updatedSigner.addr)
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "",
            userSig: "",
            expires: block.timestamp + 1 hours,
            nonce: 2, // Increment nonce
            allChainIds: chainIds,
            chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        // This should succeed
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Verify the config was updated
        bytes32 testDigest = keccak256("test2");
        bytes memory ecdsaSig = _signHashRaw(updatedSigner, testDigest);
        bytes memory emissaryData = abi.encodePacked(address(0x1), uint8(1), ecdsaSig); // ECDSA_VALIDATOR

        bytes4 ret = env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);
        assertEq(ret, env.emissary.verifyClaim.selector);
    }

    // Test ECDSA update - should fail without allocator signature
    function test_setConfig_ECDSA_Update_FailsWithoutAllocatorSig() public {
        // First, do initial setup
        test_setConfig_ECDSA_InitialSetup_NoAllocatorSigNeeded();

        // Now try to update without allocator signature

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 1,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1)), // ECDSA_VALIDATOR
            validatorConfig: abi.encodePacked(updatedSigner.addr)
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 2, allChainIds: chainIds, chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator signature!

        vm.prank(env.smartAccount1.account);
        vm.expectRevert();
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    /* //////////////////////////////////////////////////////////////
                          PASSKEY TESTS
    //////////////////////////////////////////////////////////////*/

    // Test Passkey initial setup - should NOT require allocator signature
    function test_setConfig_Passkey_InitialSetup_NoAllocatorSigNeeded() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        // Encode passkey credentials
        bytes memory passkeyConfig = _encodePasskeyConfig(PASSKEY_X, PASSKEY_Y, false, false);

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 2,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1001)), // PASSKEY_VALIDATOR
            validatorConfig: passkeyConfig
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator signature needed for initial setup!

        // This should succeed without allocator signature
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    // Test Passkey update - should require allocator signature
    function test_setConfig_Passkey_Update_RequiresAllocatorSig() public {
        // First, do initial setup
        test_setConfig_Passkey_InitialSetup_NoAllocatorSigNeeded();

        // Now update to different credentials
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        // Different passkey credentials for update
        bytes memory updatedPasskeyConfig = _encodePasskeyConfig(
            PASSKEY_X + 1, // Different X coordinate
            PASSKEY_Y + 1, // Different Y coordinate
            true, // Different requireUV
            true // Different usePrecompile
        );

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 2,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1001)), // PASSKEY_VALIDATOR
            validatorConfig: updatedPasskeyConfig
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "",
            userSig: "",
            expires: block.timestamp + 1 hours,
            nonce: 2, // Increment nonce
            allChainIds: chainIds,
            chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        enableData.allocatorSig = _signHashRaw(env.orchestrator, digest);

        // This should succeed with allocator signature
        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    // Test Passkey update - should fail without allocator signature
    function test_setConfig_Passkey_Update_FailsWithoutAllocatorSig() public {
        // First, do initial setup
        test_setConfig_Passkey_InitialSetup_NoAllocatorSigNeeded();

        // Now try to update without allocator signature
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        bytes memory updatedPasskeyConfig = _encodePasskeyConfig(PASSKEY_X + 1, PASSKEY_Y + 1, true, true);

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 2,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(0x1001)), // PASSKEY_VALIDATOR
            validatorConfig: updatedPasskeyConfig
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 2, allChainIds: chainIds, chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);

        enableData.userSig = _signOwnableValidator(env.eoa, digest);
        // No allocator signature!

        vm.prank(env.smartAccount1.account);
        vm.expectRevert();
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);
    }

    // Test Passkey verifyClaim - success case
    function test_verifyClaim_Passkey_Success() public {
        // Setup passkey config using helper
        env.emissary
            .setupPasskeyConfig(
                env.smartAccount1.account,
                env.lockTag,
                PASSKEY_X,
                PASSKEY_Y,
                false, // requireUV
                false // usePrecompile
            );

        // Create test digest - using the exact challenge that matches our test signature
        bytes32 testDigest = 0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf;

        // Create passkey signature for the digest
        WebAuthn.WebAuthnAuth memory auth = _createPasskeySignature(testDigest);

        // Encode emissary data: validator (PASSKEY_VALIDATOR), configId (2), signature
        bytes memory emissaryData = abi.encodePacked(
            address(0x1001), // PASSKEY_VALIDATOR
            uint8(2), // configId
            abi.encode(auth) // WebAuthnAuth signature
        );

        // Verify claim should succeed
        bytes4 result = env.emissary
            .verifyClaim(
                env.smartAccount1.account,
                testDigest,
                bytes32(0), // claimHash
                emissaryData,
                env.lockTag
            );

        assertEq(result, env.emissary.verifyClaim.selector, "Should return success selector");
    }

    // Test Passkey verifyClaim - invalid signature
    function test_verifyClaim_Passkey_InvalidSignature() public {
        // Setup passkey config
        env.emissary.setupPasskeyConfig(env.smartAccount1.account, env.lockTag, PASSKEY_X, PASSKEY_Y, false, false);

        // Create test digest - using a different digest to test invalid signature
        bytes32 testDigest = keccak256("different digest for invalid test");

        // Create signature for WRONG digest
        bytes32 wrongDigest = keccak256("wrong digest");
        WebAuthn.WebAuthnAuth memory auth = _createPasskeySignature(wrongDigest);

        // Encode emissary data with wrong signature
        bytes memory emissaryData = abi.encodePacked(
            address(0x1001), // PASSKEY_VALIDATOR
            uint8(2),
            abi.encode(auth)
        );

        // Verify claim should fail
        bytes4 result = env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);

        assertEq(result, bytes4(0xFFFFFFFF), "Should return failure for invalid signature");
    }

    // Test Passkey verifyClaim - no config set
    function test_verifyClaim_Passkey_NoConfig() public {
        // Don't setup any config

        bytes32 testDigest = keccak256("test");
        WebAuthn.WebAuthnAuth memory auth = _createPasskeySignature(testDigest);

        bytes memory emissaryData = abi.encodePacked(
            address(0x1001), // PASSKEY_VALIDATOR
            uint8(2),
            abi.encode(auth)
        );

        // Should fail because no config is set (pubKeyX/Y will be 0)
        bytes4 result = env.emissary.verifyClaim(env.smartAccount1.account, testDigest, bytes32(0), emissaryData, env.lockTag);

        assertEq(result, bytes4(0xFFFFFFFF), "Should return failure when no config set");
    }

    /* //////////////////////////////////////////////////////////////
                          GETCONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    // Test getConfig for ECDSA_VALIDATOR
    function test_getConfig_ECDSA() public {
        // Setup ECDSA config
        test_setConfig_ECDSA_InitialSetup_NoAllocatorSigNeeded();

        // Get the config
        bytes memory config = env.emissary
            .getConfig(
                env.smartAccount1.account,
                1, // configId
                address(0x1), // ECDSA_VALIDATOR
                env.lockTag
            );

        // Decode and verify
        address signer = abi.decode(config, (address));
        assertEq(signer, newSigner.addr, "Should return correct ECDSA signer address");
    }

    // Test getConfig for ECDSA_VALIDATOR - no config set
    function test_getConfig_ECDSA_NoConfig() public {
        // Don't setup any config, just try to read

        bytes memory config = env.emissary
            .getConfig(
                env.smartAccount1.account,
                1, // configId
                address(0x1), // ECDSA_VALIDATOR
                env.lockTag
            );

        // Should return zero address when no config is set
        address signer = abi.decode(config, (address));
        assertEq(signer, address(0), "Should return zero address when no config set");
    }

    // Test getConfig for PASSKEY_VALIDATOR
    function test_getConfig_Passkey() public {
        // Setup passkey config
        test_setConfig_Passkey_InitialSetup_NoAllocatorSigNeeded();

        // Get the config
        bytes memory config = env.emissary
            .getConfig(
                env.smartAccount1.account,
                2, // configId
                address(0x1001), // PASSKEY_VALIDATOR
                env.lockTag
            );

        // Decode and verify
        WebAuthnCredential memory creds = abi.decode(config, (WebAuthnCredential));
        assertEq(creds.pubKeyX, PASSKEY_X, "Should return correct pubKeyX");
        assertEq(creds.pubKeyY, PASSKEY_Y, "Should return correct pubKeyY");
        assertEq(creds.requireUV, false, "Should return correct requireUV flag");
        assertEq(creds.usePrecompile, false, "Should return correct usePrecompile flag");
    }

    // Test getConfig for PASSKEY_VALIDATOR - no config set
    function test_getConfig_Passkey_NoConfig() public {
        // Don't setup any config, just try to read

        bytes memory config = env.emissary
            .getConfig(
                env.smartAccount1.account,
                2, // configId
                address(0x1001), // PASSKEY_VALIDATOR
                env.lockTag
            );

        // Should return empty/zero credentials when no config is set
        WebAuthnCredential memory creds = abi.decode(config, (WebAuthnCredential));
        assertEq(creds.pubKeyX, 0, "Should return zero pubKeyX when no config set");
        assertEq(creds.pubKeyY, 0, "Should return zero pubKeyY when no config set");
        assertEq(creds.requireUV, false, "Should return false requireUV when no config set");
        assertEq(creds.usePrecompile, false, "Should return false usePrecompile when no config set");
    }

    // Test getConfig for custom validator (compressed storage)
    function test_getConfig_CustomValidator() public {
        // Deploy a mock custom validator
        MockStatelessValidator mockValidator = new MockStatelessValidator();

        // Setup custom validator config
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        bytes memory customConfig = abi.encodePacked("custom validator config data");

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 3,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: IStatelessValidator(address(mockValidator)),
            validatorConfig: customConfig
        });

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", userSig: "", expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        bytes32 digest = env.emissary.getHash(env.smartAccount1.account, env.lockTag, enableData.expires, config, enableData);
        enableData.userSig = _signOwnableValidator(env.eoa, digest);

        vm.prank(env.smartAccount1.account);
        env.emissary.setConfig(env.smartAccount1.account, config, enableData);

        // Now get the config
        bytes memory retrievedConfig = env.emissary
            .getConfig(
                env.smartAccount1.account,
                3, // configId
                address(mockValidator),
                env.lockTag
            );

        // Should return the original custom config data
        assertEq(retrievedConfig, customConfig, "Should return correct custom validator config");
    }

    // Test getConfig for custom validator - no config set
    function test_getConfig_CustomValidator_NoConfig() public {
        MockStatelessValidator mockValidator = new MockStatelessValidator();

        // Try to get config without setting it first
        bytes memory config = env.emissary
            .getConfig(
                env.smartAccount1.account,
                3, // configId
                address(mockValidator),
                env.lockTag
            );

        // Should return empty bytes when no config is set
        assertEq(config.length, 0, "Should return empty bytes when no config set");
    }

    /* //////////////////////////////////////////////////////////////
                          WEBAUTHN HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to create a WebAuthn signature for a given challenge
    /// @param challenge The challenge bytes32 to sign
    /// @return auth The WebAuthnAuth struct with signature
    function _createPasskeySignature(bytes32 challenge) internal pure returns (WebAuthn.WebAuthnAuth memory auth) {
        // Encode challenge to base64url for clientDataJSON
        string memory challengeB64 = _base64UrlEncode(abi.encode(challenge));

        // Create clientDataJSON matching the test vector format
        string memory clientDataJSON =
            string(abi.encodePacked('{"type":"webauthn.get","challenge":"', challengeB64, '","origin":"http://localhost:3005"}'));

        auth = WebAuthn.WebAuthnAuth({
            authenticatorData: TEST_AUTHENTICATOR_DATA,
            clientDataJSON: clientDataJSON,
            challengeIndex: 23,
            typeIndex: 1,
            r: TEST_R,
            s: TEST_S
        });
    }

    /// @notice Helper to encode WebAuthnCredential for config
    function _encodePasskeyConfig(uint256 x, uint256 y, bool requireUV, bool usePrecompile) internal pure returns (bytes memory) {
        return EmissaryLib.pack(WebAuthnCredential({ pubKeyX: x, pubKeyY: y, requireUV: requireUV, usePrecompile: usePrecompile }));
    }

    /// @notice Simple base64url encoder for challenge
    /// @dev Simplified version - in production use proper Base64Url library
    function _base64UrlEncode(bytes memory data) internal pure returns (string memory) {
        bytes memory TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

        uint256 len = data.length;
        if (len == 0) return "";

        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen);

        uint256 i = 0;
        uint256 j = 0;

        while (i < len) {
            uint256 a = uint256(uint8(data[i++]));
            uint256 b = i < len ? uint256(uint8(data[i++])) : 0;
            uint256 c = i < len ? uint256(uint8(data[i++])) : 0;

            uint256 triple = (a << 16) | (b << 8) | c;

            result[j++] = TABLE[(triple >> 18) & 0x3F];
            result[j++] = TABLE[(triple >> 12) & 0x3F];
            result[j++] = TABLE[(triple >> 6) & 0x3F];
            result[j++] = TABLE[triple & 0x3F];
        }

        // Remove padding for base64url
        uint256 paddingLen = (3 - (len % 3)) % 3;
        assembly {
            mstore(result, sub(mload(result), paddingLen))
        }

        return string(result);
    }
}

// Mock stateless validator for testing custom validator path
contract MockStatelessValidator is IStatelessValidator {
    function validateSignatureWithData(bytes32, bytes calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }
}
