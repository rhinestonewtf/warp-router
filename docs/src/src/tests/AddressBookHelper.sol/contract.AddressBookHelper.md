# AddressBookHelper
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/AddressBookHelper.sol)

**Inherits:**
[Create2Factory](/Users/ops/work/rhinestone/compact-utils/docs/src/src/tests/AddressBookHelper.sol/contract.Create2Factory.md)


## State Variables
### vm

```solidity
Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))))
```


### $deploymentMap

```solidity
mapping(bytes32 nameHash => Deployment) $deploymentMap
```


### ADDRESSBOOK

```solidity
AddressBook ADDRESSBOOK = new AddressBook(address(this))
```


## Functions
### _getAddress


```solidity
function _getAddress(string memory name) internal view returns (address);
```

### _addDeployment


```solidity
function _addDeployment(string memory name, AddressBookLib.ID id, bytes memory bytecode, bytes memory args) internal returns (address);
```

### _addDeployment


```solidity
function _addDeployment(string memory name, AddressBookLib.ID id, bytes memory bytecode) internal returns (address);
```

### _deploymentId


```solidity
function _deploymentId(string memory name) internal view returns (bytes32);
```

### _registerAddress


```solidity
function _registerAddress(Deployment storage deployment) internal returns (address);
```

### _deploy


```solidity
function _deploy(string memory name) internal returns (address);
```

### _deploy


```solidity
function _deploy(Deployment storage deployment) internal returns (address addr);
```

## Structs
### InitCode

```solidity
struct InitCode {
    bytes bytecode;
    bytes args;
}
```

### Deployment

```solidity
struct Deployment {
    string name;
    AddressBookLib.ID id;
    address predictedAddress;
    InitCode code;
}
```

