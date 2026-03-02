# TestAllocator
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/DebugAllocator.sol)

**Inherits:**
[RSAllocator](/Users/ops/work/rhinestone/compact-utils/docs/src/src/allocator/RSAllocator.sol/contract.RSAllocator.md)


## Functions
### constructor


```solidity
constructor(address compact, address _owner, address _signer) RSAllocator(compact, _owner, _signer);
```

### _compactDomainSeparator


```solidity
function _compactDomainSeparator() internal view virtual override returns (bytes32);
```

