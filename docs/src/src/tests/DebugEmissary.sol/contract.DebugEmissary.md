# DebugEmissary
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/tests/DebugEmissary.sol)

**Inherits:**
[Emissary](/Users/ops/work/rhinestone/compact-utils/docs/src/src/emissary/Emissary.sol/contract.Emissary.md), [ISmartSessionEmissary](/Users/ops/work/rhinestone/compact-utils/docs/src/src/interfaces/ISmartSessionEmissary.sol/interface.ISmartSessionEmissary.md)


## State Variables
### passOverrite

```solidity
bool passOverrite
```


## Functions
### constructor


```solidity
constructor(address compact) Emissary(compact);
```

### mock_setConfig


```solidity
function mock_setConfig(address sponsor, uint8 id, bytes12 lockTag, IStatelessValidator validator, bytes calldata data) external;
```

### _config


```solidity
function _config(address sponsor, uint8 id, bytes12 lockTag, IStatelessValidator validator) external view returns (bytes memory);
```

### setupPasskeyConfig

Helper to setup passkey config for testing


```solidity
function setupPasskeyConfig(address account, bytes12 lockTag, uint256 pubKeyX, uint256 pubKeyY, bool requireUV, bool usePrecompile)
    external;
```

### getHash


```solidity
function getHash(address account, bytes12 lockTag, uint256 expires, EmissaryConfig calldata config, EmissaryEnable calldata enableData)
    external
    view
    returns (bytes32);
```

### verifyClaim


```solidity
function verifyClaim(address sponsor, bytes32 digest, bytes32 claimHash, bytes calldata emissaryData, bytes12 lockTag)
    external
    view
    virtual
    override
    returns (bytes4);
```

### _compactDomainSeparator


```solidity
function _compactDomainSeparator() internal view virtual override returns (bytes32);
```

### overwrite


```solidity
function overwrite(bool ovr) external;
```

### verifyExecution


```solidity
function verifyExecution(address account, bytes32 digest, bytes calldata data, Execution[] calldata executions, bytes12 lockTag)
    external
    override
    returns (bytes4);
```

