# EIP712Hash
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/emissary/lib/EmissaryEIP712Lib.sol)


## Functions
### config


```solidity
function config(
    address sponsor,
    IStatelessValidator validator,
    uint8 configId,
    uint256 expires,
    bytes12 lockTag,
    uint256 nonce,
    bytes calldata validatorConfig,
    uint256[] calldata chainIds
)
    internal
    pure
    returns (bytes32 hash);
```

## Errors
### InvalidSignature

```solidity
error InvalidSignature()
```

