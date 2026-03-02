# TestHelperLib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/Environment.sol)


## Functions
### toOperation


```solidity
function toOperation(Execution[] memory executions, SmartExecutionLib.SigMode _mode)
    internal
    pure
    returns (Types.Operation memory ops);
```

### toOperation


```solidity
function toOperation(Execution[] memory executions, uint8 _mode) internal pure returns (Types.Operation memory ops);
```

### toOperationMulticall


```solidity
function toOperationMulticall(Execution[] memory executions) internal pure returns (Types.Operation memory ops);
```

### into


```solidity
function into(uint256[2] memory val) internal pure returns (uint256[2][] memory out);
```

### withoutIndex


```solidity
function withoutIndex(bytes32[] memory array, uint256 index) internal pure returns (uint256 _index, bytes32[] memory arrayOut);
```

