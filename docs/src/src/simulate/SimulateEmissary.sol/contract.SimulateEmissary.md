# SimulateEmissary
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/simulate/SimulateEmissary.sol)

**Inherits:**
[Emissary](/Users/ops/work/rhinestone/compact-utils/docs/src/src/emissary/Emissary.sol/contract.Emissary.md)


## State Variables
### foo

```solidity
bytes32 public constant foo = keccak256("SimulateEmissary")
```


## Functions
### constructor


```solidity
constructor(address compact) Emissary(compact);
```

### verifyClaim


```solidity
function verifyClaim(
    address sponsor,
    bytes32 digest,
    bytes32, /* claimHash*/
    bytes calldata emissaryData,
    bytes12 lockTag
)
    external
    view
    virtual
    override
    returns (bytes4);
```

