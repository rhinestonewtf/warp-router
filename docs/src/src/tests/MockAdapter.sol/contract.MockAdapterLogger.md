# MockAdapterLogger
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockAdapter.sol)


## State Variables
### fillExecuted

```solidity
mapping(bytes32 => bool) public fillExecuted
```


### claimExecuted

```solidity
mapping(bytes32 => bool) public claimExecuted
```


### lastrelayerContext

```solidity
bytes public lastrelayerContext
```


### lastTokenOut

```solidity
uint256[2][] public lastTokenOut
```


### lastPrefundFrom

```solidity
address public lastPrefundFrom
```


### lastPrefundTo

```solidity
address public lastPrefundTo
```


## Functions
### logFillExecuted


```solidity
function logFillExecuted(bytes32 nonce) external;
```

### logClaimExecuted


```solidity
function logClaimExecuted(bytes32 nonce) external;
```

### logrelayerContext


```solidity
function logrelayerContext(bytes calldata context) external;
```

### logTokenOut


```solidity
function logTokenOut(uint256[2][] calldata tokenOut) external;
```

### logPrefund


```solidity
function logPrefund(address from, address to) external;
```

### getLastTokenOut


```solidity
function getLastTokenOut() external view returns (uint256[2][] memory);
```

### resetState


```solidity
function resetState() external;
```

