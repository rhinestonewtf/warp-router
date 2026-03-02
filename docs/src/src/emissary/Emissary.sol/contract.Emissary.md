# Emissary
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/emissary/Emissary.sol)

**Inherits:**
[IEmissary](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/IEmissary.sol/interface.IEmissary.md), EIP712, [CompactEIP712](/Users/ops/work/rhinestone/compact-utils/docs/src/src/types/EIP712.sol/library.CompactEIP712.md)

Manages configurations for stateless validators associated with sponsor accounts and lock tags

This contract acts as a central point for managing validator configurations across different chains.
It supports three types of validation modes determined by the validator address:
- ECDSA_VALIDATOR (0x1): Built-in ECDSA signature validation with a configured signer address
- PASSKEY_VALIDATOR (0x1001): Built-in WebAuthn P256 signature validation with stored credentials
- Custom validators (other addresses): External stateless validators with compressed storage
Multiple configurations can exist for the same validator address by using different configIds.
For example, you can have multiple ECDSA signers under configId 1, 2, 3, etc., all using ECDSA_VALIDATOR.
The contract uses a nonce mechanism per sponsor and lock tag to prevent replay attacks on configuration
updates. The lock tag is derived from the allocator ID, scope, and reset period.
Configuration updates require two signatures:
- User signature: Always required unless msg.sender is the account itself
- Allocator signature: Only required when updating existing config (init=false), skipped on first setup

**Note:**
security: All configuration updates are protected by EIP-712 signatures and nonce-based replay protection


## State Variables
### ECDSA_VALIDATOR
Validator address for ECDSA signature validation mode
When config.validator == ECDSA_VALIDATOR, uses built-in ECDSA signature verification
Multiple ECDSA signers can be configured using different configIds


```solidity
address internal constant ECDSA_VALIDATOR = address(0x1)
```


### PASSKEY_VALIDATOR
Validator address for WebAuthn passkey validation mode
When config.validator == PASSKEY_VALIDATOR, uses built-in P256 WebAuthn verification
Multiple passkeys can be configured using different configIds


```solidity
address internal constant PASSKEY_VALIDATOR = address(0x1001)
```


### INVALID_SIGNATURE
Signature indicating invalid signature verification
Returned when signature validation fails in verifyClaim


```solidity
bytes4 internal constant INVALID_SIGNATURE = bytes4(0xFFFFFFFF)
```


## Functions
### constructor

Initializes the Emissary contract with The Compact contract address

Sets up EIP-712 domain separator by inheriting from CompactEIP712


```solidity
constructor(address compact) CompactEIP712(compact);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`compact`|`address`|The address of The Compact contract for cross-chain validation|


### setConfig

Sets or updates the configuration for a specific validator, config ID, and lock tag
associated with a sponsor account

This function handles three distinct configuration types with different storage patterns:
TYPE_ECDSA (1): Stores a single address (20 bytes) as the authorized signer
- validatorConfig contains the signer address in the first 20 bytes
- Signature verification uses ECDSA.recoverCalldata to extract and compare signer
- Storage: Direct address storage at computed slot
TYPE_PASSKEY (2): Stores WebAuthn credentials (P256 public key + flags)
- validatorConfig is ABI-encoded WebAuthnCredential struct
- Stores pubKeyX, pubKeyY (uint256 each), requireUV and usePrecompile (bool flags)
- Signature verification uses WebAuthn.verify with challenge-response protocol
Custom validators (3+): Stores arbitrary configuration using compressed storage
- validatorConfig is validator-specific bytes that get compressed
- Delegates signature verification to IStatelessValidator.validateSignatureWithData
- Storage: Uses CompressedStorageLib for efficient storage
The init flag determines whether allocator signature is required:
- init=true: First time setup, no existing config, allocator signature is skipped
- init=false: Updating existing config, allocator must authorize the change

**Notes:**
- security: Requires monotonically increasing nonce to prevent replay attacks

- security: User signature always required unless msg.sender is the account itself

- security: Allocator signature only required on updates (not initial setup)


```solidity
function setConfig(address account, EmissaryConfig calldata config, EmissaryEnable calldata enableData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The sponsor account for which the configuration is being set|
|`config`|`EmissaryConfig`|The EmissaryConfig struct containing validator, configId, scope, resetPeriod, allocator, and validatorConfig|
|`enableData`|`EmissaryEnable`|The EmissaryEnable struct containing signatures, nonce, expiry, chain IDs, and the current chain index|


### verifyClaim

Verifies a claim hash using the configured stateless validator for a given sponsor
and lock tag.

Extracts the validator address and config ID from the start of `emissaryData`.
Retrieves the corresponding configuration data.
Calls the `validateSignatureWithData` function on the specified validator.


```solidity
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
    returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sponsor`|`address`|The sponsor account associated with the claim.|
|`digest`|`bytes32`|The hash of the claim being verified.|
|`<none>`|`bytes32`||
|`emissaryData`|`bytes`|Data containing the validator address (first 20 bytes), config ID (next byte), and the validator-specific signature data (remaining bytes).|
|`lockTag`|`bytes12`|The lock tag associated with the configuration to use for verification.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|The selector `this.verifyClaim.selector` if the signature is valid according to the validator, otherwise returns `bytes4(0xFFFFFFFF)`.|


### _validateSignature

Internal function that performs the actual signature validation logic

This function handles three distinct validation paths based on validator address:
ECDSA_VALIDATOR (0x1): Built-in ECDSA signature verification
- Recovers signer from signature using ECDSA.recoverCalldata
- Compares recovered signer with stored signer address for the given configId
- Returns true if they match
PASSKEY_VALIDATOR (0x1001): Built-in WebAuthn passkey verification
- Decodes WebAuthnAuth struct from emissaryData
- Loads stored credentials (pubKeyX, pubKeyY, requireUV, usePrecompile) for the given configId
- Uses WebAuthn.verify with challenge-response protocol
- Returns true if P256 signature verification succeeds
Other addresses: External stateless validator
- Uses the validator address specified in emissaryData
- Loads compressed configuration data from storage for the given configId
- Delegates to IStatelessValidator.validateSignatureWithData
- Returns result from external validator
Storage slot derivation:
- Slot = keccak256(sponsor, configId, lockTag, validator)
- This ensures each sponsor+configId+lockTag+validator combination has unique storage
- Multiple configs can exist for the same validator under different configIds


```solidity
function _validateSignature(address sponsor, bytes32 digest, bytes calldata emissaryData, bytes12 lockTag)
    internal
    view
    virtual
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sponsor`|`address`|The sponsor account whose signature is being validated|
|`digest`|`bytes32`|The EIP-712 digest being signed|
|`emissaryData`|`bytes`|Packed data: [validator(20)][configId(1)][signatureData(var)]|
|`lockTag`|`bytes12`|The lock tag derived from allocator, scope, and reset period|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if signature is valid, false otherwise|


### _domainNameAndVersion

Returns the EIP-712 domain name and version for this contract

Used in the EIP-712 signature hashing process to construct the domain separator.
The domain separator ensures signatures are unique to this contract and chain.
EIP-712 signing flow:
1. Create typed struct hash: hashStruct(SetConfig(...))
2. Get domain separator: DOMAIN_SEPARATOR()
3. Combine: keccak256("\x19\x01" || domainSeparator || hashStruct)
4. Sign the final digest with user's private key


```solidity
function _domainNameAndVersion() internal view virtual override returns (string memory name, string memory version);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The domain name ("Emissary")|
|`version`|`string`|The domain version ("0.0.1")|


### DOMAIN_SEPARATOR

Returns the EIP-712 domain separator for this contract instance
This ensures signatures are unique to:
- This specific contract deployment (address)
- The contract name and version


```solidity
function DOMAIN_SEPARATOR() public view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The EIP-712 domain separator for signature validation|


### getConfig

Retrieves the stored validator configuration for a specific account, config ID, validator, and lock tag

This function handles three distinct configuration types with different storage patterns:
ECDSA_VALIDATOR (0x1): Returns ABI-encoded signer address
- Loads a single address (20 bytes) from storage
- Returns abi.encode(address) - the authorized ECDSA signer
PASSKEY_VALIDATOR (0x1001): Returns ABI-encoded WebAuthnCredential struct
- Loads WebAuthnCredential containing pubKeyX, pubKeyY, requireUV, and usePrecompile
- Returns abi.encode(WebAuthnCredential) with P256 public key and validation flags
Custom validators (other addresses): Returns raw configuration bytes
- Loads compressed configuration data from storage
- Returns uncompressed validator-specific configuration bytes
Storage slot derivation:
- Slot = keccak256(account, configId, lockTag, validator)
- Each combination has unique storage ensuring no collisions


```solidity
function getConfig(address account, uint8 configId, address validator, bytes12 lockTag) external view returns (bytes memory config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The sponsor account whose configuration to retrieve|
|`configId`|`uint8`|The configuration ID (allows multiple configs per validator)|
|`validator`|`address`|The validator address (determines configuration format)|
|`lockTag`|`bytes12`|The lock tag derived from allocator, scope, and reset period|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`config`|`bytes`|The configuration data encoded according to validator type|


## Events
### EmissaryConfigUpdated
Emitted when a new validator configuration is successfully set for an account and
lock tag.


```solidity
event EmissaryConfigUpdated(address indexed account, IStatelessValidator indexed validator, bytes12 indexed lockTag)
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The sponsor account whose configuration was updated.|
|`validator`|`IStatelessValidator`|The stateless validator address associated with the configuration.|
|`lockTag`|`bytes12`|The lock tag derived from the allocator, scope, and reset period.|

## Errors
### InvalidSignature

```solidity
error InvalidSignature()
```

