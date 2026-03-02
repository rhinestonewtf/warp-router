# MulticallHandler
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/common/MulticallHandler.sol)

**Inherits:**
[MulticallCompanion](/Users/ops/work/rhinestone/compact-utils/docs/src/src/common/MulticallCompanion.sol/abstract.MulticallCompanion.md)


## State Variables
### WETH

```solidity
address internal immutable WETH
```


## Functions
### constructor


```solidity
constructor(address addressBook) ;
```

### _weth


```solidity
function _weth() internal view virtual override returns (address);
```

### handleTargetOpsMulticall


```solidity
function handleTargetOpsMulticall(Types.Operation calldata targetOps) external nonReentrant;
```

## Errors
### InvalidOperationType

```solidity
error InvalidOperationType()
```

