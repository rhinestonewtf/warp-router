// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { EIP712Hash } from "./lib/EmissaryEIP712Lib.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { IEmissary, WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";

import { IdLib } from "the-compact/lib/IdLib.sol";
import { EmissaryStorageLib } from "./lib/EmissaryStorageLib.sol";
import { EfficiencyLib } from "the-compact/lib/EfficiencyLib.sol";
import { Compressed } from "./lib/CompressedStorageLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { WebAuthn } from "@webauthn/WebAuthn.sol";
import { EmissaryLib } from "./lib/EmissaryLib.sol";

/**
 * @title Emissary Contract
 * @notice Manages configurations for stateless validators associated with sponsor accounts and lock tags
 * @dev This contract acts as a central point for managing validator configurations across different chains.
 * It supports three types of validation modes determined by the validator address:
 * - ECDSA_VALIDATOR (0x1): Built-in ECDSA signature validation with a configured signer address
 * - PASSKEY_VALIDATOR (0x1001): Built-in WebAuthn P256 signature validation with stored credentials
 * - Custom validators (other addresses): External stateless validators with compressed storage
 *
 * Multiple configurations can exist for the same validator address by using different configIds.
 * For example, you can have multiple ECDSA signers under configId 1, 2, 3, etc., all using ECDSA_VALIDATOR.
 *
 * The contract uses a nonce mechanism per sponsor and lock tag to prevent replay attacks on configuration
 * updates. The lock tag is derived from the allocator ID, scope, and reset period.
 *
 * Configuration updates require two signatures:
 * - User signature: Always required unless msg.sender is the account itself
 * - Allocator signature: Only required when updating existing config (init=false), skipped on first setup
 *
 * @custom:security All configuration updates are protected by EIP-712 signatures and nonce-based replay protection
 */
contract Emissary is IEmissary, EIP712 {
    using EmissaryStorageLib for address;
    using EmissaryStorageLib for bytes32;
    using SignatureCheckerLib for address;
    using IdLib for address;
    using IdLib for uint96;
    using IdLib for bytes12;
    using EfficiencyLib for uint256;
    using Compressed for Compressed.Bytes;
    using EmissaryLib for bytes;

    error InvalidSignature();

    /**
     * @dev Validator address for ECDSA signature validation mode
     * When config.validator == ECDSA_VALIDATOR, uses built-in ECDSA signature verification
     * Multiple ECDSA signers can be configured using different configIds
     */
    address internal constant ECDSA_VALIDATOR = address(0x1);

    /**
     * @dev Validator address for WebAuthn passkey validation mode
     * When config.validator == PASSKEY_VALIDATOR, uses built-in P256 WebAuthn verification
     * Multiple passkeys can be configured using different configIds
     */
    address internal constant PASSKEY_VALIDATOR = address(0x1001);

    /**
     * @dev Signature indicating invalid signature verification
     * Returned when signature validation fails in verifyClaim
     */
    bytes4 internal constant INVALID_SIGNATURE = bytes4(0xFFFFFFFF);

    /**
     * @notice Emitted when a new validator configuration is successfully set for an account and
     * lock tag.
     * @param account The sponsor account whose configuration was updated.
     * @param validator The stateless validator address associated with the configuration.
     * @param lockTag The lock tag derived from the allocator, scope, and reset period.
     */
    event EmissaryConfigUpdated(address indexed account, IStatelessValidator indexed validator, bytes12 indexed lockTag);

    /**
     * @notice Sets or updates the configuration for a specific validator, config ID, and lock tag
     * associated with a sponsor account
     * @dev This function handles three distinct configuration types with different storage patterns:
     *
     * TYPE_ECDSA (1): Stores a single address (20 bytes) as the authorized signer
     * - validatorConfig contains the signer address in the first 20 bytes
     * - Signature verification uses ECDSA.recoverCalldata to extract and compare signer
     * - Storage: Direct address storage at computed slot
     *
     * TYPE_PASSKEY (2): Stores WebAuthn credentials (P256 public key + flags)
     * - validatorConfig is ABI-encoded WebAuthnCredential struct
     * - Stores pubKeyX, pubKeyY (uint256 each), requireUV and usePrecompile (bool flags)
     * - Signature verification uses WebAuthn.verify with challenge-response protocol
     *
     * Custom validators (3+): Stores arbitrary configuration using compressed storage
     * - validatorConfig is validator-specific bytes that get compressed
     * - Delegates signature verification to IStatelessValidator.validateSignatureWithData
     * - Storage: Uses CompressedStorageLib for efficient storage
     *
     * The init flag determines whether allocator signature is required:
     * - init=true: First time setup, no existing config, allocator signature is skipped
     * - init=false: Updating existing config, allocator must authorize the change
     *
     * @param account The sponsor account for which the configuration is being set
     * @param config The EmissaryConfig struct containing validator, configId, scope, resetPeriod,
     * allocator, and validatorConfig
     * @param enableData The EmissaryEnable struct containing signatures, nonce, expiry, chain IDs,
     * and the current chain index
     * @custom:security Requires monotonically increasing nonce to prevent replay attacks
     * @custom:security User signature always required unless msg.sender is the account itself
     * @custom:security Allocator signature only required on updates (not initial setup)
     */
    function setConfig(address account, EmissaryConfig calldata config, EmissaryEnable calldata enableData) external {
        // Derive the lock tag from allocator ID, scope, and reset period
        // This creates a unique identifier for the resource lock being configured
        bytes12 lockTag = config.allocator.toAllocatorId().toLockTag(config.scope, config.resetPeriod);

        // Handle nonces for replay protection
        // Each sponsor+lockTag pair has its own nonce counter
        bytes32 nonceSlot = account.nonceSlot(lockTag);
        uint256 currentNonce = nonceSlot.loadUint256();
        require(enableData.nonce > currentNonce, InvalidNonce()); // Ensure nonce increases monotonically
        nonceSlot.setUint256(enableData.nonce); // Store new nonce to prevent replay

        // Verify chain ID and expiry constraints
        // The signature must explicitly include the current chain ID to prevent cross-chain replay
        require(enableData.allChainIds[enableData.chainIndex] == block.chainid, InvalidSignature());
        // Ensure the enable message hasn't expired based on block timestamp
        require(enableData.expires > block.timestamp, InvalidSignature());
        uint8 configId = config.configId;

        // Calculate the EIP-712 hash for the configuration data
        // This creates a typed structured data hash following EIP-712 specification:
        // SetConfig(address sponsor,address validator,uint8 configId,bytes12 lockTag,
        // uint256 expires,bytes config,uint256 nonce,uint256[] chainIds)
        bytes32 hash = EIP712Hash.config({
            sponsor: account,
            validator: config.validator,
            configId: configId,
            lockTag: lockTag,
            expires: enableData.expires,
            nonce: enableData.nonce,
            validatorConfig: config.validatorConfig,
            chainIds: enableData.allChainIds
        });
        // Create the final digest by wrapping with domain separator
        // Uses _hashTypedDataSansChainId since chainId is already validated above
        bytes32 digest = _hashTypedDataSansChainId(hash);

        // Determine if this is initial setup (init=true) or an update (init=false)
        // and store the configuration data according to the validator address
        // The validator address determines the validation mode:
        // - ECDSA_VALIDATOR (0x1): Built-in ECDSA validation
        // - PASSKEY_VALIDATOR (0x1001): Built-in WebAuthn P256 validation
        // - Other addresses: Custom external validator
        bool init;
        if (address(config.validator) == ECDSA_VALIDATOR) {
            // ECDSA mode: Store a single signer address for ECDSA signature verification
            // Storage layout: sponsor -> configId -> lockTag -> ECDSA_VALIDATOR -> signer address
            // Multiple signers can be configured under different configIds
            bytes32 slot = account.configSlot(configId, lockTag, ECDSA_VALIDATOR);
            address currentSigner = slot.loadAddressUnchecked();
            init = (currentSigner == address(0)); // Check if this is the first time setting this config

            // Extract signer address from the first 20 bytes of validatorConfig
            address signer = address(bytes20(config.validatorConfig));
            slot.storeAddress(signer);
        } else if (address(config.validator) == PASSKEY_VALIDATOR) {
            // Passkey mode: Store WebAuthn credentials including P256 public key and validation flags
            // The credentials include requireUV (user verification) and usePrecompile (RIP-7212) flags
            // Multiple passkeys can be configured under different configIds
            bytes32 slot = account.configSlot(configId, lockTag, PASSKEY_VALIDATOR);
            WebAuthnCredential storage creds = slot.loadPasskeyCredentials();
            init = (creds.pubKeyX == 0 && creds.pubKeyY == 0); // Check if credentials are uninitialized

            // Store WebAuthn credentials to storage
            // These will be used during signature verification to validate the challenge-response
            (creds.requireUV, creds.usePrecompile, creds.pubKeyX, creds.pubKeyY) =
                EmissaryLib.unpackWebAuthnCredential(config.validatorConfig);
        } else {
            // Custom validator mode: Store arbitrary configuration data using compressed storage
            // This allows validators to define their own configuration format
            // The validator address is an external contract implementing IStatelessValidator
            bytes32 slot = account.configSlot(configId, lockTag, address(config.validator));
            Compressed.Bytes storage $config = slot.loadCompressedBytes();
            init = $config.sload().length == 0; // Check if this is the first time setting this config

            // Store the validator configuration data with compression for gas efficiency
            $config.sstore(config.validatorConfig);
        }

        // Verify signatures based on caller and initialization state
        // Two-signature model provides security through separation of concerns:
        // 1. User signature proves the account holder authorizes this config
        // 2. Allocator signature proves the resource allocator authorizes updates (not needed on init)

        // User signature verification (always required unless caller is the account)
        // If msg.sender is the account itself, we can skip signature verification as the caller
        // has already proven ownership by making the transaction
        if (account != msg.sender) {
            // Verify using ERC-1271 standard signature validation
            // This works for both EOAs (via ecrecover) and smart contract wallets
            require(account.isValidSignatureNowCalldata(digest, enableData.userSig), InvalidSignature());
        }

        // Allocator signature verification (only required when updating existing config)
        // When init=true (first time setup), we skip allocator signature to allow easier onboarding
        // The rationale: initial setup creates the config, so allocator hasn't committed resources yet
        // When init=false (updating), allocator must approve changes to protect their allocated resources
        if (!init) {
            // Check allocator signature using ERC-1271 standard
            // Allocator is typically a smart contract managing resource allocation
            require(config.allocator.isValidERC1271SignatureNowCalldata(digest, enableData.allocatorSig), InvalidSignature());
        }

        emit EmissaryConfigUpdated(account, config.validator, lockTag);
    }

    /**
     * @notice Verifies a claim hash using the configured stateless validator for a given sponsor
     * and lock tag.
     * @dev Extracts the validator address and config ID from the start of `emissaryData`.
     *      Retrieves the corresponding configuration data.
     *      Calls the `validateSignatureWithData` function on the specified validator.
     * @param sponsor The sponsor account associated with the claim.
     * @param digest The hash of the claim being verified.
     * @param emissaryData Data containing the validator address (first 20 bytes), config ID (next
     * byte),
     *                     and the validator-specific signature data (remaining bytes).
     * @param lockTag The lock tag associated with the configuration to use for verification.
     * @return The selector `this.verifyClaim.selector` if the signature is valid according to the
     * validator,
     *         otherwise returns `bytes4(0xFFFFFFFF)`.
     */
    function verifyClaim(
        address sponsor,
        bytes32 digest,
        bytes32, /* claimHash*/
        bytes calldata emissaryData,
        bytes12 lockTag
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return _validateSignature(sponsor, digest, emissaryData, lockTag) ? this.verifyClaim.selector : INVALID_SIGNATURE;
    }

    /**
     * @notice Internal function that performs the actual signature validation logic
     * @dev This function handles three distinct validation paths based on validator address:
     *
     * ECDSA_VALIDATOR (0x1): Built-in ECDSA signature verification
     * - Recovers signer from signature using ECDSA.recoverCalldata
     * - Compares recovered signer with stored signer address for the given configId
     * - Returns true if they match
     *
     * PASSKEY_VALIDATOR (0x1001): Built-in WebAuthn passkey verification
     * - Decodes WebAuthnAuth struct from emissaryData
     * - Loads stored credentials (pubKeyX, pubKeyY, requireUV, usePrecompile) for the given configId
     * - Uses WebAuthn.verify with challenge-response protocol
     * - Returns true if P256 signature verification succeeds
     *
     * Other addresses: External stateless validator
     * - Uses the validator address specified in emissaryData
     * - Loads compressed configuration data from storage for the given configId
     * - Delegates to IStatelessValidator.validateSignatureWithData
     * - Returns result from external validator
     *
     * Storage slot derivation:
     * - Slot = keccak256(sponsor, configId, lockTag, validator)
     * - This ensures each sponsor+configId+lockTag+validator combination has unique storage
     * - Multiple configs can exist for the same validator under different configIds
     *
     * @param sponsor The sponsor account whose signature is being validated
     * @param digest The EIP-712 digest being signed
     * @param emissaryData Packed data: [validator(20)][configId(1)][signatureData(var)]
     * @param lockTag The lock tag derived from allocator, scope, and reset period
     * @return bool True if signature is valid, false otherwise
     */
    function _validateSignature(
        address sponsor,
        bytes32 digest,
        bytes calldata emissaryData,
        bytes12 lockTag
    )
        internal
        view
        virtual
        returns (bool)
    {
        // Unpack emissary data into validator address, config ID, and signature data
        (address validator, uint8 configId, bytes calldata signatureData) = EmissaryLib.unpack(emissaryData);

        if (validator == ECDSA_VALIDATOR) {
            // Built-in ECDSA validation path
            // Load the authorized signer address from storage for this configId
            address signer = sponsor.configSlot(configId, lockTag, ECDSA_VALIDATOR).loadAddress();
            // Recover signer from signature and compare with stored signer
            return (ECDSA.recoverCalldata(digest, signatureData) == signer);
        } else if (validator == PASSKEY_VALIDATOR) {
            // Built-in WebAuthn passkey validation path
            // Decode the WebAuthn authentication data (authenticatorData, clientDataJSON, etc.)
            WebAuthn.WebAuthnAuth memory passkeyAuth = abi.decode(signatureData, (WebAuthn.WebAuthnAuth));
            // Load stored P256 public key credentials and validation flags for this configId
            WebAuthnCredential memory creds = sponsor.configSlot(configId, lockTag, PASSKEY_VALIDATOR).loadPasskeyCredentials();
            // Verify the WebAuthn signature using P256 curve verification
            // The challenge is the digest, which will be validated against clientDataJSON
            return WebAuthn.verify({
                challenge: abi.encode(digest),
                requireUV: creds.requireUV,
                webAuthnAuth: passkeyAuth,
                x: creds.pubKeyX,
                y: creds.pubKeyY,
                usePrecompile: creds.usePrecompile
            });
        } else {
            // Custom stateless validator path
            // Load the compressed configuration data for this validator and configId
            Compressed.Bytes storage $config = sponsor.configSlot(configId, lockTag, validator).loadCompressedBytes();
            bytes memory configData = $config.sload();
            // If no config is set, validation fails - prevents using unconfigured validators
            if (configData.length == 0) return false;
            // Delegate signature validation to the external stateless validator
            // The validator interprets both the signature data and config data according to its own logic
            return IStatelessValidator(validator).validateSignatureWithData(digest, signatureData, configData);
        }
    }

    /**
     * @notice Returns the EIP-712 domain name and version for this contract
     * @dev Used in the EIP-712 signature hashing process to construct the domain separator.
     * The domain separator ensures signatures are unique to this contract and chain.
     *
     * EIP-712 signing flow:
     * 1. Create typed struct hash: hashStruct(SetConfig(...))
     * 2. Get domain separator: DOMAIN_SEPARATOR()
     * 3. Combine: keccak256("\x19\x01" || domainSeparator || hashStruct)
     * 4. Sign the final digest with user's private key
     *
     * @return name The domain name ("Emissary")
     * @return version The domain version ("0.0.1")
     */
    function _domainNameAndVersion() internal view virtual override returns (string memory name, string memory version) {
        name = "Emissary";
        version = "0.0.1";
    }

    /**
     * @notice Returns the EIP-712 domain separator for this contract instance
     *
     * This ensures signatures are unique to:
     * - This specific contract deployment (address)
     * - The contract name and version
     *
     * @return The EIP-712 domain separator for signature validation
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _domainSeparator();
    }

    /**
     * @notice Retrieves the stored validator configuration for a specific account, config ID, validator, and lock tag
     * @dev This function handles three distinct configuration types with different storage patterns:
     *
     * ECDSA_VALIDATOR (0x1): Returns ABI-encoded signer address
     * - Loads a single address (20 bytes) from storage
     * - Returns abi.encode(address) - the authorized ECDSA signer
     *
     * PASSKEY_VALIDATOR (0x1001): Returns ABI-encoded WebAuthnCredential struct
     * - Loads WebAuthnCredential containing pubKeyX, pubKeyY, requireUV, and usePrecompile
     * - Returns abi.encode(WebAuthnCredential) with P256 public key and validation flags
     *
     * Custom validators (other addresses): Returns raw configuration bytes
     * - Loads compressed configuration data from storage
     * - Returns uncompressed validator-specific configuration bytes
     *
     * Storage slot derivation:
     * - Slot = keccak256(account, configId, lockTag, validator)
     * - Each combination has unique storage ensuring no collisions
     *
     * @param account The sponsor account whose configuration to retrieve
     * @param configId The configuration ID (allows multiple configs per validator)
     * @param validator The validator address (determines configuration format)
     * @param lockTag The lock tag derived from allocator, scope, and reset period
     * @return config The configuration data encoded according to validator type
     */
    function getConfig(address account, uint8 configId, address validator, bytes12 lockTag) external view returns (bytes memory config) {
        bytes32 slot = account.configSlot(configId, lockTag, validator);
        if (validator == ECDSA_VALIDATOR) {
            config = abi.encode(slot.loadAddressUnchecked());
        } else if (validator == PASSKEY_VALIDATOR) {
            WebAuthnCredential memory creds = slot.loadPasskeyCredentials();
            config = abi.encode(creds);
        } else {
            Compressed.Bytes storage $config = slot.loadCompressedBytes();
            config = $config.sload();
        }
    }
}
