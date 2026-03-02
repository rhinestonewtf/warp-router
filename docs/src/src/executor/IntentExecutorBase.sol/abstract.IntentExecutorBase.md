# IntentExecutorBase
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/IntentExecutorBase.sol)

Base contract for intent executors with router access control

Provides core functionality for intent execution including router-only access control


## State Variables
### ROUTER
The router contract address authorized to call restricted functions


```solidity
address internal immutable ROUTER
```


### LOCKTAG
The tag used for resource locking during execution


```solidity
bytes12 public immutable LOCKTAG
```


## Functions
### constructor

Initializes the intent executor base with router and lock tag


```solidity
constructor(address router, address allocator) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The address of the authorized router contract|
|`allocator`|`address`||


### onlyRouter

Restricts function access to the designated router contract only

Prevents unauthorized cross-chain execution attempts by enforcing that only
the router can trigger intent execution functions


```solidity
modifier onlyRouter() ;
```

## Errors
### OnlyRouter
Thrown when a function is called by an unauthorized account


```solidity
error OnlyRouter()
```

