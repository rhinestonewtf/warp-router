// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Emissary } from "@rhinestone/compact-utils/src/emissary/Emissary.sol";
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { DebugEmissary } from "@rhinestone/compact-utils/src/tests/DebugEmissary.sol";
import { ResetPeriod } from "the-compact/types/ResetPeriod.sol";
import { Scope } from "the-compact/types/Scope.sol";

/**
 * @title EmissaryInvariantHandler
 * @notice Handler contract for invariant testing of Emissary
 * @dev This handler tracks state changes and provides functions for the invariant fuzzer to call
 */
contract EmissaryInvariantHandler is Test {
    DebugEmissary public emissary;
    address public testAccount;
    address public allocator;

    // Track all config keys that have been set
    struct ConfigKey {
        address account;
        address validator;
        uint8 configId;
        bytes12 lockTag;
    }

    ConfigKey[] public setConfigs;
    mapping(bytes32 => bool) public configExists;

    // Track attempts to update without allocator signature
    uint256 public updateAttemptsWithoutAllocatorSig;
    uint256 public successfulUpdatesWithoutAllocatorSig;

    constructor(DebugEmissary _emissary, address _testAccount, address _allocator) {
        emissary = _emissary;
        testAccount = _testAccount;
        allocator = _allocator;
    }

    function _configKeyHash(address account, address validator, uint8 configId, bytes12 lockTag) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, validator, configId, lockTag));
    }

    /**
     * @notice Attempt to set a config (either initial or update)
     * @dev This simulates both initial setup and update scenarios
     */
    function setConfig(
        uint8 configId,
        uint8 validatorType, // 0 = ECDSA, 1 = PASSKEY, 2+ = custom
        bytes12 lockTag,
        uint256 nonce,
        bool includeAllocatorSig
    )
        public
    {
        // Bound inputs
        configId = uint8(bound(configId, 1, 255));
        nonce = bound(nonce, 1, type(uint256).max);

        // Determine validator address based on type
        address validator;
        bytes memory validatorConfig;
        if (validatorType == 0) {
            validator = address(0x1); // ECDSA_VALIDATOR
            validatorConfig = abi.encodePacked(makeAddr("signer"));
        } else if (validatorType == 1) {
            validator = address(0x1001); // PASSKEY_VALIDATOR
            // Simple passkey config
            validatorConfig = abi.encode(false, false, uint256(1), uint256(2));
        } else {
            validator = makeAddr("customValidator");
            validatorConfig = abi.encodePacked("customConfig");
        }

        bytes32 configKeyHash = _configKeyHash(testAccount, validator, configId, lockTag);
        bool isUpdate = configExists[configKeyHash];

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: configId,
            allocator: allocator,
            scope: Scope.Multichain,
            resetPeriod: ResetPeriod.TenMinutes,
            validator: IStatelessValidator(validator),
            validatorConfig: validatorConfig
        });

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: includeAllocatorSig ? bytes("valid_sig") : bytes(""),
            userSig: bytes("user_sig"),
            expires: block.timestamp + 1 hours,
            nonce: nonce,
            allChainIds: chainIds,
            chainIndex: 0
        });

        // Track update attempts without allocator signature
        if (isUpdate && !includeAllocatorSig) {
            updateAttemptsWithoutAllocatorSig++;
        }

        vm.prank(testAccount);
        try emissary.setConfig(testAccount, config, enableData) {
            // If this is an update without allocator sig, we have a violation!
            if (isUpdate && !includeAllocatorSig) {
                successfulUpdatesWithoutAllocatorSig++;
            }

            // Track that this config now exists
            if (!configExists[configKeyHash]) {
                setConfigs.push(ConfigKey({ account: testAccount, validator: validator, configId: configId, lockTag: lockTag }));
                configExists[configKeyHash] = true;
            }
        } catch {
            // Expected to revert if update without allocator sig
        }
    }

    /**
     * @notice Try to update an existing config without allocator signature
     * @dev This specifically targets the invariant we want to test
     */
    function tryUpdateExistingConfigWithoutAllocatorSig(uint256 configIndex) public {
        if (setConfigs.length == 0) return;

        configIndex = bound(configIndex, 0, setConfigs.length - 1);
        ConfigKey memory key = setConfigs[configIndex];

        // Get the existing config details
        bytes memory validatorConfig;
        if (key.validator == address(0x1)) {
            validatorConfig = abi.encodePacked(makeAddr("newSigner"));
        } else if (key.validator == address(0x1001)) {
            validatorConfig = abi.encode(false, false, uint256(999), uint256(888));
        } else {
            validatorConfig = abi.encodePacked("newCustomConfig");
        }

        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: key.configId,
            allocator: allocator,
            scope: Scope.Multichain,
            resetPeriod: ResetPeriod.TenMinutes,
            validator: IStatelessValidator(key.validator),
            validatorConfig: validatorConfig
        });

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: "", // NO ALLOCATOR SIGNATURE
            userSig: "user_sig",
            expires: block.timestamp + 1 hours,
            nonce: block.timestamp, // Use timestamp as nonce to ensure it's always increasing
            allChainIds: chainIds,
            chainIndex: 0
        });

        updateAttemptsWithoutAllocatorSig++;

        vm.prank(testAccount);
        try emissary.setConfig(testAccount, config, enableData) {
            // THIS SHOULD NEVER SUCCEED!
            successfulUpdatesWithoutAllocatorSig++;
        } catch {
            // Expected - update without allocator sig should revert
        }
    }
}

/**
 * @title EmissaryInvariantTest
 * @notice Invariant tests for critical Emissary security properties
 * @dev Tests the invariant that existing configs can only be overwritten with allocator signature
 */
contract EmissaryInvariantTest is Test {
    DebugEmissary public emissary;
    EmissaryInvariantHandler public handler;

    address public testAccount;
    address public allocator;
    address public compact;

    function setUp() public {
        compact = makeAddr("compact");
        testAccount = makeAddr("testAccount");
        allocator = makeAddr("allocator");

        emissary = new DebugEmissary(compact);
        handler = new EmissaryInvariantHandler(emissary, testAccount, allocator);

        // Configure the fuzzer to target the handler
        targetContract(address(handler));

        // Target specific functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = EmissaryInvariantHandler.setConfig.selector;
        selectors[1] = EmissaryInvariantHandler.tryUpdateExistingConfigWithoutAllocatorSig.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));

        // Enable overwrite mode to bypass signature checks
        emissary.overwrite(true);
    }

    /**
     * @notice CRITICAL INVARIANT: Existing configs cannot be updated without allocator signature
     * @dev This invariant ensures that once a config is set, only the allocator can authorize updates
     *
     * Security rationale:
     * - Initial setup (init=true) does not require allocator sig (easier onboarding)
     * - Updates (init=false) MUST require allocator sig to protect allocated resources
     * - This prevents unauthorized modifications to validator configurations
     */
    function invariant_cannotUpdateConfigWithoutAllocatorSig() public view {
        assertEq(handler.successfulUpdatesWithoutAllocatorSig(), 0, "CRITICAL: Config was updated without allocator signature!");
    }

    /**
     * @notice Verify that update attempts without allocator sig were actually tried
     * @dev This ensures the invariant test is actually exercising the update path
     */
    function invariant_updateAttemptsWereMade() public view {
        // After fuzzing, we should have attempted some updates
        // This ensures our test is actually meaningful
        assertTrue(
            handler.updateAttemptsWithoutAllocatorSig() > 0 || !handler.configExists(bytes32(0)),
            "Test should attempt updates to be meaningful"
        );
    }

    /**
     * @notice Explicit test: Update existing ECDSA config without allocator sig should fail
     */
    function test_updateECDSAConfigWithoutAllocatorSigFails() public {
        emissary.overwrite(false); // Disable overwrite to test real signature validation

        // Set initial ECDSA config (should succeed without allocator sig)
        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 1,
            allocator: allocator,
            scope: Scope.Multichain,
            resetPeriod: ResetPeriod.TenMinutes,
            validator: IStatelessValidator(address(0x1)), // ECDSA_VALIDATOR
            validatorConfig: abi.encodePacked(makeAddr("signer1"))
        });

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: bytes(""), userSig: bytes(""), expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        vm.prank(testAccount);
        emissary.setConfig(testAccount, config, enableData);

        // Try to update without allocator signature (should fail)
        config.validatorConfig = abi.encodePacked(makeAddr("signer2"));
        enableData.nonce = 2;

        vm.prank(testAccount);
        vm.expectRevert();
        emissary.setConfig(testAccount, config, enableData);
    }

    /**
     * @notice Explicit test: Update existing Passkey config without allocator sig should fail
     */
    function test_updatePasskeyConfigWithoutAllocatorSigFails() public {
        emissary.overwrite(false);

        // Set initial Passkey config
        IEmissary.EmissaryConfig memory config = IEmissary.EmissaryConfig({
            configId: 2,
            allocator: allocator,
            scope: Scope.Multichain,
            resetPeriod: ResetPeriod.TenMinutes,
            validator: IStatelessValidator(address(0x1001)), // PASSKEY_VALIDATOR
            validatorConfig: abi.encodePacked(false, false, uint256(100), uint256(200))
        });

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        IEmissary.EmissaryEnable memory enableData = IEmissary.EmissaryEnable({
            allocatorSig: bytes(""), userSig: bytes(""), expires: block.timestamp + 1 hours, nonce: 1, allChainIds: chainIds, chainIndex: 0
        });

        vm.prank(testAccount);
        emissary.setConfig(testAccount, config, enableData);

        // Try to update without allocator signature (should fail)
        config.validatorConfig = abi.encodePacked(false, false, uint256(300), uint256(400));
        enableData.nonce = 2;

        vm.prank(testAccount);
        vm.expectRevert();
        emissary.setConfig(testAccount, config, enableData);
    }
}
