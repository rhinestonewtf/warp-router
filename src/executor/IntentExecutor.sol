// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { CompactEIP712 } from "@rhinestone/compact-utils/src/common/CompactEIP712.sol";
import { CompactIntentExecutor } from "./CompactIntent/CompactIntentExecutor.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { ValidateSignature } from "./VerifySignature/VerifySignature.sol";
import { IntentExecutorBase } from "./IntentExecutorBase.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Permit2EIP712 } from "@rhinestone/compact-utils/src/common/Permit2EIP712.sol";
import { Permit2IntentExecutor } from "./Permit2Intent/Permit2Executor.sol";
import { StandaloneIntentExecutor } from "./StandaloneIntent/StandaloneIntent.sol";
import { TrustedExecution } from "./TrustedExecution/TrustedExecution.sol";
import { ERC7579InitializedLib } from "./lib/ERC7579InitializedLib.sol";

/**
 * @title IntentExecutor
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Main executor contract that unifies multiple intent execution mechanisms
 * @dev This contract serves as the central hub for executing different types of intents:
 *      - CompactIntentExecutor: Executes intents using The Compact protocol for cross-chain transfers
 *      - Permit2IntentExecutor: Executes intents using Permit2 for gasless token approvals
 *      - StandaloneIntentExecutor: Executes intents independently without external protocols
 *      - TrustedExecution: Executes operations from trusted parties without signature verification
 *
 *      The contract inherits from ERC7579ExecutorBase to provide modular account compatibility
 *      and implements the ERC-7579 executor module interface for smart contract wallets.
 *
 * @custom:security This contract aggregates multiple execution paths, each with different trust models.
 *                  Users should understand the security implications of each execution type before use.
 */
contract IntentExecutor is
    ERC7579ExecutorBase,
    IntentExecutorBase,
    ValidateSignature,
    CompactIntentExecutor,
    Permit2IntentExecutor,
    StandaloneIntentExecutor,
    TrustedExecution
{
    using ERC7579InitializedLib for address;
    using ERC7579InitializedLib for bytes32;
    /**
     * @notice Initializes the IntentExecutor with required dependencies for all execution types
     * @dev Chains constructor calls to initialize each inherited executor component:
     *      - CompactIntentExecutor requires router, compact protocol, and lock tag
     *      - Permit2IntentExecutor has no constructor parameters
     *      - StandaloneIntentExecutor looks up Paymaster from AddressBook for gas refunds
     *      - TrustedExecution requires an address book for trusted party validation
     *      - ExecutionSigChecker requires compact protocol
     * @param router The router contract address for cross-chain operations
     * @param compact The Compact protocol contract address for cross-chain transfers
     * @param allocator the RSAllocator
     * @param addressBook The address book contract for managing trusted execution parties
     */

    constructor(
        address router,
        address compact,
        address allocator,
        address addressBook,
        address smartSessionEmissary
    )
        TrustedExecution(addressBook)
        ValidateSignature(compact, smartSessionEmissary)
        CompactEIP712(compact)
        Permit2EIP712(address(Constants.PERMIT2))
        IntentExecutorBase(router, allocator)
        StandaloneIntentExecutor(addressBook)
    { }

    /**
     * @notice Checks if the executor module is initialized for a specific smart account
     * @dev This function is required by the ERC-7579 module interface but currently returns
     *      false as initialization state is not tracked. Future implementations may add
     *      account-specific initialization tracking.
     * @param smartAccount The smart account address to check initialization status for
     * @return bool Always returns false in current implementation
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return (smartAccount.moduleSlot().get() == 1);
    }

    /**
     * @notice Identifies this contract as an ERC-7579 executor module
     * @dev Part of the ERC-7579 module interface. Returns true only for MODULE_TYPE_EXECUTOR
     *      to indicate this contract implements executor functionality.
     * @param moduleTypeId The module type identifier to check against
     * @return bool True if moduleTypeId matches MODULE_TYPE_EXECUTOR, false otherwise
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    /**
     * @notice Handles module installation on a smart account
     * @dev Required by ERC-7579 but currently performs no initialization logic.
     *      Future implementations may add account-specific setup here.
     */
    function onInstall(
        bytes calldata /* data*/
    )
        external
    {
        address account = msg.sender;
        account.moduleSlot().set(1);
    }

    /**
     * @notice Handles module uninstallation from a smart account
     * @dev Required by ERC-7579 but currently performs no cleanup logic.
     *      Future implementations may add account-specific cleanup here.
     */
    function onUninstall(
        bytes calldata /* data*/
    )
        external
    {
        address account = msg.sender;
        account.moduleSlot().set(0);
    }

    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual override returns (bool) {
        return false;
    }
}
