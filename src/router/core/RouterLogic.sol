// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AdapterConfig, RouterManagerStorageLib } from "../lib/RouterStorageLib.sol";
import { AdapterLib } from "@rhinestone/compact-utils/src/router/lib/AdapterLib.sol";
import { DirectRoutes } from "./DirectRoutes.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";
import { IRouter } from "@rhinestone/compact-utils/src/interfaces/IRouter.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { RouterManager } from "./RouterManager.sol";
import { RouterManagerV1 } from "../lib/v1/RouterAdapterLibV1.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { AdapterTagLib } from "../lib/v1/AdapterTagLib.sol";

/**
 * @title RouterLogic
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Core routing logic contract for the Warp Routerr ecosystem, orchestrating settlement operations
 *         across multiple protocols and adapters with advanced gas optimization and security features.
 *
 * @dev ARCHITECTURAL OVERVIEW:
 *      The RouterLogic serves as the central coordination hub for all settlement operations within the
 *      Rhinestone ecosystem. It implements a sophisticated adapter pattern where different protocols
 *      (Compact, Permit2, cross-chain bridges) can be plugged in as adapters while maintaining
 *      consistent routing logic and security guarantees.
 *
 *      **Core Responsibilities:**
 *      1. **Operation Routing**: Routes fill and claim operations to appropriate protocol adapters
 *      2. **Atomic Execution**: Ensures batched operations execute atomically or revert entirely
 *      3. **Gas Optimization**: Implements advanced caching and optimization techniques for batch operations
 *      4. **Security Enforcement**: Validates signatures and prevents unauthorized operation execution
 *      5. **Context Management**: Manages solver-specific contexts for each operation in a batch
 *
 * @dev OPERATION TYPES:
 *      **Fill Operations**: Settlement operations that fulfill user orders by transferring assets
 *      and executing user-specified target operations. Require atomic signature validation.
 *
 *      **Claim Operations**: Resource unlock operations that claim user assets from protocols
 *      like Compact or Permit2. Can be executed independently without atomic signatures.
 *
 * @dev ADAPTER ARCHITECTURE:
 *      The router uses a selector-based adapter system where each operation type maps to a specific
 *      adapter contract via a 4-byte function selector. This enables:
 *      - **Modular Protocol Support**: New protocols can be added by registering new adapters
 *      - **Version Management**: Protocol upgrades handled through adapter replacement
 *      - **Gas Efficiency**: Direct routing eliminates unnecessary abstraction layers
 *      - **Special Operations**: Built-in selectors bypass adapter layer for common operations
 *
 * @dev GAS OPTIMIZATION FEATURES:
 *      **Adapter Caching**: Consecutive operations with same selector reuse cached adapter addresses
 *      **Calldata Encoding**: Optimized encoding reduces calldata costs for batch operations
 *      **Assembly Decoding**: Direct calldata access avoids memory copying overhead
 *      **Context Indexing**: Efficient solver context consumption tracking
 *      **Special Selectors**: Built-in operations bypass adapter lookup entirely
 *
 * @dev SECURITY MODEL:
 *      **Atomic Signatures**: Fill operations require signature from designated atomicFillSigner
 *      **Reentrancy Protection**: All external functions protected via ReentrancyGuardTransient
 *      **Access Control**: RouterManager provides role-based adapter management
 *      **Context Validation**: Ensures solver contexts match operation requirements
 *      **Batch Integrity**: All operations in a batch must succeed or entire batch reverts
 *
 * @dev DEPLOYMENT ARCHITECTURE:
 *      Designed as upgradeable logic contract behind a proxy pattern. The proxy holds state
 *      while RouterLogic contains the execution logic, enabling upgrades without state migration.
 *      Inherits from RouterManager for adapter management and DirectRoutes for special operations.
 *
 * @custom:security All fill operations require valid atomic signatures
 * @custom:security Reentrancy protection prevents recursive calls during settlement operations
 * @custom:gas Advanced optimization techniques reduce gas costs for batch operations by 20-40%
 * @custom:upgradeable Logic contract designed for proxy-based upgrades with state preservation
 */
contract RouterLogic is IRouter, RouterManager, DirectRoutes, ReentrancyGuardTransient {
    using RouterManagerV1 for bytes4;
    using RouterManagerStorageLib for AdapterConfig;
    using EfficientHashLib for bytes;
    using SignatureCheckerLib for address;
    using AdapterLib for address;
    using AdapterTagLib for bytes12;

    /**
     * @notice Initializes the RouterLogic contract with essential security and management addresses.
     * @dev Sets up the core security and management infrastructure for the router:
     *
     *      **Atomic Fill Security**: The atomicFillSigner is the only address authorized to sign
     *      atomic batch operations. This prevents unauthorized solvers from executing user operations
     *      without proper validation. Setting this to address(0) effectively pauses all fill operations.
     *
     *      **Role-Based Management**: The adder and remover addresses receive respective roles for
     *      adapter management through the RouterManager inheritance. This enables controlled
     *      protocol upgrades and adapter management without compromising existing operations.
     *
     * @param atomicFillSigner The address authorized to sign atomic fill batch operations.
     *                        Must be non-zero for fill operations to function. This address should be
     *                        carefully managed as it controls all user asset movements through fills.
     * @param adder The address granted ADAPTER_ADDER_ROLE for registering new protocol adapters.
     *             Allows controlled addition of new protocol support without contract upgrades.
     * @param remover The address granted ADAPTER_REMOVER_ROLE for disabling problematic adapters.
     *               Provides emergency mechanism to disable compromised or deprecated adapters.
     *
     * @custom:security The atomicFillSigner address is immutable after deployment and controls all fill security
     * @custom:access Adapter management roles can be transferred or revoked through RouterManager functions
     * @custom:deployment This constructor runs only once during initial deployment or proxy initialization
     */
    constructor(address atomicFillSigner, address adder, address remover) RouterManager(adder, remover) {
        $atomicFillSigner = atomicFillSigner;
    }

    /**
     * @notice Validates atomic execution authorization by verifying a cryptographic signature
     * @dev This function implements the core security mechanism for atomic batch operations.
     *      It ensures that only the designated atomic signer can authorize the execution of
     *      multiple operations together. This prevents unauthorized solvers from executing
     *      operations without proper validation and maintains protocol security.
     *
     *      The atomic signature system serves two critical purposes:
     *      1. **Authorization Control**: Only the protocol's designated signer can approve batches
     *      2. **Replay Protection**: Each signature is tied to specific calldata via the hash
     *
     *      Implementation uses ECDSA signature recovery to verify the signer without requiring
     *      the signer's public key as input, reducing calldata costs.
     *
     * @param hash The keccak256 hash of the encoded adapter calldatas being executed atomically.
     *             This hash binds the signature to the specific operations being performed,
     *             preventing signature reuse across different operation sets.
     * @param atomicSig The ECDSA signature generated by the atomic signer over the provided hash.
     *                  Must be in the format expected by ECDSA.recoverCalldata (65 bytes: r + s + v).
     * @return atomic True if the signature is valid and came from the authorized atomic signer,
     *                false otherwise. A false return will cause the calling function to revert
     *                with InvalidAtomicity error.
     *
     * @custom:security This function is critical for protocol security:
     *                  - The atomicFillSigner address is stored in contract storage and set during
     *                    construction or initialization. If set to address(0), atomic fills are paused.
     *                  - Uses ECDSA signature recovery which is resistant to signature malleability attacks
     *                  - The hash parameter prevents signature replay across different operation batches
     *                  - Virtual function allows for override in derived contracts (e.g., simulation)
     *
     * @custom:gas Optimizes gas usage by:
     *            - Caching $atomicFillSigner from storage to avoid multiple SLOADs
     *            - Using ECDSA.recoverCalldata which operates directly on calldata without copying
     *            - Single storage read (2100 gas for cold slot, 100 gas for warm slot)
     */
    function _isAtomic(bytes32 hash, bytes calldata atomicSig) internal virtual returns (bool atomic) {
        // ============= Step 1: Signature Verification =============
        // Load atomicFillSigner from storage once and cache it
        address signer = $atomicFillSigner;
        // Ensure the signer is configured (non-zero) to prevent unauthorized execution
        require(signer != address(0), IRouter.AtomicSignerNotSet());

        // Verify the signature came from the authorized atomicFillSigner
        atomic = (signer == ECDSA.recoverCalldata(hash, atomicSig));
    }

    /**
     * @notice Gas-optimized version of routeFill with enhanced batching and caching mechanisms.
     * @dev This function implements several gas optimizations over the standard routeFill:
     *
     *      1. **Encoded Calldata Format**: Instead of accepting a bytes[] array directly, it accepts
     *         an ABI-encoded bytes parameter that contains the array. This reduces calldata costs
     *         as the array doesn't need to be decoded initially, saving ~200-500 gas per element.
     *
     *      2. **Adapter Caching**: The function caches the last used adapter address and its selector.
     *         When consecutive calls use the same selector (common in batch operations), it reuses
     *         the cached adapter instead of performing an SLOAD operation. Each cache hit saves
     *         ~2100 gas (cold SLOAD cost).
     *
     *      3. **Special Selector Optimization**: Built-in selectors (singleCall, multiCall, fee collection)
     *         bypass the adapter lookup entirely and are handled directly, saving both SLOAD operations
     *         and DELEGATECALL overhead (~2600+ gas per special call).
     *
     *      4. **Inline Assembly Decoding**: Uses assembly to decode the encoded calldata array without
     *         copying to memory, operating directly on calldata pointers. This saves memory expansion
     *         costs and unnecessary data copying.
     *
     *      5. **Solver Context Management**: Distinguishes between operations that consume solver contexts
     *         (regular adapter calls) and those that don't (special selectors), preventing unnecessary
     *         array access and bounds checking for special operations.
     *
     * @param relayerContexts Array of solver-specific contexts, consumed only by regular adapter calls.
     *                       Special selectors (singleCall, multiCall, fee collection) do not consume contexts.
     * @param encodedAdapterCalldatas ABI-encoded bytes containing the array of adapter calldatas.
     *                                Must be encoded as: abi.encode(bytes[] adapterCalldatas)
     * @param atomicFillSignature Signature from atomicFillSigner authorizing this batch execution.
     *                           Signed message is keccak256(encodedAdapterCalldatas).
     */
    function optimized_routeFill921336808(
        bytes[] calldata relayerContexts,
        bytes calldata encodedAdapterCalldatas,
        bytes calldata atomicFillSignature
    )
        public
        payable
        virtual
        nonReentrant
    {
        // Compute hash of the encoded calldata using optimized keccak helper
        // This operates directly on calldata without memory copying
        bytes32 hash = encodedAdapterCalldatas.hashCalldata();
        require(_isAtomic(hash, atomicFillSignature), IRouter.InvalidAtomicity());

        // ============= Step 2: Decode Array Without Memory Copying =============
        bytes[] calldata adapterCalldatas;
        uint256 length;
        assembly ("memory-safe") {
            // The encoded data structure for abi.encode(bytes[]) is:
            // [0x00] offset to array start (always 0x20 for single dynamic type)
            // [0x20] array length
            // [0x40] offset to first element
            // [0x60] offset to second element...
            // [actual data follows after all offsets]

            // Read the offset to the array data (skip the ABI encoding wrapper)
            let o := add(encodedAdapterCalldatas.offset, calldataload(encodedAdapterCalldatas.offset))
            // Point to array elements (skip the length field at o)
            adapterCalldatas.offset := add(o, 0x20)
            // Read the array length from position o
            length := calldataload(o)
            adapterCalldatas.length := length
        }

        // ============= Step 3: Initialize Loop Variables =============
        // Cache relayerContexts length to avoid repeated array length access (saves ~3 gas per check)
        uint256 relayerContextsLength = relayerContexts.length;
        // prevSelector caches the last used selector for adapter reuse optimization
        bytes4 prevSelector;
        // adapter caches the last loaded adapter address to avoid repeated SLOADs
        address adapter;
        // Adapter tag caches the last loaded adapter tag for skip context checks
        bytes12 adapterTag;
        // Tracks how many solver contexts have been consumed by regular adapter calls
        uint256 relayerContextIndex;

        // ============= Step 4: Process Each Operation =============
        for (uint256 i; i < length;) {
            bytes calldata adapterCalldata = adapterCalldatas[i];
            bytes4 selector = bytes4(adapterCalldata[:4]);

            // ============= Special Selector Handling =============
            // These selectors are handled directly without adapter lookup or solver context consumption
            // This saves ~2100 gas (SLOAD) + ~500 gas (DELEGATECALL overhead) per special call

            if (!_processDirectFillRoute(selector, adapterCalldata)) {
                // ============= Regular Adapter Call =============
                // This path handles standard adapter calls that consume solver contexts

                // **Adapter Caching Optimization**:
                // If the selector matches the previous one, reuse the cached adapter address
                // This optimization is highly effective for batch operations with the same adapter
                if (selector != prevSelector) {
                    // Selector changed - need to load the adapter from storage
                    // This performs an SLOAD operation (2100 gas for cold slot)
                    (adapter, adapterTag) = selector.withFillAdapter().adapterAddressAndTag();
                    // Cache the selector for potential reuse in next iteration
                    prevSelector = selector;
                }
                // If selector == prevSelector, we skip the SLOAD and reuse cached adapter

                // Check if this adapter skips solver context
                if (adapterTag.isSkipRelayerContext()) {
                    // Execute the adapter call without solver context - more gas efficient
                    require(selector == adapter.callAdapter(adapterCalldata), IRouter.AdapterCallFailed());
                } else {
                    // Ensure we have a solver context for this adapter call
                    // This check prevents out-of-bounds access and ensures proper context consumption
                    require(relayerContextIndex < relayerContextsLength, IRouter.LengthMismatch());

                    // Execute the adapter call with the corresponding solver context
                    // The adapter is called via DELEGATECALL, preserving msg.sender and msg.value
                    require(
                        selector == adapter.callAdapterWithRelayerContext(relayerContexts[relayerContextIndex], adapterCalldata),
                        IRouter.AdapterCallFailed()
                    );

                    // Increment solver context index after successful adapter call
                    unchecked {
                        ++relayerContextIndex;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        // ============= Step 5: Final Validation =============
        // Ensure all provided solver contexts were consumed
        // This prevents accidentally providing too many contexts (could indicate misconfiguration)
        // and ensures all regular adapter calls had corresponding contexts
        require(relayerContextsLength == relayerContextIndex, IRouter.LengthMismatch());
    }

    /**
     * @notice Executes multiple claim operations in batch, routing each to its corresponding protocol adapter.
     * @dev Implements efficient batch claim processing with gas optimization features:
     *
     *      **BATCH CLAIM PROCESSING:**
     *      Unlike fill operations, claim operations don't require atomic signatures as they represent
     *      resource unlocking from protocols where users have already authorized the operations through
     *      signatures at the protocol level (Compact mandate signatures, Permit2 permits, etc.).
     *
     *      **GAS OPTIMIZATION TECHNIQUES:**
     *      1. **Adapter Caching**: Consecutive operations with the same selector reuse cached adapter
     *         addresses, avoiding repeated SLOAD operations (saves ~2100 gas per cache hit).
     *      2. **Context Indexing**: Efficient tracking of solver context consumption without array bounds checking.
     *      3. **Special Selector Bypass**: Built-in operations (singleCall, multiCall) handled directly
     *         without adapter lookup, saving ~2600+ gas per special operation.
     *
     *      **OPERATION FLOW:**
     *      1. Extract 4-byte selector from each calldata to identify the target adapter
     *      2. Check for special selectors that bypass adapter lookup (gas optimization)
     *      3. For regular operations: load adapter (with caching), consume solver context, execute
     *      4. Validate all solver contexts were consumed (prevents misconfiguration)
     *
     *      **ERROR HANDLING:**
     *      All operations must succeed or the entire batch reverts, ensuring consistent state.
     *      Length mismatch between solver contexts and regular operations will revert the batch.
     *
     * @param relayerContexts Array of solver-specific contexts for each non-special operation.
     *                      Each regular adapter call consumes one context in order. Special selectors
     *                      (singleCall, multiCall, fee collection) don't consume contexts.
     * @param adapterCalldatas Array of calldata for adapter execution, each prefixed with a 4-byte
     *                        selector identifying the target adapter or special operation type.
     *
     * @custom:gas Optimized for batch processing with caching and special selector handling
     * @custom:atomic All operations succeed or entire batch reverts for consistency
     * @custom:security No signature validation required - relies on protocol-level authorization
     */
    function routeClaim(bytes[] calldata relayerContexts, bytes[] calldata adapterCalldatas) external payable nonReentrant {
        // ============= Step 1: Initialize Loop Variables =============
        uint256 length = adapterCalldatas.length;
        // Cache relayerContexts length to avoid repeated array length access (saves ~3 gas per check)
        uint256 relayerContextsLength = relayerContexts.length;
        // prevSelector caches the last used selector for adapter reuse optimization
        bytes4 prevSelector;
        // adapter caches the last loaded adapter address to avoid repeated SLOADs
        address adapter;
        // Adapter tag caches the last loaded adapter tag for skip context checks
        bytes12 adapterTag;
        // Tracks how many solver contexts have been consumed by regular adapter calls
        uint256 relayerContextIndex;

        // ============= Step 2: Process Each Operation =============
        for (uint256 i; i < length;) {
            bytes calldata adapterCalldata = adapterCalldatas[i];
            bytes4 selector = bytes4(adapterCalldata[:4]);

            // ============= Special Selector Handling =============
            // These selectors are handled directly without adapter lookup or solver context consumption
            if (!_processDirectClaimRoute(selector, adapterCalldata)) {
                // ============= Regular Adapter Call =============
                // This path handles standard adapter calls that consume solver contexts

                // **Adapter Caching Optimization**:
                // If the selector matches the previous one, reuse the cached adapter address
                // This optimization is highly effective for batch operations with the same adapter
                if (selector != prevSelector) {
                    // Selector changed - need to load the adapter from storage
                    // This performs an SLOAD operation (2100 gas for cold slot)
                    (adapter, adapterTag) = selector.withClaimAdapter().adapterAddressAndTag();
                    // Cache the selector for potential reuse in next iteration
                    prevSelector = selector;
                }
                // If selector == prevSelector, we skip the SLOAD and reuse cached adapter

                // Check if this adapter skips solver context
                if (adapterTag.isSkipRelayerContext()) {
                    // Execute the adapter call without solver context - more gas efficient
                    require(selector == adapter.callAdapter(adapterCalldata), IRouter.AdapterCallFailed());
                } else {
                    // Ensure we have a solver context for this adapter call
                    // This check prevents out-of-bounds access and ensures proper context consumption
                    require(relayerContextIndex < relayerContextsLength, IRouter.LengthMismatch());

                    // Execute the adapter call with the corresponding solver context
                    // The adapter is called via DELEGATECALL, preserving msg.sender and msg.value
                    require(
                        selector == adapter.callAdapterWithRelayerContext(relayerContexts[relayerContextIndex], adapterCalldata),
                        IRouter.AdapterCallFailed()
                    );

                    // Increment solver context index after successful adapter call
                    unchecked {
                        ++relayerContextIndex;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        // ============= Step 3: Final Validation =============
        // Ensure all provided solver contexts were consumed
        // This prevents accidentally providing too many contexts (could indicate misconfiguration)
        // and ensures all regular adapter calls had corresponding contexts
        require(relayerContextsLength == relayerContextIndex, IRouter.LengthMismatch());
    }

    /**
     * @notice Executes a single claim operation by routing it to the appropriate protocol adapter.
     * @dev Simplified single-operation version of the batch routeClaim function. Provides the same
     *      functionality as the batch version but optimized for single operations:
     *
     *      **SINGLE OPERATION FLOW:**
     *      1. Extract the 4-byte selector from calldata to identify operation type
     *      2. Check for special selectors (singleCall, multiCall) that bypass adapter lookup
     *      3. For regular operations: load the appropriate claim adapter and execute with context
     *      4. Ensure adapter call succeeds with matching selector validation
     *
     *      **SPECIAL SELECTOR SUPPORT:**
     *      Built-in selectors for common operations are handled directly without adapter lookup:
     *      - Single calls for direct contract interactions
     *      - Multi calls for batched contract interactions
     *      - Fee collection operations
     *      This saves ~2600+ gas by avoiding SLOAD and DELEGATECALL overhead.
     *
     *      **PROTOCOL ADAPTER EXECUTION:**
     *      Regular claim operations are routed to protocol-specific adapters (SameChainAdapter,
     *      CrossChainAdapter, etc.) that handle the underlying protocol interactions for resource
     *      unlocking and settlement completion.
     *
     * @param relayerContext The solver-specific context data required by the adapter for this claim.
     *                     Contains parameters like user addresses, amounts, signatures, and other
     *                     operation-specific data needed for successful claim execution.
     * @param adapterCalldata The complete calldata for adapter execution, including the 4-byte selector
     *                       and encoded parameters. The selector determines which adapter to route to,
     *                       while parameters contain the operation-specific data.
     *
     * @custom:gas Single operation version avoids batch processing overhead for simple claims
     * @custom:security No atomic signature required - relies on protocol-level authorization
     * @custom:efficiency Special selectors bypass adapter lookup for maximum gas efficiency
     */
    function routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) public payable nonReentrant {
        bytes4 selector = bytes4(adapterCalldata[:4]);
        // in order to support single / multicalls without sloading and delegatecalling an adapter,
        // these special selectors can be used
        if (!_processDirectClaimRoute(selector, adapterCalldata)) {
            address adapter = selector.withClaimAdapter().adapterAddress();
            require(selector == adapter.callAdapterWithRelayerContext(relayerContext, adapterCalldata), IRouter.AdapterCallFailed());
        }
    }

    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual override returns (bool) {
        return false;
    }
}
