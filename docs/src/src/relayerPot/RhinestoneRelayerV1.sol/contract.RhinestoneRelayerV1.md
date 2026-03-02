# RhinestoneRelayerV1
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/relayerPot/RhinestoneRelayerV1.sol)

**Inherits:**
Ownable


## State Variables
### isRelayer
Mapping of trusted relayer addresses.


```solidity
mapping(address relayer => bool isTrusted) public isRelayer
```


### RHINESTONE_ROUTER
Address of the Warp Routerr


```solidity
address public immutable RHINESTONE_ROUTER
```


## Functions
### constructor

Initializes the contract with the relayer address and owner.


```solidity
constructor(address _router, address _owner) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_router`|`address`|The address of the Warp Routerr.|
|`_owner`|`address`|The address of the initial owner.|


### onlyTrustedRelayer

Modifier to check if the caller is a trusted relayer.


```solidity
modifier onlyTrustedRelayer() ;
```

### setRelayer

Sets the relayer address and trust status.

Only callable by the owner.


```solidity
function setRelayer(address relayer, bool isTrusted) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayer`|`address`|The address of the relayer to set.|
|`isTrusted`|`bool`|Whether the relayer is trusted.|


### setApprovals

Sets the approvals for a token to the Warp Routerr.


```solidity
function setApprovals(TokenAmount[] calldata tokenAmounts) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAmounts`|`TokenAmount[]`|The array of TokenAmount structs containing token addresses and amounts.|


### withdraw

Withdraws tokens from the contract to the owner's address.


```solidity
function withdraw(TokenAmount[] calldata tokenAmount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAmount`|`TokenAmount[]`|The array of TokenAmount structs containing token addresses and amounts.|


### withdraw

Withdraws tokens from the contract to the owner's address.


```solidity
function withdraw(address recipient, TokenAmount[] calldata tokenAmount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|a custom recipient to which the pot can rebalance to|
|`tokenAmount`|`TokenAmount[]`|The array of TokenAmount structs containing token addresses and amounts.|


### _withdraw


```solidity
function _withdraw(address recipient, TokenAmount[] calldata tokenAmount) internal;
```

### unwrapWETH

Unwraps WETH into ETH


```solidity
function unwrapWETH(address WETH, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`WETH`|`address`|address|
|`amount`|`uint256`|Amount of WETH to unwrap|


### wrapWETH

Wraps ETH into WETH using funds from the contract


```solidity
function wrapWETH(address WETH, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`WETH`|`address`|address|
|`amount`|`uint256`|Amount of ETH to wrap|


### relayERC202076776083

Executes calldata on the Warp Routerr.

Doesn't allow using an ETH amount stored in the contract.

Selector optimized to be 0x00000000


```solidity
function relayERC202076776083() external payable onlyTrustedRelayer;
```

### relayETH7172445

Executes calldata on the Warp Routerr.

Allows using an ETH amount stored in the contract along with the call by encoding an
amount in the 12 bytes after the function selector.
[0x00000096](4)[callvalue](12)[calldata]

Selector optimized to be 0x00000096


```solidity
function relayETH7172445() external payable onlyTrustedRelayer;
```

### receive

Fallback function to receive ETH.


```solidity
receive() external payable;
```

### _setApprovalForRouter

Sets approval for the Warp Routerr to spend tokens.


```solidity
function _setApprovalForRouter(TokenAmount[] calldata tokenAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAmount`|`TokenAmount[]`|The array of TokenAmount structs containing token addresses and amounts.|


## Events
### RelayerSet
Event emitted when a relayer is set


```solidity
event RelayerSet(address indexed relayer, bool isTrusted)
```

### Withdrawn
Event emitted when tokens are withdrawn


```solidity
event Withdrawn(address indexed token, uint256 amount)
```

### Approved
Event emitted when approvals are set for tokens


```solidity
event Approved(address indexed token, uint256 amount)
```

## Errors
### InvalidRelayerAddress
Used for executing token transfers and approvals

Error thrown when the relayer address is invalid


```solidity
error InvalidRelayerAddress()
```

### RelayerNotTrusted
Error thrown when the relayer is not trusted


```solidity
error RelayerNotTrusted()
```

### InvalidConstructorArg

```solidity
error InvalidConstructorArg()
```

### InvalidRecipient

```solidity
error InvalidRecipient()
```

