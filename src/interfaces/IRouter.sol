// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IEvents {
    /// @notice Emitted when DirectRoute fill event is used
    event RouterFilled(address account, uint256 nonce);
}

/**
 * @title IRouter
 * @notice Interface for the Warp Routerr contract
 * @dev This interface defines all external functions and errors for the RouterLogic contract
 */
interface IRouter {
    // ============= Errors =============

    /// @notice Thrown when the provided account address is the zero address
    error InvalidAccountAddress();

    /// @notice Thrown if account creation fails
    error AccountCreationFailed();

    /// @notice Thrown when the contract is paused
    error Paused();

    /// @notice Thrown when input arrays have mismatched lengths
    error LengthMismatch();

    /// @notice Thrown when an atomic operation fails signature validation
    error InvalidAtomicity();

    /// @notice Thrown when atomic signer isn't set
    error AtomicSignerNotSet();

    /// @notice Thrown when an adapter call fails
    error AdapterCallFailed();

    // ============= Core Routing Functions =============

    /**
     * @notice Gas-optimized version of routeFill with enhanced batching and caching mechanisms
     * @param relayerContexts Array of solver-specific contexts, consumed only by regular adapter calls
     * @param encodedAdapterCalldatas ABI-encoded bytes containing the array of adapter calldatas
     * @param atomicFillSignature Signature from atomicFillSigner authorizing this batch execution
     */
    function optimized_routeFill921336808(
        bytes[] calldata relayerContexts,
        bytes calldata encodedAdapterCalldatas,
        bytes calldata atomicFillSignature
    )
        external
        payable;

    /**
     * @notice Routes multiple claim operations to their adapters
     * @param relayerContexts Array of solver-specific context for these operations
     * @param adapterCalldatas Array of calldata for the adapters
     */
    function routeClaim(bytes[] calldata relayerContexts, bytes[] calldata adapterCalldatas) external payable;

    /**
     * @notice Routes a single claim operation to its adapter
     * @param relayerContext The solver-specific context for this operation
     * @param adapterCalldata The calldata for the adapter
     */
    function routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) external payable;
}
