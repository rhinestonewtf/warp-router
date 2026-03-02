# RSAllocator
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/allocator/RSAllocator.sol)

**Inherits:**
Ownable, [CompactEIP712](/Users/ops/work/rhinestone/compact-utils/docs/src/src/types/EIP712.sol/library.CompactEIP712.md)

Rhinestone's implementation of a TheCompact Allocator that validates signatures made on claims

This contract rebuilds the domain separator from TheCompact and produces the digest for signature validation.
It implements signature-based claim authorization where a designated signer must approve claims.
Key features:
- Signature-based claim authorization using ECDSA
- EIP-712 typed data hashing for secure message signing
- EIP-1271 compliance for contract-based signature validation
- Ownable pattern for signer management
- Integration with TheCompact protocol


## State Variables
### TYPEHASH_CONSUMENONCE
`keccak256("ConsumeNonce(uint256[] nonces)")`.


```solidity
bytes32 internal constant TYPEHASH_CONSUMENONCE = 0xc388303b4ae891d202248584dad8838f8418a633b4f603df8eaf6a69ac7c9030
```


### signer
The authorized signer address for claim validation


```solidity
address public signer
```


### ERROR
Constant returned by isValidSignature for invalid signatures (EIP-1271)


```solidity
bytes4 internal constant ERROR = bytes4(0xFFFFFFFF)
```


### ALLOCATOR_ID
The unique identifier assigned by TheCompact upon registration


```solidity
uint96 public immutable ALLOCATOR_ID
```


## Functions
### constructor

Initializes the RSAllocator with TheCompact registration

The constructor registers this allocator with TheCompact and sets up ownership


```solidity
constructor(address compact, address _owner, address _signer) CompactEIP712(compact);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`compact`|`address`|Address of TheCompact contract|
|`_owner`|`address`|Address that will own the allocator (can update signer)|
|`_signer`|`address`|Initial signer address for claim validation|


### setSigner

Updates the authorized signer address

Only the contract owner can call this function
Emits SignerUpdated event after successful update


```solidity
function setSigner(address _signer) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signer`|`address`|New signer address|


### consumeNonce

Consumes allocator nonces, invalidating any claims that use them

DANGER: This is a potentially dangerous function that gives the allocator the power to break existing compacts.
When a nonce is consumed, any claims that depend on that nonce will become invalid and unable to be processed.
This effectively allows the allocator to revoke or cancel pending claims by invalidating their nonces.
Use cases for this function:
- Emergency cancellation of pending claims
- Revoking access before a claim can be processed
- Invalidating claims that are no longer desired
Security considerations:
- Only the authorized signer can approve nonce consumption via EIP-712 signature
- Nonces are permanently consumed and cannot be reused
- This action is irreversible - consumed nonces cannot be "unconsumed"
- Users relying on claims with these nonces will have their claims fail
The signature must be over the EIP-712 typed data hash:
ConsumeNonce(uint256[] nonces)
combined with TheCompact's domain separator to prevent cross-chain and cross-contract replay attacks.


```solidity
function consumeNonce(uint256[] calldata nonces, bytes calldata signature) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonces`|`uint256[]`|Array of nonce values to consume|
|`signature`|`bytes`|EIP-712 signature from the authorized signer approving the nonce consumption|


### isClaimAuthorized

Checks if a claim is authorized by validating the signature in allocatorData

This function is called by TheCompact to validate claims before processing.
Supports both qualified claims (with qualification hash) and direct signature verification.


```solidity
function isClaimAuthorized(
    bytes32 claimHash, // The message hash representing the claim.
    address,
    /* arbiter*/
    // The account tasked with verifying and submitting the claim.
    address,
    /* sponsor*/
    // The account to source the tokens from.
    uint256,
    /* nonce*/
    // A parameter to enforce replay protection, scoped to allocator.
    uint256,
    /* expires*/
    // The time at which the claim expires.
    uint256[2][] calldata,
    /* idsAndAmounts*/
    // The allocated token IDs and amounts.
    bytes calldata allocatorData // Arbitrary data provided by the arbiter.
)
    external
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The message hash representing the claim to be authorized|
|`<none>`|`address`||
|`<none>`|`address`||
|`<none>`|`uint256`||
|`<none>`|`uint256`||
|`<none>`|`uint256[2][]`||
|`allocatorData`|`bytes`|Signature data, optionally prefixed with qualification hash if length > 65 bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the claim is authorized, false otherwise|


### authorizeClaim

Authorizes a claim by validating the signature and returns the function selector if valid

This function is called by TheCompact during claim processing.
Supports both qualified claims (with qualification hash) and direct signature verification.


```solidity
function authorizeClaim(
    bytes32 claimHash,
    address, /* arbiter*/
    address, /* sponsor*/
    uint256, /* nonce*/
    uint256, /* expires*/
    uint256[2][] calldata, /* idsAndAmounts*/
    bytes calldata allocatorData
)
    external
    view
    returns (bytes4 ret);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The message hash representing the claim to be authorized|
|`<none>`|`address`||
|`<none>`|`address`||
|`<none>`|`uint256`||
|`<none>`|`uint256`||
|`<none>`|`uint256[2][]`||
|`allocatorData`|`bytes`|Signature data, optionally prefixed with qualification hash if length > 65 bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ret`|`bytes4`|The function selector if authorized, zero bytes otherwise|


### _authorizeClaim

Internal function to validate claim authorization through signature verification

This function implements the core signature verification logic used by both public authorization functions.
If allocatorData is longer than 65 bytes, the first 32 bytes are treated as a qualification hash
which is combined with the claim hash. Otherwise, the claim hash is used directly for verification.


```solidity
function _authorizeClaim(bytes32 claimHash, bytes calldata allocatorData) internal view virtual returns (bool valid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimHash`|`bytes32`|The original claim hash to be validated|
|`allocatorData`|`bytes`|The signature data, optionally prefixed with qualification hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`valid`|`bool`|True if the signature is valid and matches the authorized signer|


### isValidSignature

EIP-1271 signature validation interface for contract-based signature verification

This allows the contract to act as a signer for EIP-1271 compliant systems
Returns the function selector (0x1626ba7e) for valid signatures, ERROR (0xFFFFFFFF) for invalid ones


```solidity
function isValidSignature(bytes32 digest, bytes calldata signature) public view returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`digest`|`bytes32`|The message hash to validate|
|`signature`|`bytes`|The signature bytes to validate against the digest|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|bytes4 The function selector if signature is valid, ERROR constant if invalid|


## Events
### SignerUpdated
Emitted when the authorized signer address is updated


```solidity
event SignerUpdated(address newSigner)
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSigner`|`address`|The new signer address|

## Errors
### InvalidConstructor

```solidity
error InvalidConstructor()
```

### InvalidSignature

```solidity
error InvalidSignature()
```

