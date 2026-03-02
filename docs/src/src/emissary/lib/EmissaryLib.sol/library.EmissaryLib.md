# EmissaryLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/emissary/lib/EmissaryLib.sol)

Library for packing and unpacking emissary data format

EmissaryData format: [validator(20)][configId(1)][signatureData(variable)]
The emissaryData encoding contains three components:
1. Validator address (20 bytes) - Determines validation mode (ECDSA, Passkey, or custom)
2. Config ID (1 byte) - Identifies which config to use for this validator
3. Signature data (variable length) - Validator-specific signature payload
This format allows:
- Multiple configs per validator address (via different configIds)
- Compact encoding for gas efficiency
- Clear separation between routing info (validator+configId) and signature data


## Functions
### unpack

Unpacks emissary data into its component parts

Extracts validator address, config ID, and signature data from packed bytes
Format breakdown:
- Bytes [0:20]: Validator address (determines ECDSA/Passkey/Custom mode)
- Byte [20]: Config ID (allows multiple configs per validator)
- Bytes [21:]: Signature data (format depends on validator type)

**Note:**
example: 
For ECDSA: signatureData is raw ECDSA signature (v,r,s format)
For Passkey: signatureData is ABI-encoded WebAuthn.WebAuthnAuth struct
For Custom: signatureData format is defined by the custom validator


```solidity
function unpack(bytes calldata emissaryData) internal pure returns (address validator, uint8 configId, bytes calldata signatureData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emissaryData`|`bytes`|The packed emissary data bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validator`|`address`|The validator address extracted from bytes [0:20]|
|`configId`|`uint8`|The config ID extracted from byte [20]|
|`signatureData`|`bytes`|The remaining bytes [21:] containing validator-specific signature|


### pack

Packs validator address, config ID, and signature data into emissary data format

Concatenates the three components into the standard emissary data format
This function creates the packed format expected by verifyClaim:
[validator address][config ID][signature data]

**Note:**
usage: This is typically used when constructing claims that will be verified
via the Emissary contract's verifyClaim function


```solidity
function pack(address validator, uint8 configId, bytes memory signatureData) internal pure returns (bytes memory emissaryData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`validator`|`address`|The validator address (20 bytes) - determines validation mode|
|`configId`|`uint8`|The config ID (1 byte) - identifies which config to use|
|`signatureData`|`bytes`|The validator-specific signature data (variable length)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`emissaryData`|`bytes`|The packed bytes in emissary data format|


### pack


```solidity
function pack(WebAuthnCredential memory passkeyAuth) internal pure returns (bytes memory packed);
```

### unpackWebAuthnCredential

Unpacks bytes into WebAuthnCredential components

Extracts the four fields from packed bytes created by pack(WebAuthnCredential)
Format breakdown:
- Byte [0]: requireUV (bool)
- Byte [1]: usePrecompile (bool)
- Bytes [2:34]: pubKeyX (uint256)
- Bytes [34:66]: pubKeyY (uint256)


```solidity
function unpackWebAuthnCredential(bytes calldata packed)
    internal
    pure
    returns (bool requireUV, bool usePrecompile, uint256 pubKeyX, uint256 pubKeyY);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packed`|`bytes`|The packed WebAuthnCredential bytes (66 bytes total)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requireUV`|`bool`|Whether user verification is required|
|`usePrecompile`|`bool`|Whether to use precompile for verification|
|`pubKeyX`|`uint256`|The X coordinate of the public key|
|`pubKeyY`|`uint256`|The Y coordinate of the public key|


