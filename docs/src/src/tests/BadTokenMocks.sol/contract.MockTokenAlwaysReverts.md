# MockTokenAlwaysReverts
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/BadTokenMocks.sol)

Mock ERC20 token that always reverts on transfer

Useful for testing handling of tokens that revert on transfer attempts


## State Variables
### balanceOf

```solidity
mapping(address => uint256) public balanceOf
```


### name

```solidity
string public name
```


### symbol

```solidity
string public symbol
```


### decimals

```solidity
uint8 public decimals
```


## Functions
### constructor


```solidity
constructor(string memory _name, string memory _symbol, uint8 _decimals) ;
```

### mint


```solidity
function mint(address to, uint256 amount) external;
```

### transfer


```solidity
function transfer(address, uint256) external pure;
```

### transferFrom


```solidity
function transferFrom(address, address, uint256) external pure;
```

### approve


```solidity
function approve(address, uint256) external pure;
```

