# MockERC20
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/MockERC20.sol)

**Inherits:**
ERC20


## Functions
### constructor


```solidity
constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals);
```

### increaseAllowance


```solidity
function increaseAllowance(address spender, uint256 addedValue) public;
```

### decreaseAllowance


```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) public;
```

