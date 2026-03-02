# FeeCollector
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/utils/FeeCollector.sol)

Contract for collecting fees from relayers during fill operations

Fees are collected by relayers on fills and are expected to be priced into
the user's intent pricing if fees are user-facing. This contract provides
the core functionality for distributing fees to multiple recipients.


## Functions
### _collectFee

Collects fees from the sender and distributes them to specified recipients

Transfers tokens from msg.sender to multiple recipients as specified in the fee structure.
Relayers are expected to have already received tokens from users and this function
distributes the fee portion to the intended recipients.


```solidity
function _collectFee(Fee calldata fee) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`Fee`|The fee structure containing token address and recipient/amount pairs|


### _collectFee

Collects fees with separated parameters (for direct calldata manipulation)


```solidity
function _collectFee(address recipient, uint256[2][] calldata tokenAndAmounts) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address to receive the fees|
|`tokenAndAmounts`|`uint256[2][]`|Array of [token, amount] pairs for fee distribution|


### _collectFee


```solidity
function _collectFee(Fee[] calldata fees) internal virtual;
```

## Structs
### Fee
Structure representing a fee collection with token and recipient details


```solidity
struct Fee {
    address recipient;
    uint256[2][] tokenAndAmounts;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`||
|`tokenAndAmounts`|`uint256[2][]`||

