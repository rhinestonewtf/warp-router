# MockSimpleAccount
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockSimpleAccount.sol)

**Inherits:**
Ownable


## Functions
### constructor


```solidity
constructor(address _owner) ;
```

### execute


```solidity
function execute(Execution[] calldata executions, bytes calldata /* signature */) external;
```

### executeOne


```solidity
function executeOne(address target, bytes calldata callData, bytes calldata sig) external;
```

### executeFromExecutor


```solidity
function executeFromExecutor(
    bytes32,
    /* executionHash */
    bytes calldata executionCalldata
)
    external;
```

### isValidSignature


```solidity
function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
```

