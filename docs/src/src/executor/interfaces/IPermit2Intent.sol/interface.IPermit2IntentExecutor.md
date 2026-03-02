# IPermit2IntentExecutor
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/executor/interfaces/IPermit2Intent.sol)

Interface for Permit2-based intent execution

Defines the contract interface for executing intents using Permit2 for gasless approvals


## Functions
### executePreClaimOpsWithPermit2Stub

Executes pre-claim operations using Permit2-based authorization

Validates Permit2 signature and executes operations before any cross-chain transfers


```solidity
function executePreClaimOpsWithPermit2Stub(
    address account,
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateStub calldata mandateStub,
    Types.Operation calldata preClaimOps,
    bytes calldata signature
)
    external
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The user account that signed the intent|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration|
|`mandateStub`|`EIP712Permit2MandateStub`|Mandate-specific parameters with operation and token hashes|
|`preClaimOps`|`Types.Operation`|Array of operations to execute on the origin chain|
|`signature`|`bytes`|EIP-712 signature from the account authorizing the operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed Permit2 hash used for signature validation|


### executeTargetOpsWithPermit2Stub

Executes target operations using Permit2-based authorization

Validates Permit2 signature and executes operations on the destination chain


```solidity
function executeTargetOpsWithPermit2Stub(
    address account,
    EIP712Permit2Stub calldata permit2Stub,
    EIP712Permit2MandateDestinationStub calldata mandateStub,
    Types.Operation calldata targetOps,
    bytes calldata signature
)
    external
    returns (bytes32 permit2Hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The user account that signed the intent|
|`permit2Stub`|`EIP712Permit2Stub`|Core Permit2 parameters including nonce and expiration|
|`mandateStub`|`EIP712Permit2MandateDestinationStub`|Mandate-specific parameters with operation and token hashes|
|`targetOps`|`Types.Operation`|Array of operations to execute on the destination chain|
|`signature`|`bytes`|EIP-712 signature from the account authorizing the operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`permit2Hash`|`bytes32`|The computed Permit2 hash used for signature validation|


### isPermit2IntentNonceConsumed

Checks if a nonce has been used for a specific account

Provides a way to check nonce usage for Permit2 intents


```solidity
function isPermit2IntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce value to check|
|`account`|`address`|The account address that owns the nonce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`used`|`bool`|True if the nonce has been consumed, false otherwise|


## Errors
### InvalidPermit2Signature
Thrown when Permit2 signature validation fails


```solidity
error InvalidPermit2Signature()
```

## Structs
### EIP712Permit2Stub
Core Permit2 parameters for intent execution

Contains essential Permit2 data for signature validation and replay protection


```solidity
struct EIP712Permit2Stub {
    /// @dev Nonce for replay protection
    uint256 nonce;
    /// @dev Expiration timestamp for the permit
    uint256 expires;
}
```

### EIP712Permit2MandateStub
Mandate-specific parameters for Permit2 intent execution

Contains hashed operation and token data for the intent mandate


```solidity
struct EIP712Permit2MandateStub {
    /// @dev Hash of input token details
    bytes32 tokenInHash;
    /// @dev Minimum gas required for execution of operations
    uint128 minGas;
    /// @dev Hash of target attributes (account, tokenOut, chain, expires)
    bytes32 targetAttributesHash;
    /// @dev Hash of destination operations to execute
    bytes32 destOpsHash;
    /// @dev Hash of qualifier data specific to this mandate
    bytes32 qHash;
}
```

### EIP712Permit2MandateDestinationStub

```solidity
struct EIP712Permit2MandateDestinationStub {
    address sponsor;
    address arbiter;
    uint256 notarizedChainId;
    bytes32 preClaimOpsHash;
    bytes32 targetAttributesHash;
    bytes32 tokenInHash;
    bytes32 tokenOutHash;
    uint256 fillExpires;
    bytes32 qHash;
}
```

