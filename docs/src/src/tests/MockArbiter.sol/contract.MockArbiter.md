# MockArbiter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockArbiter.sol)

**Inherits:**
[ArbiterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/arbiter/ArbiterBase.sol/contract.ArbiterBase.md)


## Functions
### constructor


```solidity
constructor(address router, address compact, address addressBook) ArbiterBase(router, compact, addressBook);
```

### testCompactPreClaimOps


```solidity
function testCompactPreClaimOps(
    Types.Order calldata order,
    Types.Signatures calldata sigs,
    bytes32[] calldata otherElements,
    uint256 elementOffset,
    uint256 notarizedChainId,
    uint256 preClaimGasStipend
)
    external
    onlyRouter
    returns (bytes32);
```

### testPermit2PreClaimOps


```solidity
function testPermit2PreClaimOps(Types.Order calldata order, Types.Signatures calldata sigs, uint256 preClaimGasStipend)
    external
    onlyRouter
    returns (bytes32);
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) public pure override returns (bool);
```

