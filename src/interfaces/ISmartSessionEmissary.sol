// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

/**
 * @title ISmartSessionEmissary
 * @notice Interface for emissary contracts that validate execution-aware signatures
 * @dev Emissaries implementing this interface can enforce fine-grained policies on
 *      operations being executed. Unlike simple signature validation, this allows
 *      the emissary to inspect and restrict the actual execution context.
 */
interface ISmartSessionEmissary {
    /**
     * @notice Validates a signature with full awareness of the operations being executed
     * @dev This method provides comprehensive validation by giving the emissary context
     *      about both the signature and the operations. The emissary can enforce policies such as:
     *      - Restricting which contracts can be called
     *      - Limiting transaction values
     *      - Enforcing time-based restrictions
     *      - Validating complex business logic based on the operation data
     *
     *      The function must return its own selector (verifyExecution.selector) to indicate
     *      approval. This pattern prevents accidental approval from functions that return bool.
     *
     * @param account The account address that authorized the emissary
     * @param hash The EIP-712 digest of the data being signed
     * @param data The signature data (format depends on emissary implementation)
     * @param ops The Types.Operation containing execution data with vt prefix (exec type + sig mode)
     * @return selector Must return verifyExecution.selector if the execution is approved
     * @custom:security The emissary must be authorized in TheCompact for the given account/lockTag
     * @custom:gas May be gas-intensive as the emissary can perform complex validation logic
     */
    function verifyExecution(address account, bytes32 hash, bytes calldata data, Types.Operation calldata ops) external returns (bytes4);
}
