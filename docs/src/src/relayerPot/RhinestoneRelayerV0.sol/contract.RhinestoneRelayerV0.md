# RhinestoneRelayerV0
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/relayerPot/RhinestoneRelayerV0.sol)

**Inherits:**
[RhinestoneRelayerV1](/Users/ops/work/rhinestone/compact-utils/docs/src/src/relayerPot/RhinestoneRelayerV1.sol/contract.RhinestoneRelayerV1.md)


## State Variables
### RHINESTONE_V0

```solidity
address public immutable RHINESTONE_V0
```


## Functions
### constructor


```solidity
constructor(address _routerV0, address _routerV1, address _owner) RhinestoneRelayerV1(_routerV1, _owner);
```

### relayV0_ERC20_13732236

Executes calldata on the Rhinestone Spokepool (v0).

Doesn't allow using an ETH amount stored in the contract.


```solidity
function relayV0_ERC20_13732236() external payable onlyTrustedRelayer;
```

