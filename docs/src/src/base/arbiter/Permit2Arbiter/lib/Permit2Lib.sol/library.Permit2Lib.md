# Permit2Lib
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/base/arbiter/Permit2Arbiter/lib/Permit2Lib.sol)

Utility library providing helper functions for Permit2 protocol integration within the Router ecosystem

This library serves as a critical bridge between the Router's internal order representation and the
external Permit2 protocol requirements. It handles two primary responsibilities:
1. **Data Structure Conversion**: Transforms Router's compact token representation (ID/amount pairs)
into Permit2's expected TokenPermissions and SignatureTransferDetails structures. This conversion
is essential because Router uses packed token IDs for gas optimization, while Permit2 requires
explicit token addresses.
2. **EIP-712 Typestring Management**: Provides the complex typestring constant required for witness-based
signature validation in cross-chain operations. This typestring defines the structure of mandate
data that serves as additional validation context for signature verification.
Integration with Router Ecosystem**:
- Used by Permit2Arbiter to process signature-based token unlocking operations
- Enables cross-chain arbiters to validate and execute token transfers using cryptographic signatures
- Bridges Router's gas-optimized data structures with Permit2's standardized interface
- Supports witness-based transfers where mandate hashes provide additional validation context
Permit2 Protocol Context**:
Permit2 is Uniswap's signature-based token approval system that eliminates the need for separate
approval transactions. Users can grant spending permissions through EIP-712 signatures, enabling
more efficient and user-friendly token transfers. The witness mechanism allows additional data
(like mandate hashes) to be included in the signature validation process.
Security Considerations**:
- Token ID to address conversion uses proven IdLib implementation from the-compact
- Witness typestring must match exactly between signer and verifier for security
- All conversions maintain 1:1 correspondence between input and output arrays

**Notes:**
- security: Critical utility for signature validation - witness typestring must remain consistent

- gas: Optimized for batch operations to minimize gas costs in multi-token scenarios


## State Variables
### WITNESS_TYPESTRING
Enables efficient token ID to address conversion using the-compact's battle-tested implementation

EIP-712 typestring defining the structure for witness-based signature validation in cross-chain operations

This using statement provides access to IdLib.toAddress() function which converts packed token IDs
back to standard Ethereum addresses. The conversion is deterministic and gas-optimized, using bitwise
operations to extract the address from the packed uint256 representation used throughout Router.

This complex typestring is critical for Permit2's witness-based transfer mechanism, which allows additional
data (the mandate hash) to be included in signature validation. The typestring defines the exact structure
that must be used when creating and verifying EIP-712 signatures for cross-chain token transfers.
Typestring Breakdown**:
The typestring defines nested structures used in cross-chain mandate validation:
- `Mandate`: The root structure containing target details, operations, and validation data
- `target`: Target chain and recipient information for cross-chain operations
- `originOps`: Array of operations to be executed on the origin chain
- `destOps`: Array of operations to be executed on the destination chain
- `q`: Validation hash (typically a commitment or proof)
- `Op`: Individual operation structure for cross-chain execution
- `to`: Target contract address for the operation
- `value`: ETH value to send with the operation
- `data`: Encoded function call data for the operation
- `Target`: Destination chain configuration for cross-chain settlement
- `recipient`: Address to receive tokens on the destination chain
- `tokenOut`: Array of tokens and amounts expected on destination
- `targetChain`: Chain ID of the destination network
- `fillExpiry`: Deadline for completing the cross-chain settlement
- `Token`: Token specification for cross-chain transfers
- `token`: ERC20 token contract address
- `amount`: Amount of tokens to transfer
- `TokenPermissions`: Permit2's standard token permission structure
- `token`: ERC20 token contract address for permissions
- `amount`: Maximum amount that can be transferred
Security Importance**:
This typestring must match exactly between signature creation and verification. Any deviation
will cause signature validation to fail, preventing unauthorized token transfers. The structure
ensures that cross-chain mandates are cryptographically bound to specific token permissions,
origin/destination operations, and settlement parameters.
Cross-Chain Integration**:
When users sign permits for cross-chain operations, the mandate hash (derived from this structure)
serves as a witness that proves the token transfer is part of a legitimate cross-chain settlement.
This prevents isolated token transfers and ensures all operations are part of validated cross-chain flows.

**Notes:**
- security: CRITICAL - This typestring must never change as it would invalidate all existing signatures

- gas: The typestring is stored as a constant to minimize gas costs during signature verification


```solidity
string internal constant WITNESS_TYPESTRING =
// solhint-disable-next-line max-line-length
"Mandate mandate)Mandate(Target target,uint8 v,uint128 minGas,Op[] originOps,Op[] destOps,bytes32 q)Op(address to,uint256 value,bytes data)Target(address recipient,Token[] tokenOut,uint256 targetChain,uint256 fillExpiry)Token(address token,uint256 amount)TokenPermissions(address token,uint256 amount)"
```


## Functions
### toTokenPermissions

Converts Router's compact token representation into Permit2-compatible permission structures

This function serves as the core data transformation utility that bridges Router's gas-optimized
token representation with Permit2's standardized interface requirements. It performs a dual conversion:
1. **Token ID to Address Conversion**: Transforms packed uint256 token IDs (used throughout Router
for gas optimization) back into standard Ethereum addresses using IdLib's deterministic conversion.
2. **Structure Mapping**: Creates parallel arrays of TokenPermissions and SignatureTransferDetails
that match Permit2's expected interface for batch token transfers.
Algorithm Overview**:
For each [tokenId, amount] pair in the input array:
- Extract the token address from the packed ID using IdLib.toAddress()
- Create a TokenPermissions struct with the extracted address and amount
- Create a SignatureTransferDetails struct specifying the recipient and requested amount
- Both structs use the same amount, ensuring consistency in permission and transfer details
Data Flow Integration**:
This function is typically called by Permit2Arbiter when processing cross-chain orders:
1. Cross-chain order contains tokenIn array with [id, amount] pairs
2. This function converts the data into Permit2-compatible structures
3. Permit2Arbiter uses the output to construct PermitBatchTransferFrom
4. The permit is then used for signature-based token transfers via Permit2
Gas Optimization Design**:
- Uses calldata arrays for input to minimize memory allocation costs
- Pre-allocates output arrays to exact size to avoid dynamic resizing
- Unchecked loop iteration for gas savings (overflow impossible with practical token counts)
- Reuses the same amount value for both permission and transfer structures

**Notes:**
- security: Input validation relies on IdLib.toAddress() for safe token ID conversion

- gas: Optimized for batch operations - O(n) complexity with minimal memory allocations


```solidity
function toTokenPermissions(uint256[2][] calldata idsAndAmounts, address permit2Recipient)
    internal
    pure
    returns (
        ISignatureTransfer.TokenPermissions[] memory tokenPermissions,
        ISignatureTransfer.SignatureTransferDetails[] memory signatureTransferDetails
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`idsAndAmounts`|`uint256[2][]`|Array of [tokenId, amount] pairs where tokenId is Router's packed token representation and amount is the quantity of tokens to be transferred. The tokenId uses Router's gas-optimized format where token addresses are packed into uint256 values.|
|`permit2Recipient`|`address`|The address that will receive the transferred tokens. This is typically the depositor address in cross-chain settlements or the settlement contract itself, depending on the specific arbitration flow being executed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenPermissions`|`ISignatureTransfer.TokenPermissions[]`|Array of Permit2 TokenPermissions structures containing the extracted token addresses and amounts. These define what tokens the signature authorizes for transfer.|
|`signatureTransferDetails`|`ISignatureTransfer.SignatureTransferDetails[]`|Array of Permit2 SignatureTransferDetails structures specifying the recipient and requested amounts for each token transfer. These define where the tokens should be sent and how much should be transferred.|


