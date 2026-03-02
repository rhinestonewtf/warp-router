# InitializableWithProxyOwner
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/InitializableWithProxyOwner.sol)


## Functions
### onlyProxyOwner

Modifier to restrict access to the proxy owner only

Reads the owner address from the upgradeable beacon owner slot.
This is used for proxy initialization to prevent unauthorized access.


```solidity
modifier onlyProxyOwner() ;
```

## Errors
### UnauthorizedInit

```solidity
error UnauthorizedInit()
```

