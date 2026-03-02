# MockTarget
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockTarget.sol)


## State Variables
### value

```solidity
uint256 public value
```


### param

```solidity
uint256 public param
```


## Functions
### targetFn


```solidity
function targetFn(uint256 _param) external payable;
```

### deposit


```solidity
function deposit(IERC20 token, uint256 amount) external;
```

### reverting


```solidity
function reverting() external pure;
```

### getAddress


```solidity
function getAddress() external view returns (address);
```

### getBool


```solidity
function getBool() external view returns (bool);
```

### getBytes32


```solidity
function getBytes32() external pure returns (bytes32);
```

### getString


```solidity
function getString() external pure returns (string memory);
```

### getArray


```solidity
function getArray() external view returns (uint256[] memory);
```

### getTuple


```solidity
function getTuple() external view returns (uint256, address, bool);
```

### getBytes


```solidity
function getBytes() external pure returns (bytes memory);
```

## Events
### TargetCalled

```solidity
event TargetCalled(uint256 value, uint256 param)
```

### BalanceOf

```solidity
event BalanceOf(address account, uint256 balance)
```

