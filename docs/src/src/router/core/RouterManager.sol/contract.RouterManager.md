# RouterManager
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/RouterManager.sol)

**Inherits:**
AccessControl, [IRouterManager](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/IRouterManager.sol/interface.IRouterManager.md), [InitializableWithProxyOwner](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/InitializableWithProxyOwner.sol/abstract.InitializableWithProxyOwner.md)

Advanced router management contract with semantic versioning support

This contract manages adapter installations, upgrades, and access control for a routing system.
It supports both fill and claim adapters with semantic version validation for safe upgrades.
Key features:
- Role-based access control for adapter management
- Semantic version validation for adapter upgrades
- Separate storage for fill and claim adapters
- Hotfix support with patch-only upgrade validation
- Atomic fill signer management with pause functionality


## State Variables
### ADD_ROLE
Role for adding new routes and setting the atomic fill signer.

Holders of this role can install new adapters, perform hotfixes, and pause the router


```solidity
bytes32 internal constant ADD_ROLE = bytes32(uint256(0x1001))
```


### RM_ROLE
Role for retiring existing routes.

Currently defined but not actively used in this contract version


```solidity
bytes32 internal constant RM_ROLE = bytes32(uint256(0x1002))
```


### PAUSE_ROLE
Role for pausing router

Currently defined but not actively used in this contract version


```solidity
bytes32 internal constant PAUSE_ROLE = bytes32(uint256(0x1003))
```


### $atomicFillSigner
The address of the signer authorized for atomic fills.

When set to address(0), atomic fills are effectively paused


```solidity
address public $atomicFillSigner
```


### initialized
Flag indicating whether the contract has been initialized (for proxy pattern)


```solidity
bool public initialized
```


## Functions
### constructor

Sets up the initial roles for the contract.


```solidity
constructor(address addAdmin, address rmAdmin) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addAdmin`|`address`|The address to be granted the ADD_ROLE.|
|`rmAdmin`|`address`|The address to be granted the RM_ROLE.|


### initialize

Initializes the contract when used with a proxy.

This function can only be called once.


```solidity
function initialize(address atomicSigner, address addAdmin, address rmAdmin) external onlyProxyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`atomicSigner`|`address`|The address to set as the atomic fill signer.|
|`addAdmin`|`address`|The address to be granted the ADD_ROLE.|
|`rmAdmin`|`address`|The address to be granted the RM_ROLE.|


### pauseRouter

Pauses atomic fills by setting the atomic fill signer to the zero address.

Only callable by an address with the ADD_ROLE.


```solidity
function pauseRouter() external onlyRole(ADD_ROLE);
```

### setAtomicFillSigner

Sets a new atomic fill signer address.

Only callable by an address with the ADD_ROLE.


```solidity
function setAtomicFillSigner(address newSigner) external onlyRole(ADD_ROLE);
```

### installFillAdapter

Installs a new fill adapter for a specific version and selector

Validates that no adapter is currently installed for this version/selector combination.
Performs adapter validation to ensure it implements the required interface.


```solidity
function installFillAdapter(bytes2 protocolVersion, bytes4 selector, address adapter) external onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolVersion`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the adapter contract to install Requirements: - Caller must have ADD_ROLE - No adapter must be currently installed for this version/selector - Adapter must have the same major version as the specified version parameter - Adapter must implement the required interface and pass validation|


### hotfixFillAdapter

Applies a hotfix to an existing fill adapter

Validates that an adapter exists and that the new version is only a patch upgrade.
This function enforces semantic versioning rules to ensure safe upgrades.


```solidity
function hotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract for the hotfix Requirements: - Caller must have ADD_ROLE - An adapter must already be installed for this version/selector - New adapter version must be only a patch upgrade (no major/minor changes) - New adapter must implement the required interface and pass validation|


### forceHotfixFillAdapter

Forces a hotfix to an existing fill adapter without semantic versioning restrictions

Similar to hotfixFillAdapter but bypasses the isOnlyPatch check, allowing major/minor version changes.
This function should be used with extreme caution as it can introduce breaking changes.

WARNING: This function bypasses semantic versioning validation and can introduce breaking changes


```solidity
function forceHotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract for the hotfix Requirements: - Caller must have ADD_ROLE - An adapter must already be installed for this version/selector - New adapter must implement the required interface and pass validation|


### installClaimAdapter

Installs a new claim adapter for a specific version and selector

Validates that no adapter is currently installed for this version/selector combination.
Performs adapter validation to ensure it implements the required interface.


```solidity
function installClaimAdapter(bytes2 version, bytes4 selector, address adapter) public onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the adapter contract to install Requirements: - Caller must have ADD_ROLE - No adapter must be currently installed for this version/selector - Adapter must have the same major version as the specified version parameter - Adapter must implement the required interface and pass validation|


### hotfixClaimAdapter

Applies a hotfix to an existing claim adapter

Validates that an adapter exists and that the new version is only a patch upgrade.
This function enforces semantic versioning rules to ensure safe upgrades.


```solidity
function hotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract for the hotfix Requirements: - Caller must have ADD_ROLE - An adapter must already be installed for this version/selector - New adapter version must be only a patch upgrade (no major/minor changes) - New adapter must implement the required interface and pass validation|


### forceHotfixClaimAdapter

Forces a hotfix to an existing claim adapter without semantic versioning restrictions

Similar to hotfixClaimAdapter but bypasses the isOnlyPatch check, allowing major/minor version changes.
This function should be used with extreme caution as it can introduce breaking changes.

WARNING: This function bypasses semantic versioning validation and can introduce breaking changes


```solidity
function forceHotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (6 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract for the hotfix Requirements: - Caller must have ADD_ROLE - An adapter must already be installed for this version/selector - New adapter must implement the required interface and pass validation|


### getFillAdapter

Retrieves the fill adapter configuration for a specific version and selector


```solidity
function getFillAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (2 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The address of the installed fill adapter (address(0) if none)|
|`adapterTag`|`bytes12`|The metadata tag associated with the adapter|


### getClaimAdapter

Retrieves the claim adapter configuration for a specific version and selector


```solidity
function getClaimAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (2 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The address of the installed claim adapter (address(0) if none)|
|`adapterTag`|`bytes12`|The metadata tag associated with the adapter|


### retireFillAdapter

Retires (removes) an existing fill adapter

Removes a previously installed fill adapter, making it unavailable for routing.
This action is irreversible for the specific version/selector combination.


```solidity
function retireFillAdapter(bytes2 version, bytes4 selector) external onlyRole(RM_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter to retire (2 bytes)|
|`selector`|`bytes4`|The function selector of the adapter to retire Requirements: - Caller must have RM_ROLE - An adapter must be installed for this version/selector combination|


### retireClaimAdapter

Retires (removes) an existing claim adapter

Removes a previously installed claim adapter, making it unavailable for routing.
This action is irreversible for the specific version/selector combination.


```solidity
function retireClaimAdapter(bytes2 version, bytes4 selector) external onlyRole(RM_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter to retire (2 bytes)|
|`selector`|`bytes4`|The function selector of the adapter to retire Requirements: - Caller must have RM_ROLE - An adapter must be installed for this version/selector combination|


### _installFillAdapter

Internal function to install or update a fill adapter and return the previous adapter

Core implementation for all fill adapter operations (install, hotfix, forceHotfix)


```solidity
function _installFillAdapter(bytes2 version, bytes4 selector, address adapter, bytes12 adapterTag)
    internal
    returns (address currentAdapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (2 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract|
|`adapterTag`|`bytes12`|Arbitrary metadata tag for the adapter (12 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentAdapter`|`address`|The address of the previously installed adapter (address(0) if none)|


### _installClaimAdapter

Internal function to install or update a claim adapter and return the previous adapter

Core implementation for all claim adapter operations (install, hotfix, forceHotfix)


```solidity
function _installClaimAdapter(bytes2 version, bytes4 selector, address adapter, bytes12 adapterTag)
    internal
    returns (address currentAdapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`version`|`bytes2`|The semantic version of the adapter (2 bytes)|
|`selector`|`bytes4`|The function selector that the adapter implements|
|`adapter`|`address`|The address of the new adapter contract|
|`adapterTag`|`bytes12`|Arbitrary metadata tag for the adapter (12 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentAdapter`|`address`|The address of the previously installed adapter (address(0) if none)|


### _requireAdapter

Internal function to validate that an adapter implements required interfaces

Performs two critical validations:
1. ERC165 interface support check for the given selector
2. Adapter contract validation via delegatecall to isAdapter()


```solidity
function _requireAdapter(bytes4 selector, address adapter) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector that the adapter must support|
|`adapter`|`address`|The address of the adapter contract to validate Requirements: - Adapter must support ERC165 interface for the given selector - Adapter must successfully respond to isAdapter() delegatecall - isAdapter() must return the correct function selector|


### setTokenApproval


```solidity
function setTokenApproval(address adapter, address token, uint256 amount) external onlyRole(ADD_ROLE);
```

