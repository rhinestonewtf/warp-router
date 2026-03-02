# SingleCaller
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/utils/Caller.sol)


## Functions
### singleCall

Executes a single call to a target address with provided calldata.

use fallback function instead.


```solidity
function singleCall(address, bytes calldata) external pure;
```

### fallback

Fallback function that extracts target address from calldata and forwards the call.

Uses assembly for gas efficiency. Expects calldata format: [target(20 bytes)][callData(...)]
The first 20 bytes of calldata are treated as the target address,
and the remaining bytes are forwarded as calldata to the target.
Reverts if the forwarded call fails.


```solidity
fallback() external payable;
```

## Errors
### UseFallbackInstead

```solidity
error UseFallbackInstead()
```

