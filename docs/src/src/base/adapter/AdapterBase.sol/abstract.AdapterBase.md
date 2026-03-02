# AdapterBase
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/adapter/AdapterBase.sol)

**Inherits:**
[IAdapter](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/IAdapter.sol/interface.IAdapter.md), [SemVer](/Users/ops/work/rhinestone/compact-utils/docs/src/src/common/semver/SemVer.sol/contract.SemVer.md)

Abstract base contract for settlement layer specific adapters in the Router ecosystem

This contract provides the foundational functionality that all settlement adapters must implement.
Adapters are delegate-called from the Router contract to handle cross-chain operations, token transfers,
and settlement logic for specific protocols or chains. Inheriting contracts must implement settlement-specific
logic while leveraging the common patterns provided here for security, token handling, and router integration.

CRITICAL SECURITY NOTICE:
- Adapters are ALWAYS executed via delegatecall from the Router contract
- The Router's storage and balance are accessible during adapter execution
- DO NOT implement direct calls to untrusted contracts from adapter functions
- All external calls to untrusted contracts could be detrimental to Router security
- Use only trusted, well-audited protocols and contracts in adapter implementations

IMPLEMENTATION REQUIREMENTS:
- All external functions that implement fill or claim logic MUST return their own function selector
- Return signature must be: returns(bytes4) with value of functionName.selector
- All claim/fill functions MUST be added to the IERC165 supportsInterface implementation
- Example: function myFillFunction() external returns(bytes4) { return this.myFillFunction.selector; }

ADAPTER IMPLEMENTATION GUIDE:
When creating a new adapter that inherits from AdapterBase, follow these critical guidelines:
1. FUNCTION SIGNATURE REQUIREMENTS:
- All fill/claim functions MUST return bytes4 (their own selector)
- Example: function myFill(...) external returns(bytes4) { ...; return this.myFill.selector; }
2. SECURITY REQUIREMENTS:
- NEVER make direct calls to untrusted external contracts
- Remember: adapters run in Router's context via delegatecall
- Any storage writes affect Router's storage, not adapter's storage
- Use only trusted, audited protocols (e.g., Uniswap, AAVE, Compound)
3. IERC165 IMPLEMENTATION:
- Override supportsInterface to include all your fill/claim function selectors
- Example:
function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
return interfaceId == this.myFill.selector ||
interfaceId == this.myClaim.selector ||
super.supportsInterface(interfaceId);
}
4. RELAYER CONTEXT:
- Use _loadRelayerContext() to retrieve relayer-provided data
- Define your own struct for the expected relayer context format
- Example: (uint contextLength, bytes calldata relayerCtx) = _loadRelayerContext();
MyRelayerData memory data = abi.decode(relayerCtx, (MyRelayerData));
5. TOKEN HANDLING:
- Use provided helpers: _prefundRecipient
- Handle both ERC20 and native ETH (Constants.NATIVE_TOKEN)


## State Variables
### _ROUTER
The Router contract address that this adapter is designed to work with

Used for security checks to ensure adapter functions are only called via delegatecall from the Router


```solidity
address public immutable _ROUTER
```


### ARBITER
The Arbiter contract address responsible for validating settlements

If no arbiter is provided during construction, defaults to address(this) for self-arbitration


```solidity
address public immutable ARBITER
```


## Functions
### constructor

Initializes the adapter with router and arbiter addresses

Sets up the fundamental addresses needed for adapter operation and security validation


```solidity
constructor(address router, address arbiter) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The Router contract address that will delegatecall into this adapter|
|`arbiter`|`address`|The Arbiter contract address for settlement validation, or address(0) for self-arbitration|


### onlyViaRouter

Ensures function is only called via delegatecall from the Router contract

Critical security modifier that prevents direct calls to adapter functions
When adapter functions are delegatecalled from Router, they execute in Router's context,
meaning they have access to Router's storage, balance, and permissions.
This modifier prevents malicious actors from calling adapter functions directly
which could bypass Router's security checks and access controls.


```solidity
modifier onlyViaRouter() ;
```

### _onlyRouterAdapter

Internal function to verify the adapter is being called via Router delegatecall

When delegatecalled from Router, address(this) equals _ROUTER due to delegatecall context
This prevents malicious direct calls to adapter functions that could bypass Router's security checks


```solidity
function _onlyRouterAdapter() internal view virtual;
```

### _prefundRecipient

Prefunds a recipient with multiple token outputs before settlement execution

Iterates through an array of token/amount pairs and transfers each to the recipient
This is typically used to provide liquidity to users before cross-chain settlement completes


```solidity
function _prefundRecipient(address from, address to, uint256[2][] calldata tokenOut) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address providing the tokens (usually the Router or a solver)|
|`to`|`address`|The recipient address that will receive the prefunded tokens|
|`tokenOut`|`uint256[2][]`|Array of [tokenAddress, amount] pairs encoded as uint256[2]|


### _prefundRecipient

Prefunds a recipient with a specific token and amount

Handles both native ETH and ERC20 token transfers with proper validation
For native tokens, validates that msg.value matches the expected amount


```solidity
function _prefundRecipient(address from, address to, address tokenOut, uint256 amountOut) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address providing the tokens|
|`to`|`address`|The recipient address|
|`tokenOut`|`address`|The token address (Constants.NATIVE_TOKEN for ETH)|
|`amountOut`|`uint256`|The amount to transfer|


### _loadRelayerContext

Extracts relayer-provided context data from the end of the calldata

The Router's `_callAdapterWithRelayerContext` function appends relayer context to adapter calls using:
`abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length))`
Resulting calldata format: [original_function_calldata][relayer_context_bytes][context_length_32_bytes]
This function efficiently extracts the relayer context without copying data by:
1. Reading the context length from the last 32 bytes of calldata
2. Calculating the offset where relayer context begins
3. Returning a calldata slice pointing to the relayer context
The relayer context contains settlement-layer-specific data that varies by adapter implementation.
Each adapter should `abi.decode(relayerContext, (SpecificStructType))` to parse their expected format.
Example usage in adapter implementations:
```solidity
(uint contextLength, bytes calldata relayerCtx) = _loadRelayerContext();
MySettlementData memory data = abi.decode(relayerCtx, (MySettlementData));
```


```solidity
function _loadRelayerContext() internal pure returns (uint256 contextLength, bytes calldata relayerContext);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`contextLength`|`uint256`|The length of the relayer context in bytes|
|`relayerContext`|`bytes`|The relayer context as a calldata slice ready for abi.decode by the adapter|


### supportsInterface


```solidity
function supportsInterface(bytes4 selector) public pure virtual returns (bool);
```

### settlementLayerSpender

Returns the address authorized to spend tokens for settlement

Adapters must override this function to specify the correct spender address


```solidity
function settlementLayerSpender() external view virtual returns (address tokenSpender);
```

### ADAPTER_TAG


```solidity
function ADAPTER_TAG() external pure virtual returns (bytes12 adapterTag);
```

## Events
### Filled
Emitted when a fill operation is successfully completed


```solidity
event Filled(uint256 nonce)
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The unique identifier for the filled order|

### Claimed
Emitted when a claim operation is successfully completed


```solidity
event Claimed(uint256 nonce)
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The unique identifier for the claimed order|

## Errors
### OnlyDelegateCall
Thrown when adapter functions are called directly instead of via Router delegatecall


```solidity
error OnlyDelegateCall()
```

### InvalidRelayerContext

```solidity
error InvalidRelayerContext()
```

