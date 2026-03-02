// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

/**
 * @title IPermit2IntentExecutor
 * @notice Interface for Permit2-based intent execution
 * @dev Defines the contract interface for executing intents using Permit2 for gasless approvals
 */
interface IPermit2IntentExecutor {
    /// @notice Thrown when Permit2 signature validation fails
    error InvalidPermit2Signature();

    /**
     * @notice Core Permit2 parameters for intent execution
     * @dev Contains essential Permit2 data for signature validation and replay protection
     */
    struct EIP712Permit2Stub {
        /// @dev Nonce for replay protection
        uint256 nonce;
        /// @dev Expiration timestamp for the permit
        uint256 expires;
    }

    /**
     * @notice Mandate-specific parameters for Permit2 intent execution
     * @dev Contains hashed operation and token data for the intent mandate
     */
    struct EIP712Permit2MandateStub {
        /// @dev Hash of input token details
        bytes32 tokenInHash;
        /// @dev Minimum gas required for execution of operations
        uint128 minGas;
        /// @dev Hash of target attributes (account, tokenOut, chain, expires)
        bytes32 targetAttributesHash;
        /// @dev Hash of destination operations to execute
        bytes32 destOpsHash;
        /// @dev Hash of qualifier data specific to this mandate
        bytes32 qHash;
    }

    /**
     * @notice Mandate-specific parameters for Permit2 destination chain execution
     * @dev Contains all data needed to reconstruct the mandate hash for destination chain
     *      execution verification. Includes the nested Target struct for fill parameters.
     */
    struct EIP712Permit2MandateDestinationStub {
        /// @dev Original sponsor address from the origin chain
        address sponsor;
        /// @dev Arbiter that facilitated the cross-chain transfer
        address arbiter;
        /// @dev Minimum gas required for pre-claim operations
        uint128 minGas;
        /// @dev Chain ID where the order was originally notarized
        uint256 notarizedChainId;
        /// @dev Hash of pre-claim operations from origin chain
        bytes32 preClaimOpsHash;
        /// @dev Hash of input token details
        bytes32 tokenInHash;
        /// @dev Hash of qualifier data
        bytes32 qHash;
        /// @dev Target parameters for fill validation
        Target targetStub;
    }

    /**
     * @notice Target chain fill parameters for Permit2 destination execution
     * @dev Contains minimal parameters needed to validate the fill on destination chain
     */
    struct Target {
        /// @dev Deadline timestamp for completing the fill
        uint256 fillExpiry;
        /// @dev Hash of expected output tokens
        bytes32 tokenOutHash;
    }

    /**
     * @notice Executes pre-claim operations using Permit2-based authorization
     * @dev Validates Permit2 signature and executes operations before any cross-chain transfers
     * @param account The user account that signed the intent
     * @param permit2Stub Core Permit2 parameters including nonce and expiration
     * @param mandateStub Mandate-specific parameters with operation and token hashes
     * @param preClaimOps Array of operations to execute on the origin chain
     * @param signature EIP-712 signature from the account authorizing the operations
     * @return permit2Hash The computed Permit2 hash used for signature validation
     */
    function executePreClaimOpsWithPermit2Stub(
        address account,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateStub calldata mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        returns (bytes32 permit2Hash);

    /**
     * @notice Executes target operations using Permit2-based authorization
     * @dev Validates Permit2 signature and executes operations on the destination chain
     * @param account The user account that signed the intent
     * @param permit2Stub Core Permit2 parameters including nonce and expiration
     * @param mandateStub Mandate-specific parameters with operation and token hashes
     * @param targetOps Array of operations to execute on the destination chain
     * @param signature EIP-712 signature from the account authorizing the operations
     * @return permit2Hash The computed Permit2 hash used for signature validation
     */
    function executeTargetOpsWithPermit2Stub(
        address account,
        EIP712Permit2Stub calldata permit2Stub,
        EIP712Permit2MandateDestinationStub calldata mandateStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        returns (bytes32 permit2Hash);

    /**
     * @notice Checks if a nonce has been used for a specific account
     * @dev Provides a way to check nonce usage for Permit2 intents
     * @param nonce The nonce value to check
     * @param account The account address that owns the nonce
     * @return used True if the nonce has been consumed, false otherwise
     */
    function isPermit2IntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
}
