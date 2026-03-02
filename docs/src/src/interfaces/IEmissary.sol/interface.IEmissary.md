# IEmissary
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IEmissary.sol)


## Functions
### verifyClaim


```solidity
function verifyClaim(
    address sponsor, // the sponsor of the claim
    bytes32 digest,
    bytes32 claimHash, // The message hash representing the claim.
    bytes calldata signature,
    bytes12 lockTag
)
    external
    view
    returns (bytes4);
```

## Errors
### InvalidNonce

```solidity
error InvalidNonce()
```

## Structs
### EmissaryConfig

```solidity
struct EmissaryConfig {
    uint8 configId;
    address allocator;
    Scope scope;
    ResetPeriod resetPeriod;
    IStatelessValidator validator;
    bytes validatorConfig;
}
```

### EmissaryEnable

```solidity
struct EmissaryEnable {
    bytes allocatorSig;
    bytes userSig;
    uint256 expires;
    uint256 nonce;
    uint256[] allChainIds;
    uint256 chainIndex;
}
```

