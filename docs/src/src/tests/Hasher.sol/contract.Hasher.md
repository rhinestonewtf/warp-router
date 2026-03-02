# Hasher
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/Hasher.sol)


## State Variables
### _NAME_HASH

```solidity
bytes32 private constant _NAME_HASH = 0x9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a
```


### _PERMIT2_DOMAIN_TYPEHASH

```solidity
bytes32 private constant _PERMIT2_DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866
```


### PERMIT2

```solidity
address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3
```


## Functions
### hashTypedDataPermit2


```solidity
function hashTypedDataPermit2(uint256 chainId, bytes32 permit2Hash) external pure returns (bytes32 digest);
```

### _permit2DomainSeparator


```solidity
function _permit2DomainSeparator(uint256 notarizedChainId) internal pure returns (bytes32 notarizedDomainSeparator);
```

### hashTokenIn


```solidity
function hashTokenIn(uint256[2][] calldata tokenIn) external view returns (bytes32);
```

### hashTokenOut


```solidity
function hashTokenOut(uint256[2][] calldata tokenOut) external view returns (bytes32);
```

### hashQualifier


```solidity
function hashQualifier(bytes calldata data) external view returns (bytes32);
```

### hashTargetAttributes


```solidity
function hashTargetAttributes(Types.Order calldata order) external view returns (bytes32);
```

### hashElement


```solidity
function hashElement(Types.Order calldata order, address arbiter, uint256 originChainId) external view returns (bytes32);
```

### hashMandate


```solidity
function hashMandate(Types.Order calldata order) external view returns (bytes32);
```

### hashMandate


```solidity
function hashMandate(Mandate calldata mandate) external view returns (bytes32);
```

### hashCompact


```solidity
function hashCompact(Types.Order calldata order, bytes32[] calldata allElements) external view returns (bytes32);
```

### hashOps


```solidity
function hashOps(Execution[] calldata execs) external pure returns (bytes32);
```

### hashMandateRaw


```solidity
function hashMandateRaw(bytes32 targetAttributes, uint8 v, uint128 minGas, bytes32 preClaimOpsHash, bytes32 destOpsHash, bytes32 qHash)
    external
    pure
    returns (bytes32);
```

### hashPermit2


```solidity
function hashPermit2(bytes32 tokenInHash, address arbiter, uint256 nonce, uint256 expires, bytes32 mandate)
    external
    pure
    returns (bytes32);
```

### hashOperation


```solidity
function hashOperation(Types.Operation calldata ops) external pure returns (bytes32);
```

### permit2HashForTesting


```solidity
function permit2HashForTesting(
    IPermit2IntentExecutor.EIP712Permit2Stub calldata permit2Stub,
    IPermit2IntentExecutor.EIP712Permit2MandateStub calldata mandateStub,
    bytes32 preClaimOpsHash,
    address arbiter
)
    external
    pure
    returns (bytes32 permit2Hash);
```

### measureTokenInGas


```solidity
function measureTokenInGas(uint256[2][] calldata tokenIn) external view returns (uint256 gasUsed);
```

### measureTokenOutGas


```solidity
function measureTokenOutGas(uint256[2][] calldata tokenOut) external view returns (uint256 gasUsed);
```

### measureCompactGas


```solidity
function measureCompactGas(Types.Order calldata order, bytes32[] calldata allElements) external view returns (uint256 gasUsed);
```

### measureElementGas


```solidity
function measureElementGas(Types.Order calldata order, address arbiter, uint256 originChainId) external view returns (uint256 gasUsed);
```

### measureMandateGas


```solidity
function measureMandateGas(Types.Order calldata order) external view returns (uint256 gasUsed);
```

### measureTargetAttributesGas


```solidity
function measureTargetAttributesGas(Types.Order calldata order) external view returns (uint256 gasUsed);
```

### measureOpsGas


```solidity
function measureOpsGas(Execution[] calldata execs) external view returns (uint256 gasUsed);
```

### permit2_hashBatchWithWitness


```solidity
function permit2_hashBatchWithWitness(Types.Order calldata order, address arbiter) external view returns (bytes32);
```

### _hashTokenPermissions


```solidity
function _hashTokenPermissions(ISignatureTransfer.TokenPermissions memory permitted) private pure returns (bytes32);
```

