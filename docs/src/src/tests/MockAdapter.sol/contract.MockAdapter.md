# MockAdapter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockAdapter.sol)

**Inherits:**
[AdapterBase](/Users/ops/work/rhinestone/compact-utils/docs/src/src/base/adapter/AdapterBase.sol/abstract.AdapterBase.md)


## State Variables
### logger

```solidity
MockAdapterLogger public immutable logger
```


### mockArbiter

```solidity
MockArbiter internal mockArbiter
```


## Functions
### constructor


```solidity
constructor(address router, address arbiter) AdapterBase(router, address(0)) SemVer(0, 0);
```

### getMockArbiter


```solidity
function getMockArbiter() external view returns (address);
```

### mockFill


```solidity
function mockFill(bytes32 nonce, address recipient, uint256[2][] calldata tokenOut) external onlyViaRouter returns (bytes4);
```

### mockClaim


```solidity
function mockClaim(bytes32 nonce, address recipient, uint256[2][] calldata tokenOut) external onlyViaRouter returns (bytes4);
```

### mockPrefundRecipient


```solidity
function mockPrefundRecipient(address from, address to, uint256[2][] calldata tokenOut) external returns (bytes4);
```

### mockPrefundRecipientSingle


```solidity
function mockPrefundRecipientSingle(address from, address to, address tokenOut, uint256 amountOut) external payable returns (bytes4);
```

### mockLoadrelayerContext


```solidity
function mockLoadrelayerContext() external pure returns (bytes calldata);
```

### fillExecuted


```solidity
function fillExecuted(bytes32 nonce) external view returns (bool);
```

### claimExecuted


```solidity
function claimExecuted(bytes32 nonce) external view returns (bool);
```

### lastrelayerContext


```solidity
function lastrelayerContext() external view returns (bytes memory);
```

### getLastTokenOut


```solidity
function getLastTokenOut() external view returns (uint256[2][] memory);
```

### lastPrefundFrom


```solidity
function lastPrefundFrom() external view returns (address);
```

### lastPrefundTo


```solidity
function lastPrefundTo() external view returns (address);
```

### resetState


```solidity
function resetState() external;
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) public pure override returns (bool);
```

## Events
### MockFillCalled

```solidity
event MockFillCalled(bytes32 indexed nonce, address indexed recipient, uint256[2][] tokenOut)
```

### MockClaimCalled

```solidity
event MockClaimCalled(bytes32 indexed nonce, address indexed recipient, uint256[2][] tokenOut)
```

### MockPrefundCalled

```solidity
event MockPrefundCalled(address indexed from, address indexed to, uint256[2][] tokenOut)
```

### MockrelayerContextLoaded

```solidity
event MockrelayerContextLoaded(bytes context)
```

