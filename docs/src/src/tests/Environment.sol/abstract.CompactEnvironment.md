# CompactEnvironment
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/Environment.sol)

**Inherits:**
Test, RhinestoneModuleKit, [AddressBookHelper](/Users/ops/work/rhinestone/compact-utils/docs/src/src/tests/AddressBookHelper.sol/contract.AddressBookHelper.md)


## State Variables
### env

```solidity
Environment internal env
```


### chains

```solidity
Chains internal chains
```


### intent

```solidity
Intent internal intent
```


### hasher

```solidity
Hasher internal hasher
```


## Functions
### withChainId


```solidity
modifier withChainId(uint256 chainId) ;
```

### _claim


```solidity
function _claim(uint256 chainId, bytes memory relayerContext, bytes memory adapterCalldata)
    internal
    withChainId(chainId)
    returns (uint256 gas);
```

### _fill


```solidity
function _fill(uint256 chainId, bytes[] memory relayerContexts, bytes[] memory adapterCalldatas) internal returns (uint256 gas);
```

### _fill


```solidity
function _fill(uint256 chainId, uint256 value, bytes[] memory relayerContexts, bytes[] memory adapterCalldatas)
    internal
    withChainId(chainId)
    returns (uint256 gas);
```

### _fill


```solidity
function _fill(uint256 chainId, bytes memory relayerContext, bytes memory adapterCalldata) internal returns (uint256 gas);
```

### _fill


```solidity
function _fill(uint256 chainId, uint256 value, bytes memory relayerContext, bytes memory adapterCalldata)
    internal
    withChainId(chainId)
    returns (uint256 gas);
```

### _setRouterTokenApproval


```solidity
function _setRouterTokenApproval(address spender, address token, uint256 amount) internal;
```

### _deployCompact


```solidity
function _deployCompact() public virtual;
```

### _sampleExecERC20


```solidity
function _sampleExecERC20(Token targetChainToken, uint256 amount) internal;
```

### _sampleExecNative


```solidity
function _sampleExecNative(Token targetChainToken, uint256 amount, uint256 param) internal;
```

### _deploySmartAccount


```solidity
function _deploySmartAccount(bool create) public virtual;
```

### _setFillRoute


```solidity
function _setFillRoute(bytes4 selector, address route) internal;
```

### _setClaimRoute


```solidity
function _setClaimRoute(bytes4 selector, address route) internal;
```

### _setEmissary


```solidity
function _setEmissary(AccountInstance storage instance, Account storage signer) internal virtual;
```

### _signHashRaw


```solidity
function _signHashRaw(Account storage eoa, bytes32 digest) internal view returns (bytes memory);
```

### _signHash


```solidity
function _signHash(Account storage eoa, bytes32 digest) internal view returns (bytes memory);
```

### _signOwnableValidator


```solidity
function _signOwnableValidator(Account storage eoa, bytes32 digest) internal view returns (bytes memory);
```

### _emissarySig


```solidity
function _emissarySig(AccountInstance storage smartAccount, Account storage with, bytes32 digest) internal returns (bytes memory);
```

### _allocatorSig


```solidity
function _allocatorSig(Account storage allocator, uint256 chainId, bytes32 claimHash, bytes32 qualificationHash)
    internal
    withChainId(chainId)
    returns (bytes32 digest, bytes memory sig);
```

### _allocatorSig


```solidity
function _allocatorSig(Account storage allocator, uint256 chainId, bytes32 claimHash)
    internal
    withChainId(chainId)
    returns (bytes32 digest, bytes memory sig);
```

### _hashTypedData


```solidity
function _hashTypedData(uint256 chainId, bytes32 claimHash) internal returns (bytes32 digest);
```

### _hashTypedDataPermit2


```solidity
function _hashTypedDataPermit2(uint256 chainId, bytes32 permit2Hash) internal returns (bytes32 digest);
```

### _lockAssets


```solidity
function _lockAssets(AccountInstance storage instance, Token _token, uint256 amount) internal virtual returns (uint256 tokenId);
```

### _lockAssets


```solidity
function _lockAssets(AccountInstance storage instance, address token, uint256 amount) internal virtual returns (uint256 tokenId);
```

### _getOrder


```solidity
function _getOrder(MultichainCompact storage compact, uint256 elementIndex) internal virtual returns (Types.Order memory order);
```

### _getOrder


```solidity
function _getOrder(MultichainCompact storage compact, uint256 elementIndex, uint128 gasStipend)
    internal
    virtual
    returns (Types.Order memory order);
```

### hashCompact


```solidity
function hashCompact(address arbiter, MultichainCompact storage compact)
    internal
    returns (bytes32 claimHash, bytes32[] memory elementHashes);
```

### _getOrder


```solidity
function _getOrder(address sponsor, uint256 nonce, uint256 expires, address arbiter, Element storage element)
    internal
    returns (Types.Order memory order);
```

### _getOrder


```solidity
function _getOrder(address sponsor, uint256 nonce, uint256 expires, address arbiter, Element storage element, uint128 gasStipend)
    internal
    returns (Types.Order memory order);
```

### hashPermit2


```solidity
function hashPermit2(address sponsor, uint256 nonce, uint256 expires, address arbiter, Element storage element)
    internal
    returns (bytes32 hash);
```

### _makeClaimHash


```solidity
function _makeClaimHash(address arbiter) internal;
```

### toId


```solidity
function toId(Token token) internal view returns (uint256);
```

### toId


```solidity
function toId(address token) internal view returns (uint256);
```

### _simulateClaim


```solidity
function _simulateClaim(address arbiter, MultichainCompact storage compact, uint256 elementIndex) internal;
```

### _getEIP712Stubs_TargetOps


```solidity
function _getEIP712Stubs_TargetOps(MultichainCompact storage compact, address claimHashProofer, uint256 elementIndex)
    internal
    returns (
        ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
        ICompactIntentExecutor.EIP712CompactStub memory compactStub
    );
```

### _getEIP712Stubs_PreClaimOps


```solidity
function _getEIP712Stubs_PreClaimOps(MultichainCompact storage compact, uint256 elementIndex)
    internal
    returns (
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        ICompactIntentExecutor.EIP712CompactStub memory compactStub
    );
```

### jump_hashEIP712


```solidity
function jump_hashEIP712(Types.Operation calldata ops) external returns (bytes32);
```

### _toIntentExecutorCall_targetOps


```solidity
function _toIntentExecutorCall_targetOps(MultichainCompact storage compact, address proofSender, bytes memory signature)
    internal
    returns (bytes memory call);
```

### _toIntentExecutorCall_preClaimOps


```solidity
function _toIntentExecutorCall_preClaimOps(MultichainCompact storage compact, uint256 elementIndex, bytes memory signature)
    internal
    returns (bytes memory call);
```

### _newProxy


```solidity
function _newProxy(bytes32 name) internal returns (address);
```

### _setProxyImpl


```solidity
function _setProxyImpl(bytes32 name, address newImpl) internal;
```

### _deployPermit2


```solidity
function _deployPermit2() internal;
```

### _redeployPermit2


```solidity
function _redeployPermit2(uint256 chainId) internal;
```

### _createDigest


```solidity
function _createDigest(bytes32 domainSeparator, bytes32 hashValue) internal pure returns (bytes32);
```

### insertAtAndHash


```solidity
function insertAtAndHash(bytes32[] calldata array, uint256 index, bytes32 element) external pure returns (bytes32);
```

## Structs
### Environment

```solidity
struct Environment {
    Router router;
    IPermit2 permit2;
    TheCompact compact;
    DebugEmissary emissary;
    AlwaysOKAllocator alwaysOKAllocator;
    MockSimpleAccount eoa7702;
    IntentExecutor intentExecutor;
    MultiCallAdapter multicallAdapter;
    TestAllocator allocator;
    uint96 allocatorId;
    Account atomicFillSigner;
    Account orchestrator;
    Account eoa;
    Account solver;
    Scope scope;
    ResetPeriod resetPeriod;
    AccountInstance smartAccount1;
    AccountInstance smartAccount2;
    OwnableValidator validator;
    uint8 emissaryId;
    bytes12 lockTag;
    MockTarget target;
    Token token1;
    Token token2;
    Token token3;
    MockTokenReturnsFalse badToken1;
    MockTokenAlwaysReverts badToken2;
    MockTokenWithFees badToken3;
    WETH weth;
    SameChainAdapter sameChainAdapter;
}
```

### Chains

```solidity
struct Chains {
    uint256 originChain1;
    uint256 originChain2;
    uint256 targetChain;
}
```

### Intent

```solidity
struct Intent {
    Execution[] preClaimExecution;
    Execution[] targetExecutions;
    Execution[] noExec;
    uint256[2][] tokenIn;
    uint256[2][] tokenOut;
    MultichainCompact compact;
    bytes32 digest;
    bytes32 claimHash;
    bytes32[] elementHashes;
    bytes userEmissarySig;
}
```

