# Router

[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/Router.sol)

**Inherits:**
[RouterLogic](/Users/ops/work/rhinestone/compact-utils/docs/src/src/router/core/RouterLogic.sol/contract.RouterLogic.md)

**Author:**
Rhinestone (zeroknots.eth, highskore.eth)

Main router contract for the Warp Routerr ecosystem, orchestrating cross-chain settlement operations
and protocol integrations through a flexible adapter architecture.

DEPLOYMENT OVERVIEW:
The Router contract serves as the primary entry point for all routing operations in the Rhinestone
ecosystem. It inherits all core functionality from RouterLogic while establishing a deterministic
storage layout for predictable deployment and integration patterns.
Storage Layout Management:**
This contract uses a custom storage layout position (layout at) to ensure deterministic state
management and enable advanced patterns like proxy-based upgrades or cross-chain deployment
consistency. The specific layout position ensures that state variables occupy predictable
storage slots across deployments.
Inherited Functionality:**
From RouterLogic:

- Fill and claim operation routing
- Adapter-based protocol integration
- Atomic signature validation
- Gas optimization features (adapter caching, special selectors)
- Reentrancy protection
- Native ETH handling
  From RouterManager (via RouterLogic):
- Dynamic adapter registration and removal
- Role-based access control for adapter management
- Protocol upgrade support
  From DirectRoutes (via RouterLogic):
- Special selector handling for common operations
- Direct call execution without adapter overhead
- Fee collection mechanisms

KEY FEATURES:

1. **Multi-Protocol Support**: Integrates Compact, Permit2, and cross-chain protocols via adapters
2. **Atomic Batch Execution**: Ensures all operations in a batch succeed or revert together
3. **Gas Optimizations**: Advanced caching and encoding techniques reduce operational costs
4. **Security**: Atomic fill signatures prevent unauthorized operation execution
5. **Flexibility**: Adapter pattern enables adding new protocols without contract upgrades

OPERATION TYPES:
Fill Operations**: Settlement operations that fulfill user orders by transferring assets
and executing target operations. Require atomic signature from authorized signer.
Claim Operations**: Resource unlock operations that claim user assets from protocols.
Can be executed without atomic signatures as they rely on protocol-level authorization.

**Notes:**

- security: All fill operations require valid signatures from the configured atomic signer

- gas: Implements multiple gas optimization techniques for batch operations

- upgradeable: Storage layout enables predictable state management for upgrade patterns

- layout: Custom storage position ensures deterministic deployment and integration patterns

## Functions

### constructor

Deploys the Router contract with essential security and management configuration.

Initializes the complete router infrastructure by delegating to RouterLogic constructor:
Atomic Fill Security:**
The atomicFillSigner is the sole address authorized to sign atomic batch fill operations.
This critical security measure prevents unauthorized solvers from executing user operations.
Setting this to address(0) effectively pauses all fill operations while preserving claim
functionality.
Role-Based Adapter Management:**
The adder and remover addresses receive ADAPTER_ADDER_ROLE and ADAPTER_REMOVER_ROLE
respectively, enabling controlled protocol integration and adapter lifecycle management
without requiring contract upgrades.
Storage Layout:\*\*
The custom layout position ensures that all state variables occupy deterministic storage
slots, enabling predictable integration patterns and potential upgrade mechanisms.

**Notes:**

- security: The atomicFillSigner is immutable after deployment and controls all fill security

- access: Adapter management roles can be transferred or revoked through RouterManager functions

- deployment: This constructor is called once during contract deployment and cannot be re-initialized

- considerations: Ensure all addresses are properly validated before deployment as they cannot be changed

```solidity
constructor(address atomicFillSigner, address adder, address remover) RouterLogic(atomicFillSigner, adder, remover);
```

**Parameters**

| Name               | Type      | Description                                                                                                                                                                                                                                                                            |
| ------------------ | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `atomicFillSigner` | `address` | The address authorized to sign atomic fill batch operations. Must be non-zero for fill operations to function. This address controls all user asset movements through fills and should be carefully secured. Consider using a hardware wallet or multi-sig for production deployments. |
| `adder`            | `address` | The address granted ADAPTER_ADDER_ROLE for registering new protocol adapters. Allows adding support for new protocols (e.g., new DEXs, bridges) without contract upgrades. This role should be assigned to a secure governance address.                                                |
| `remover`          | `address` | The address granted ADAPTER_REMOVER_ROLE for disabling problematic adapters. Provides an emergency mechanism to disable compromised or deprecated adapters. This role should be assigned to a secure operations or governance address.                                                 |
