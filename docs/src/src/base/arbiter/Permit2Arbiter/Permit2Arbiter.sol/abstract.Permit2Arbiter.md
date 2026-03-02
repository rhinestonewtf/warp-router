# Permit2Arbiter
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/arbiter/Permit2Arbiter/Permit2Arbiter.sol)

Abstract base contract providing Permit2 protocol integration for signature-based token transfers

This contract serves as the integration layer with Uniswap's Permit2 protocol, enabling arbiters
to execute token transfers using cryptographic signatures instead of traditional allowances.
Permit2 is a token approval management protocol that allows users to grant token spending permissions
through signatures rather than on-chain approvals. This provides better UX and gas efficiency by:
- Eliminating the need for separate approval transactions
- Enabling batch token transfers with single signature
- Providing fine-grained control over token permissions with nonces and deadlines
Integration with Router ecosystem:
- Processes token inputs from cross-chain orders using signature-based permissions
- Converts order token data into Permit2-compatible permission structures
- Handles witness-based transfers where mandate hashes serve as additional validation
- Enables seamless token unlocking as part of cross-chain settlement flows
The contract abstracts Permit2's complexity while providing standardized interfaces for
settlement-specific arbiters to execute secure, signature-authorized token transfers.
Security considerations:
- All transfers require valid signatures from token owners (sponsors)
- Mandate hashes provide additional witness-based validation for cross-chain operations
- Nonce and deadline parameters prevent replay attacks and ensure time-bounded permissions
- Permit2's battle-tested signature validation provides cryptographic security guarantees
Gas optimization notes:
- Batch operations automatically process multiple tokens in single transaction
- Immutable Permit2 interface minimizes storage costs
- Signature-based transfers eliminate separate approval gas costs

**Note:**
security: Signature validation relies on Permit2's implementation - ensure valid Permit2 address


## State Variables
### PERMIT2
Permit2 signature transfer interface for executing signature-based token transfers

This immutable interface provides access to Permit2's signature transfer functionality,
enabling secure token transfers through cryptographic signatures rather than allowances.
Used for all signature-based token unlocking operations in the arbiter system.


```solidity
ISignatureTransfer internal immutable PERMIT2
```


## Functions
### constructor

Initializes the Permit2Arbiter with Permit2 protocol integration

Sets up the immutable interface to Uniswap's Permit2 contract for signature-based
token transfers. This interface enables the arbiter to process token transfers using
cryptographic signatures instead of traditional token allowances.

**Note:**
security: The permit2 address cannot be changed after deployment - verify it matches
the official Permit2 deployment for the target network


```solidity
constructor(address permit2) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permit2`|`address`|The address of the Permit2 SignatureTransfer contract on the current network. Must be the canonical Permit2 deployment to ensure signature compatibility and security. The address is different on each network but maintains the same interface.|


### _unlockPermit2

Unlocks tokens using Permit2 signature-based transfers with mandate witness validation

Processes token inputs from a cross-chain order by converting them into Permit2-compatible
permission structures and executing signature-authorized transfers. The mandate hash serves
as a witness to provide additional validation that the transfer is part of a valid cross-chain
settlement operation.
The function performs the following operations:
1. Converts order token data (id/amount pairs) into Permit2 TokenPermissions
2. Creates SignatureTransferDetails specifying the depositor as recipient
3. Constructs a PermitBatchTransferFrom with order nonce and expiry
4. Executes permitWitnessTransferFrom with mandate hash as witness data
This enables secure token transfers where:
- The sponsor (token owner) has pre-signed permission for the transfer
- The mandate hash proves the transfer is part of a valid cross-chain order
- The depositor receives the tokens as specified in the settlement
- Nonce prevents replay attacks and expiry ensures time-bounded permissions

**Notes:**
- security: The signature must be from the order sponsor and include the mandate hash witness

- gas: Uses batch operations when multiple tokens are present for optimal gas efficiency


```solidity
function _unlockPermit2(Types.Order calldata order, bytes calldata sig, bytes32 mandateHash, address depositor) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`Types.Order`|The cross-chain order containing token inputs, sponsor, nonce, and expiry details. The tokenIn array contains [token_id, amount] pairs that get converted to token addresses.|
|`sig`|`bytes`|The signature from the order sponsor authorizing the Permit2 token transfer. Must be a valid EIP-712 signature over the permit data and mandate witness.|
|`mandateHash`|`bytes32`|The hash of the cross-chain mandate serving as witness data for additional validation. This proves the transfer is part of a legitimate cross-chain settlement operation.|
|`depositor`|`address`|The address that will receive the transferred tokens. Typically the settlement contract or final recipient depending on the settlement flow.|


