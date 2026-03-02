# Create2Factory
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/AddressBookHelper.sol)


## Functions
### deploy


```solidity
function deploy(bytes memory bytecode) public payable returns (address);
```

### deploy


```solidity
function deploy(bytes32 salt, bytes memory bytecode) public payable returns (address);
```

### deploy


```solidity
function deploy(bytes memory bytecode, bytes memory constructorArg) public payable returns (address);
```

### deploy


```solidity
function deploy(bytes32 salt, bytes memory bytecode, bytes memory constructorArg) public payable returns (address);
```

### predictDeploymentAddress


```solidity
function predictDeploymentAddress(bytes32 salt, bytes memory bytecode, bytes memory constructorArg) internal view returns (address);
```

### predictDeploymentAddress


```solidity
function predictDeploymentAddress(bytes32 salt, bytes memory bytecode) internal view returns (address);
```

### create2


```solidity
function create2(bytes32 salt, string memory name, bytes memory bytecode) public returns (address);
```

### create2


```solidity
function create2(bytes32 salt, string memory name, bytes memory bytecode, bytes memory args) public returns (address);
```

### predictCreate2


```solidity
function predictCreate2(bytes32 salt, bytes memory bytecode) public view returns (address);
```

### predictCreate2


```solidity
function predictCreate2(bytes32 salt, bytes memory bytecode, bytes memory args) public view returns (address);
```

## Events
### Deploying

```solidity
event Deploying(string name, address predictedAddress)
```

