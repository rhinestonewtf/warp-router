// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { ICompactIntentExecutor } from "../executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "../executor/interfaces/IPermit2Intent.sol";
import { IStandaloneIntentExecutor } from "../executor/interfaces/IStandaloneIntent.sol";
import { ITrustedExecution } from "./ITrustedExecution.sol";

/**
 * @title IIntentExecutor
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Interface for the IntentExecutor contract that handles intent execution within the Compact protocol
 * @dev This interface combines multiple execution strategies by inheriting from specialized sub-executor interfaces:
 *      - ICompactIntentExecutor: Handles Compact protocol operations with pre-claim and target execution
 *      - IPermit2IntentExecutor: Handles Permit2-based intent execution
 *      - IStandaloneIntentExecutor: Handles standalone multi-chain operations
 *      - ITrustedExecution: Handles execution without signatures for whitelisted arbiters
 */
interface IIntentExecutor is ICompactIntentExecutor, IPermit2IntentExecutor, IStandaloneIntentExecutor, ITrustedExecution {
    /**
     * @notice Checks if the module is initialized for a given smart account
     * @param smartAccount The address of the smart account to check
     * @return bool True if the module is initialized for the account
     */
    function isInitialized(address smartAccount) external view returns (bool);

    /**
     * @notice Checks if the module supports a specific module type
     * @param moduleTypeId The module type identifier to check
     * @return bool True if the module type is supported (should return true for MODULE_TYPE_EXECUTOR)
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool);

    /**
     * @notice Called when the module is installed on a smart account
     * @param data Installation data (if any)
     */
    function onInstall(bytes calldata data) external;

    /**
     * @notice Called when the module is uninstalled from a smart account
     * @param data Uninstallation data (if any)
     */
    function onUninstall(bytes calldata data) external;
}
