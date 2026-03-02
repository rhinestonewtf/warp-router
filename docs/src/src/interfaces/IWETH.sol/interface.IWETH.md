# IWETH
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IWETH.sol)


## Functions
### withdraw

Burn Wrapped Ether and receive native Ether.


```solidity
function withdraw(uint256 wad) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`wad`|`uint256`|Amount of WETH to unwrap and send to caller.|


### deposit

Lock native Ether and mint Wrapped Ether ERC20

msg.value is amount of Wrapped Ether to mint/Ether to lock.


```solidity
function deposit() external payable;
```

### balanceOf

Get balance of WETH held by `guy`.


```solidity
function balanceOf(address guy) external view returns (uint256 wad);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guy`|`address`|Address to get balance of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`wad`|`uint256`|Amount of WETH held by `guy`.|


### transfer

Transfer `wad` of WETH from caller to `guy`.


```solidity
function transfer(address guy, uint256 wad) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guy`|`address`|Address to send WETH to.|
|`wad`|`uint256`|Amount of WETH to send.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|ok True if transfer succeeded.|


