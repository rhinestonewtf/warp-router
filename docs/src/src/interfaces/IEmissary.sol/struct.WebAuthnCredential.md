# WebAuthnCredential
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IEmissary.sol)

WebAuthn credential structure for P256 passkey validation
Stores the public key coordinates and validation flags for WebAuthn signature verification


```solidity
struct WebAuthnCredential {
bool requireUV;
bool usePrecompile;
uint256 pubKeyX;
uint256 pubKeyY;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`requireUV`|`bool`|Whether user verification (UV) is required during authentication|
|`usePrecompile`|`bool`|Whether to use RIP-7212 precompile for P256 verification (if available)|
|`pubKeyX`|`uint256`|The X coordinate of the P256 public key|
|`pubKeyY`|`uint256`|The Y coordinate of the P256 public key|

