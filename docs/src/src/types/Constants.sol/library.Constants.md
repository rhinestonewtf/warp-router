# Constants
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/types/Constants.sol)


## State Variables
### PERMIT2

```solidity
ISignatureTransfer internal constant PERMIT2 = ISignatureTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3))
```


### NO_EXEC

```solidity
bytes32 internal constant NO_EXEC = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
```


### NATIVE_TOKEN

```solidity
address internal constant NATIVE_TOKEN = address(0)
```


### DEFAULT_ADAPTER_TAG

```solidity
bytes12 internal constant DEFAULT_ADAPTER_TAG = bytes12(0)
```


### EMPTY_TOKEN_IN_HASH

```solidity
bytes32 internal constant EMPTY_TOKEN_IN_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
```


### EMPTY_TOKEN_OUT_HASH

```solidity
bytes32 internal constant EMPTY_TOKEN_OUT_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
```


### INTENT_EXECUTOR_ID

```solidity
AddressBookLib.ID internal constant INTENT_EXECUTOR_ID = AddressBookLib.ID.wrap(keccak256("IntentExecutor"))
```


### SAMECHAIN_ARBITER_ID

```solidity
AddressBookLib.ID internal constant SAMECHAIN_ARBITER_ID = AddressBookLib.ID.wrap(keccak256("SameChainArbiter"))
```


### WETH_ID

```solidity
AddressBookLib.ID internal constant WETH_ID = AddressBookLib.ID.wrap(keccak256("WETH"))
```


### MOCK_ADDRESS

```solidity
address internal constant MOCK_ADDRESS = address(bytes20(keccak256("Type.Mock.Address")))
```


### MOCK_UINT

```solidity
uint256 internal constant MOCK_UINT = uint256(keccak256("Type.Mock.Uint256"))
```


