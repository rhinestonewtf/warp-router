# IRouterManager
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/interfaces/IRouterManager.sol)

**Inherits:**
IAccessControl


## Functions
### initialized


```solidity
function initialized() external view returns (bool);
```

### $atomicFillSigner


```solidity
function $atomicFillSigner() external view returns (address);
```

### initialize


```solidity
function initialize(address atomicSigner, address addAdmin, address rmAdmin) external;
```

### pauseRouter


```solidity
function pauseRouter() external;
```

### installFillAdapter


```solidity
function installFillAdapter(bytes2 version, bytes4 selector, address adapter) external;
```

### hotfixFillAdapter


```solidity
function hotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external;
```

### installClaimAdapter


```solidity
function installClaimAdapter(bytes2 version, bytes4 selector, address adapter) external;
```

### hotfixClaimAdapter


```solidity
function hotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external;
```

### getFillAdapter


```solidity
function getFillAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);
```

### getClaimAdapter


```solidity
function getClaimAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);
```

### retireFillAdapter


```solidity
function retireFillAdapter(bytes2 version, bytes4 selector) external;
```

### retireClaimAdapter


```solidity
function retireClaimAdapter(bytes2 version, bytes4 selector) external;
```

## Events
### FillAdapter

```solidity
event FillAdapter(bytes2 protocolVersion, address adapter, bytes4 selector, bytes12 adapterTag)
```

### ClaimAdapter

```solidity
event ClaimAdapter(bytes2 protocolVersion, address adapter, bytes4 selector, bytes12 adapterTag)
```

### FillAdapterRetired

```solidity
event FillAdapterRetired(bytes2 protocolVersion, bytes4 selector, address adapter)
```

### ClaimAdapterRetired

```solidity
event ClaimAdapterRetired(bytes2 protocolVersion, bytes4 selector, address adapter)
```

### SetApproval

```solidity
event SetApproval(address spender, address token)
```

### FillSignerSet

```solidity
event FillSignerSet(address signer)
```

## Errors
### AdapterAlreadyInstalled

```solidity
error AdapterAlreadyInstalled()
```

### AdapterNotInstalled

```solidity
error AdapterNotInstalled()
```

### OnlyPatchAllowed

```solidity
error OnlyPatchAllowed()
```

### InvalidAdapter

```solidity
error InvalidAdapter()
```

### InvalidArbiter

```solidity
error InvalidArbiter()
```

### Unauthorized

```solidity
error Unauthorized()
```

### AdapterMajorVersionMismatch

```solidity
error AdapterMajorVersionMismatch()
```

### SettingApprovalsNotSupported

```solidity
error SettingApprovalsNotSupported(IAdapter adapter)
```

## Structs
### TokenAndAmount

```solidity
struct TokenAndAmount {
    address token;
    uint256 amount;
}
```

