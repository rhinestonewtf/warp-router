// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

interface ICompactIntentExecutor {
    error InvalidParams();
    /**
     * @notice Stub data for EIP-712 element construction on origin chain
     * @dev Used during pre-claim operation execution to reconstruct the full element hash
     *      without requiring all data to be passed as parameters
     */

    struct EIP712ElementStubOrigin {
        /// @dev Array of other element hashes in the Compact Merkle tree
        bytes32[] otherElements;
        uint128 minGas;
        /// @dev Index position where this element should be inserted in the otherElements array
        uint256 elementOffset;
        /// @dev Hash of target operations that will be executed on destination chain
        bytes32 destOpsHash;
        /// @dev Hash of input token details for this element
        bytes32 tokenInHash;
        /// @dev Pre-computed hash of target attributes (account, tokenOut, chain, expires, proofer)
        bytes32 targetAttributesHash;
        /// @dev Hash of the qualifier data specific to this element
        bytes32 qHash;
    }

    /**
     * @notice Stub data for EIP-712 element construction on destination chain
     * @dev Used during target operation execution to reconstruct the full element hash
     *      and verify the claim hash proof before execution
     */
    struct EIP712ElementStubDestination {
        /// @dev Address that sponsored the original Compact order
        address sponsor;
        /// @dev Array of other element hashes in the Compact Merkle tree
        bytes32[] otherElements;
        /// @dev Index position where this element should be inserted in the otherElements array
        uint256 elementOffset;
        /// @dev Hash of pre-claim operations that were executed on origin chain
        bytes32 preClaimOpsHash;
        /// @dev Hash of input token details for this element
        bytes32 tokenInHash;
        /// @dev Hash of output token details for this element
        bytes32 tokenOutHash;
        /// @dev Timestamp after which the fill operation expires
        uint256 fillExpires;
        /// @dev Hash of the qualifier data specific to this element
        bytes32 qHash;
    }

    /**
     * @notice Core Compact order data that remains consistent across all elements
     * @dev Contains the essential order metadata that's used in EIP-712 hash construction
     *      for both pre-claim and target operations
     */
    struct EIP712CompactStub {
        /// @dev Unique nonce for this Compact order to prevent replay attacks
        uint256 nonce;
        /// @dev Timestamp after which the entire Compact order expires
        uint256 expires;
        /// @dev Chain ID where the order was originally notarized/signed
        uint256 notarizedChainId;
    }

    /**
     * @notice Executes target operations on the destination chain with claim hash verification
     * @dev This function implements the second phase of cross-chain intent execution. It:
     *      1. Reconstructs the element hash from the provided stub data
     *      2. Validates that execution is happening on the correct target chain
     *      3. Checks that the fill hasn't expired
     *      4. Builds the complete Compact Merkle tree with all elements
     *      5. Computes the final EIP-712 claim hash
     *      6. Verifies the claim hash proof through the designated proofer contract
     *      7. Executes the target operations if all validations pass
     * @param account The recipient account address for the target operations
     * @param notarizedArbiter The arbiter address that notarized the cross-chain transfer
     * @param compactStub Core Compact order data (nonce, expires, notarized chain)
     * @param elementStub Element-specific data needed for destination chain execution
     * @param targetOps Array of operations to execute on the destination chain
     * @param signature EIP-712 signature authorizing the target operations
     * @return claimHash The computed claim hash used for verification
     */
    function executeTargetOpsWithCompactStub(
        address account,
        address notarizedArbiter,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubDestination calldata elementStub,
        Types.Operation calldata targetOps,
        bytes calldata signature
    )
        external
        returns (bytes32 claimHash);

    /**
     * @notice Executes pre-claim operations on the origin chain before cross-chain transfer
     * @dev This function implements the first phase of cross-chain intent execution. It:
     *      1. Reconstructs the element hash using the caller as the arbiter
     *      2. Builds the complete Compact Merkle tree with all elements
     *      3. Computes the final EIP-712 claim hash
     *      4. Executes the pre-claim operations after signature validation
     *      5. Sets the signature skip flag for corresponding target operations
     * @param account The smart account address that owns the assets and signed the order
     * @param compactStub Core Compact order data (nonce, expires, notarized chain)
     * @param elementStub Element-specific data needed for origin chain execution
     * @param preClaimOps Array of operations to execute before cross-chain transfer (e.g., token approvals)
     * @param signature EIP-712 signature from the account authorizing these operations
     * @return sigOk True if the signature validation passed
     * @return execOk True if the pre-claim operations executed successfully
     */
    function executePreClaimOpsWithCompactStub(
        address account,
        EIP712CompactStub calldata compactStub,
        EIP712ElementStubOrigin calldata elementStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature
    )
        external
        returns (bool sigOk, bool execOk);

    function isCompactIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
}
