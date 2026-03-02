# MockTokenWithFees
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/BadTokenMocks.sol)

Mock ERC20 token that charges a fee on transfers

Useful for testing handling of tokens with transfer fees (like USDT on some chains)


## State Variables
### balanceOf

```solidity
mapping(address => uint256) public balanceOf
```


### allowance

```solidity
mapping(address => mapping(address => uint256)) public allowance
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


### FEE_BASIS_POINTS

```solidity
uint256 public constant FEE_BASIS_POINTS = 100
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
function transfer(address to, uint256 amount) external returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```

### approve


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```

### _transfer


```solidity
function _transfer(address from, address to, uint256 amount) internal returns (bool);
```

