# SimulateAllocator
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/simulate/SimulateAllocator.sol)

**Inherits:**
[RSAllocator](/Users/ops/work/rhinestone/compact-utils/docs/src/src/allocator/RSAllocator.sol/contract.RSAllocator.md)


## Functions
### constructor


```solidity
constructor(address compact, address _owner, address _signer) RSAllocator(compact, _owner, _signer);
```

### _authorizeClaim


```solidity
function _authorizeClaim(bytes32 claimHash, bytes calldata allocatorData) internal view virtual override returns (bool);
```

