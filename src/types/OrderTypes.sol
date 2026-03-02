// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title Types
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice A library defining the core data structures used throughout the Compact protocol for orders and executions.
 */
library Types {
    /**
     * @notice The core structure representing a user's intent or order.
     * @param sponsor The user or smart account initiating the order.
     * @param recipient The final beneficiary of the output tokens.
     * @param nonce A unique number to prevent replay attacks, scoped to the sponsor.
     * @param expires A timestamp after which the order is no longer valid.
     * @param fillDeadline A timestamp by which the order must be filled by a solver.
     * @param notarizedChainId The chain ID where the primary claim and notarization occur.
     * @param targetChainId The chain ID where the final output is delivered.
     * @param tokenIn An array of `[token_address, amount]` pairs for the input assets.
     * @param tokenOut An array of `[token_address, amount]` pairs for the output assets.
     * @param preClaimOps Encoded operations (e.g., approvals) to be executed before the main claim.
     * @param targetOps Encoded operations (e.g., swaps) to be executed on the target chain.
     * @param qualifier Chain-specific data used by arbiters for validation.
     * @param packedGasValues Packed gasStipend and minGas values (minGas in upper 128 bits, gasStipend in lower 128 bits).
     * @param otherElements Hashes of other elements in a multi-chain order, passed within the order struct itself.
     */
    struct Order {
        address sponsor;
        address recipient;
        uint256 nonce;
        uint256 expires;
        uint256 fillDeadline;
        uint256 notarizedChainId;
        uint256 targetChainId;
        uint256[2][] tokenIn; // aka idsAndAmounts
        uint256[2][] tokenOut;
        uint256 packedGasValues; // Packed gasStipend and minGas values
        Operation preClaimOps; // See SmartExecutionLib
        Operation targetOps; // See SmartExecutionLib
        bytes qualifier; // User qualification (Non-legible EIP712, ends up in `q` param in mandate)
    }

    /**
     * @notice A generic wrapper for an encoded execution payload.
     * @param data The raw bytes of the execution payload, see `SmartExecutionLib`.
     */
    struct Operation {
        bytes data;
    }

    /**
     * @notice A container for the various signatures required during the order lifecycle.
     * @dev For single-signature flows, `preClaimSig` and `destinationChainSig` can be left empty.
     *      In such cases, the system is designed to fall back and reuse the `notarizedClaimSig`.
     *      Modules and arbiters will override the calldata pointers to use the fallback signature.
     * @param preClaimSig Signature for `preClaimOps`. If empty, `notarizedClaimSig` is used.
     * @param notarizedClaimSig The primary signature for the claim on the notarizing chain.
     * @param destinationChainSig Signature for the claim on the destination chain. If empty, `notarizedClaimSig` is used.
     */
    struct Signatures {
        bytes notarizedClaimSig;
        bytes preClaimSig;
    }

    /**
     * @notice Maximum allowed minGas value to prevent unrealistic gas requirements
     * @dev Set to 2M gas as a reasonable upper bound for pre-claim operations.
     *      This prevents users from signing orders with excessive minGas values that:
     *      - Would be economically impractical to execute
     *      - Could be used to grief relayers with impossible gas requirements
     *      - Exceed what any reasonable pre-claim operation would need
     */
    uint128 internal constant MAX_MIN_GAS = 2_000_000;

    /// @notice Error thrown when the provided gas stipend is less than the minimum required gas
    error GasStipendTooLow();

    /**
     * @notice Error thrown when minGas exceeds the maximum allowed gas limit
     * @dev Prevents users from signing orders with unrealistic minGas values.
     *      If this error is thrown, the user should reduce their minGas value
     *      to be at most MAX_MIN_GAS (2,000,000 gas).
     */
    error MinGasExceedsLimit();

    /**
     * @notice Splits packed gas values into individual components with validation
     * @dev The packedGasValues field uses a uint256 to store two uint128 values:
     *      - Lower 128 bits: gasStipend (maximum gas provided for pre-claim operations)
     *      - Upper 128 bits: minGas (minimum gas the user requires for pre-claim ops)
     *
     *      This function performs two critical validations:
     *      1. minGas <= gasStipend: User's minimum requirement must fit within provided stipend
     *      2. minGas <= MAX_MIN_GAS: User's minimum requirement must be reasonable (2M max)
     *
     *      The minGas validation (2) prevents users from signing orders with impossible
     *      gas requirements that would either fail to execute or grief relayers.
     *
     * @param gasStipend The packed gas values (minGas in upper 128 bits, gasStipend in lower 128 bits)
     * @return _gasStipend The maximum gas provided for pre-claim operations
     * @return minGas The minimum gas required by the user for pre-claim operations
     * @custom:security Validates minGas against MAX_MIN_GAS to prevent unrealistic orders
     */
    function splitGasStipend(uint256 gasStipend) internal pure returns (uint128 _gasStipend, uint128 minGas) {
        assembly ("memory-safe") {
            _gasStipend := and(gasStipend, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            minGas := shr(128, gasStipend)
        }
        require(minGas <= _gasStipend, GasStipendTooLow());

        // Prevent unrealistic minGas values that exceed MAX_MIN_GAS
        // This protects against orders that would be impossible to execute
        require(minGas <= MAX_MIN_GAS, MinGasExceedsLimit());
    }

    function packGasValues(uint128 gasStipend, uint128 minGas) internal pure returns (uint256 packed) {
        assembly ("memory-safe") {
            packed := or(shl(128, minGas), gasStipend)
        }
    }

    /**
     * @notice Returns the signature required for the notarized chain claim.
     * @param signatures The struct containing all signatures.
     * @return sig The `notarizedClaimSig`.
     */
    function useNotarizedChainSig(Signatures calldata signatures) internal pure returns (bytes calldata sig) {
        // This is the primary signature and is expected to be present.
        return signatures.notarizedClaimSig;
    }

    /**
     * @notice Returns the signature for the pre-claim operations, with a fallback to the notarized chain signature.
     * @dev This enables single-signature flows where one signature can authorize multiple steps.
     * @param signatures The struct containing all signatures.
     * @return sig The `preClaimSig` if present, otherwise `notarizedClaimSig`.
     */
    function userPreClaimSig(Signatures calldata signatures) internal pure returns (bytes calldata sig) {
        if (signatures.preClaimSig.length != 0) {
            return signatures.preClaimSig;
        } else {
            // Fallback for single-signature flows.
            return signatures.notarizedClaimSig;
        }
    }
}
