// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IAddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/IAddressBook.sol";
import { LibERC7579 } from "@rhinestone/compact-utils/src/common/LibERC7579.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

/**
 * @title TrustedExecution
 * @notice Enables execution of operations without signatures for trusted arbiters
 * @dev This contract implements a dual-layer trust system for executing operations without
 *      requiring user signatures:
 *
 *      Layer 1 - Whitelisted Arbiters:
 *      - SAMECHAIN_ARBITER: Pre-approved for same-chain operations
 *      - SAMECHAIN_JIT_ARBITER: Pre-approved for just-in-time same-chain operations
 *      - These arbiters can execute operations immediately without additional permissions
 *
 *      Layer 2 - Dynamic Trust (Signature Skip):
 *      - Any address can gain temporary execution permission through signature skip mechanism
 *      - Typically granted after successful execution of signed operations
 *      - Allows follow-up operations without requiring additional signatures
 *
 *      Use cases:
 *      - Multi-step intent execution where initial signature authorizes subsequent operations
 *      - Cross-chain operations where origin chain execution grants permission for destination execution
 *      - Gas-optimized execution flows avoiding repeated signature validations
 *
 * @custom:security CRITICAL SECURITY CONSIDERATIONS:
 *                  - Whitelisted arbiters have permanent execution privileges without user consent
 *                  - Signature skip permissions should only be granted after proper user authorization
 *                  - Address book integrity is crucial as it defines the trusted arbiters
 *                  - No expiration mechanism exists for signature skip permissions
 */
abstract contract TrustedExecution {
    using SmartExecutionLib for Types.Operation;

    error ExecutionNotTrusted();

    /// @dev Address of the pre-approved same-chain arbiter for standard operations
    address public immutable SAMECHAIN_ARBITER;

    /**
     * @notice Initializes the trusted execution system with whitelisted arbiters
     * @dev Retrieves the trusted arbiter addresses from the address book using predefined
     *      constant identifiers. These addresses are cached at deployment for gas efficiency
     *      and to avoid external calls during execution validation.
     *
     * @param addressBook The address book contract containing the trusted arbiter addresses
     *
     * @custom:security The address book must be trusted as it defines the permanently
     *                  whitelisted arbiters who can execute operations without signatures
     */
    constructor(address addressBook) {
        SAMECHAIN_ARBITER = IAddressBook(addressBook).getAddress(Constants.SAMECHAIN_ARBITER_ID);
    }

    /**
     * @notice Executes operations on behalf of an account without requiring signatures
     * @dev This function bypasses normal signature validation for trusted arbiters.
     *      The caller must be a whitelisted arbiter
     *
     *      Execution flow:
     *      1. Validates that the caller has permission to execute without signatures
     *      2. Executes the operations on behalf of the specified account
     *
     *      This is the main entry point for trusted execution scenarios.
     *
     * @param account The account address on whose behalf the operations will be executed
     * @param ops abi encoded Array of operations to execute
     *
     * @custom:security This function provides significant privileges to the caller.
     *                  Ensure that only trusted parties can call this function.
     */
    function executeOpsWithoutSignature(address account, Types.Operation calldata ops) external onlyWhitelistedArbiter {
        LibERC7579.executeOps(account, ops);
    }

    modifier onlyWhitelistedArbiter() {
        require(_isWhitelistedArbiter(msg.sender), ExecutionNotTrusted());
        _;
    }

    /**
     * @notice Checks if an arbiter is in the permanent whitelist
     * @dev Compares the arbiter address against the cached addresses of trusted arbiters.
     *      These addresses are set during contract deployment from the address book.
     *
     * @param arbiter The address to check for whitelist status
     * @return bool True if the arbiter is whitelisted, false otherwise
     *
     * @custom:gas This function uses cached addresses to avoid storage reads and external calls
     */
    function _isWhitelistedArbiter(address arbiter) internal view returns (bool) {
        return arbiter == SAMECHAIN_ARBITER;
    }
}
