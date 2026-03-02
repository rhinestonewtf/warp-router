# Permit2EIP712

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/Permit2EIP712.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Abstract contract for EIP-712 domain separation and typed data hashing for Permit2 protocol

This contract provides the foundation for creating and verifying EIP-712 signatures
specifically for the Permit2 protocol. It handles domain separator computation and
typed data hashing in a gas-efficient manner using assembly optimizations.
The Permit2 protocol uses a simplified EIP-712 domain with only name, chainId, and
verifyingContract fields (no version field), making it distinct from standard EIP-712.
Key features:

- Immutable domain separator caching for the deployment chain
- Support for cross-chain signature validation via dynamic domain separators
- Gas-optimized assembly implementations for hashing operations
- Scratch space utilization to minimize memory allocation

**Note:**
security: Domain separators prevent signature replay across chains and contracts

## State Variables

### \_NAME_HASH

Hash of the Permit2 protocol name: keccak256("Permit2")

Used in EIP-712 domain separator computation

```solidity
bytes32 private constant _NAME_HASH = 0x9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a
```

### \_PERMIT2_DOMAIN_TYPEHASH

EIP-712 domain type hash for Permit2: keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)")

Note the absence of version field, which differs from standard EIP-712 domains

```solidity
bytes32 private constant _PERMIT2_DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866
```

### PERMIT2

The Permit2 contract address for signature verification

Immutable to ensure consistent domain separation throughout contract lifetime

```solidity
address private immutable PERMIT2
```

### PERMIT2_DOMAINSEPARATOR

Cached domain separator for the deployment chain

Pre-computed at deployment for gas efficiency on the primary chain

```solidity
bytes32 internal immutable PERMIT2_DOMAINSEPARATOR
```

## Functions

### constructor

Initializes the Permit2 EIP-712 domain parameters

Caches the domain separator for the deployment chain to save gas on subsequent calls.
The cached separator is used when validating signatures on the same chain where
the contract was deployed.

```solidity
constructor(address permit2) ;
```

**Parameters**

| Name      | Type      | Description                                                    |
| --------- | --------- | -------------------------------------------------------------- |
| `permit2` | `address` | The address of the Permit2 contract for signature verification |

### \_permit2DomainSeparator

Returns the cached domain separator for the deployment chain

Gas-efficient getter that returns the pre-computed domain separator.
This should be used for same-chain signature validation.

**Note:**
gas: Minimal gas cost as it returns an immutable value

```solidity
function _permit2DomainSeparator() internal view returns (bytes32);
```

**Returns**

| Name     | Type      | Description                                                         |
| -------- | --------- | ------------------------------------------------------------------- |
| `<none>` | `bytes32` | The domain separator for the chain where this contract was deployed |

### \_permit2DomainSeparator

Computes the domain separator for a specific chain ID

Dynamically calculates the EIP-712 domain separator for cross-chain signature validation.
This enables verification of signatures created on different chains (notarized signatures).
The domain separator is computed as:
keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, chainId, permit2Address))
Assembly implementation details:

- Uses allocated memory (via mload(0x40)) for the domain struct
- Stores 4 words sequentially: typehash, name, chainId, verifyingContract
- Hashes 128 bytes (0x80) to produce the domain separator

**Notes:**

- gas: ~800 gas for computation (keccak256 + memory operations)

- security: Critical for preventing cross-chain replay attacks

```solidity
function _permit2DomainSeparator(uint256 notarizedChainId) internal view returns (bytes32 notarizedDomainSeparator);
```

**Parameters**

| Name               | Type      | Description                                            |
| ------------------ | --------- | ------------------------------------------------------ |
| `notarizedChainId` | `uint256` | The chain ID for which to compute the domain separator |

**Returns**

| Name                       | Type      | Description                                           |
| -------------------------- | --------- | ----------------------------------------------------- |
| `notarizedDomainSeparator` | `bytes32` | The computed domain separator for the specified chain |

### \_permit2HashTypedData

Computes the EIP-712 typed data hash for a specific chain

Creates the final digest for signature verification by combining the domain separator
with the struct hash according to EIP-712 specification.
The digest is computed as:
keccak256("\x19\x01" || domainSeparator || structHash)
Assembly optimization details:

- Uses scratch space (0x00-0x5A) to avoid memory allocation
- Stores "\x19\x01" prefix at 0x18-0x19 (shifted for alignment)
- Places domain separator at 0x1A-0x39
- Places struct hash at 0x3A-0x59
- Hashes 66 bytes (0x42) starting from 0x18
- Clears position 0x3A after use (defensive cleanup)

**Notes:**

- gas: ~1000 gas (domain separator computation + keccak256)

- security: The digest binds the signature to a specific chain and contract

```solidity
function _permit2HashTypedData(bytes32 structHash, uint256 chainId) internal view returns (bytes32 digest);
```

**Parameters**

| Name         | Type      | Description                                   |
| ------------ | --------- | --------------------------------------------- |
| `structHash` | `bytes32` | The hash of the structured data to be signed  |
| `chainId`    | `uint256` | The chain ID for domain separator computation |

**Returns**

| Name     | Type      | Description                                               |
| -------- | --------- | --------------------------------------------------------- |
| `digest` | `bytes32` | The final EIP-712 digest ready for signature verification |

### \_permit2HashTypedData

Computes the EIP-712 typed data hash for the deployment chain

Optimized version that uses the cached domain separator for same-chain operations.
This is more gas-efficient than the cross-chain version as it skips domain
separator computation.
Uses the same assembly optimization pattern as the cross-chain version but
with the pre-computed domain separator.

**Notes:**

- gas: ~200 gas (just keccak256, no domain computation)

- usage: Primary function for same-chain signature validation

```solidity
function _permit2HashTypedData(bytes32 structHash) internal view returns (bytes32 digest);
```

**Parameters**

| Name         | Type      | Description                                  |
| ------------ | --------- | -------------------------------------------- |
| `structHash` | `bytes32` | The hash of the structured data to be signed |

**Returns**

| Name     | Type      | Description                                       |
| -------- | --------- | ------------------------------------------------- |
| `digest` | `bytes32` | The final EIP-712 digest for the deployment chain |
