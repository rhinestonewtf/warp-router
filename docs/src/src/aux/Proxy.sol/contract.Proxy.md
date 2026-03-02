# Proxy
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/aux/Proxy.sol)

**Inherits:**
UpgradeableBeacon


## Functions
### constructor


```solidity
constructor(address initialOwner, address initialImpl) UpgradeableBeacon(initialOwner, initialImpl);
```

### _delegate

Delegates the current call to `implementation`.
This function does not return to its internal call site, it will return directly to the external caller.


```solidity
function _delegate(address implementation) internal virtual;
```

### _fallback

Delegates the current call to the address returned by `_implementation()`.
This function does not return to its internal call site, it will return directly to the external caller.


```solidity
function _fallback() internal virtual;
```

### fallback

Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
function in the contract matches the call data.


```solidity
fallback() external payable virtual;
```

