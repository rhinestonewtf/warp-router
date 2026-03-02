# CompactEIP712

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/CompactEIP712.sol)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Abstract contract for EIP-712 domain separation and typed data hashing for The Compact protocol

This contract provides the foundation for creating and verifying EIP-712 signatures
specifically for The Compact protocol. Unlike Permit2, The Compact uses the full
EIP-712 domain specification including name, version, chainId, and verifyingContract.
The Compact protocol enables cross-chain intent execution with proper domain separation
to prevent signature replay attacks across different chains and contract deployments.
Key features:

- Full EIP-712 domain with version field (v1)
- Immutable domain separator caching for deployment chain
- Support for notarized (cross-chain) signature validation
- Gas-optimized assembly implementations
- Efficient scratch space usage for digest computation

**Notes:**

- security: Domain separators ensure signatures cannot be replayed across chains or contracts

- protocol: The Compact uses this for intent-based cross-chain execution

## State Variables

### COMPACT

The Compact contract address for signature verification

Immutable to ensure consistent domain separation throughout contract lifetime

```solidity
address internal immutable COMPACT
```

### COMPACT_DOMAINSEPARATOR

Cached domain separator for the deployment chain

Pre-computed at deployment for gas efficiency on the primary chain

```solidity
bytes32 private immutable COMPACT_DOMAINSEPARATOR
```

### \_COMPACT_DOMAIN_TYPEHASH

EIP-712 domain type hash: keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")

Standard EIP-712 domain with all four fields (includes version unlike Permit2)

```solidity
bytes32 internal constant _COMPACT_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f
```

### \_NAME_HASH

Hash of The Compact protocol name: keccak256(bytes("The Compact"))

Used in EIP-712 domain separator computation

```solidity
bytes32 internal constant _NAME_HASH = 0x5e6f7b4e1ac3d625bac418bc955510b3e054cb6cc23cc27885107f080180b292
```

### \_VERSION_HASH

Hash of the protocol version: keccak256("1")

Version "1" indicates the first iteration of The Compact protocol

```solidity
bytes32 internal constant _VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6
```

## Functions

### constructor

Initializes The Compact EIP-712 domain parameters

Caches the domain separator for the deployment chain to save gas on subsequent calls.
The cached separator is used when validating signatures on the same chain where
the contract was deployed.

```solidity
constructor(address compact) ;
```

**Parameters**

| Name      | Type      | Description                                                    |
| --------- | --------- | -------------------------------------------------------------- |
| `compact` | `address` | The address of The Compact contract for signature verification |

### \_compactDomainSeparator

Returns the cached domain separator for the deployment chain

Gas-efficient getter that returns the pre-computed domain separator.
This should be used for same-chain signature validation.

**Note:**
gas: Minimal gas cost as it returns an immutable value

```solidity
function _compactDomainSeparator() internal view virtual returns (bytes32);
```

**Returns**

| Name     | Type      | Description                                                         |
| -------- | --------- | ------------------------------------------------------------------- |
| `<none>` | `bytes32` | The domain separator for the chain where this contract was deployed |

### \_compactHashTypedData

Computes the EIP-712 typed data hash for the deployment chain

Creates the final digest for signature verification using the cached domain separator.
This is the primary function for same-chain signature validation.
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

- gas: ~200 gas (just keccak256, no domain computation)

- usage: Primary function for validating signatures created on the same chain

```solidity
function _compactHashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest);
```

**Parameters**

| Name         | Type      | Description                                  |
| ------------ | --------- | -------------------------------------------- |
| `structHash` | `bytes32` | The hash of the structured data to be signed |

**Returns**

| Name     | Type      | Description                                       |
| -------- | --------- | ------------------------------------------------- |
| `digest` | `bytes32` | The final EIP-712 digest for the deployment chain |

### \_compactHashTypedData

Computes the EIP-712 typed data hash for a notarized (cross-chain) signature

Creates the final digest for cross-chain signature verification by computing
the domain separator for the specified chain.
This enables The Compact protocol to validate signatures that were created
on different chains, essential for cross-chain intent execution.
Uses the same assembly optimization pattern as the same-chain version but
computes the domain separator dynamically for the notarized chain.

**Notes:**

- gas: ~1000 gas (domain separator computation + keccak256)

- security: Critical for validating cross-chain intents in The Compact protocol

```solidity
function _compactHashTypedData(bytes32 structHash, uint256 notarizedChainId) internal view virtual returns (bytes32 digest);
```

**Parameters**

| Name               | Type      | Description                                  |
| ------------------ | --------- | -------------------------------------------- |
| `structHash`       | `bytes32` | The hash of the structured data to be signed |
| `notarizedChainId` | `uint256` | The chain ID where the signature was created |

**Returns**

| Name     | Type      | Description                                         |
| -------- | --------- | --------------------------------------------------- |
| `digest` | `bytes32` | The final EIP-712 digest for cross-chain validation |

### \_compactDomainSeparator

Computes the domain separator for a specific chain ID

Dynamically calculates the EIP-712 domain separator for cross-chain signature validation.
This is essential for The Compact's cross-chain intent execution capabilities.
The domain separator is computed as:
keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chainId, compactAddress))
Assembly implementation details:

- Uses allocated memory (via mload(0x40)) for the domain struct
- Stores 5 words sequentially: typehash, name, version, chainId, verifyingContract
- Hashes 160 bytes (0xA0) to produce the domain separator

**Notes:**

- gas: ~900 gas for computation (keccak256 + memory operations)

- protocol: Used for validating intents created on different chains

```solidity
function _compactDomainSeparator(uint256 notarizedChainId) internal view returns (bytes32 notarizedDomainSeparator);
```

**Parameters**

| Name               | Type      | Description                                            |
| ------------------ | --------- | ------------------------------------------------------ |
| `notarizedChainId` | `uint256` | The chain ID for which to compute the domain separator |

**Returns**

| Name                       | Type      | Description                                           |
| -------------------------- | --------- | ----------------------------------------------------- |
| `notarizedDomainSeparator` | `bytes32` | The computed domain separator for the specified chain |
