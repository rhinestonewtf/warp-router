# CompactEIP712
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/types/EIP712.sol)

Simple struct definitions without boilerplate ABI functions


## Structs
### MultichainCompact

```solidity
struct MultichainCompact {
    address sponsor;
    uint256 nonce;
    uint256 expires;
    Element[] elements;
}
```

### Element

```solidity
struct Element {
    address arbiter;
    uint256 chainId;
    Lock[] commitments;
    Mandate mandate;
}
```

### Lock

```solidity
struct Lock {
    bytes12 lockTag; // A tag representing the allocator, reset period, and scope.
    address token; // The locked token, or address(0) for native tokens.
    uint256 amount; // The maximum committed amount of tokens.
}
```

### Token

```solidity
struct Token {
    address token;
    uint256 amount;
}
```

### Mandate

```solidity
struct Mandate {
    Target target;
    uint8 v;
    uint128 minGas;
    Op[] originOps;
    Op[] destOps;
    bytes32 q;
}
```

### Target

```solidity
struct Target {
    address recipient;
    Token[] tokenOut;
    uint256 targetChain;
    uint256 fillExpiry;
}
```

### Op

```solidity
struct Op {
    address to;
    uint256 value;
    bytes data;
}
```

