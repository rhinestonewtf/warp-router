// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

/**
 * @title IStandaloneIntentExecutor
 * @notice Interface for standalone multi-chain intent execution
 * @dev Defines the contract interface for executing intents independently without external protocols
 */
interface IStandaloneIntentExecutor {
    /// @notice Thrown when standalone intent signature validation fails
    error InvalidStandaloneIntentSignature();

    /// @notice Thrown when an invalid gas token is specified
    error InvalidGasToken();

    event IntentExecuted(address account, uint256 nonce);

    /**
     * @notice Multi-chain operations structure for standalone intent execution
     * @dev Contains all data needed for chain-agnostic multi-chain operation execution
     */
    struct MultiChainOps {
        /// @dev The account address that owns and signed these operations
        address account;
        /// @dev Index position of current chain in the otherChains array
        uint256 chainIndex;
        /// @dev Array of operation hashes from other chains in the multi-chain intent
        bytes32[] otherChains;
        /// @dev Nonce for replay protection
        uint256 nonce;
        /// @dev Operations to execute on the current chain
        Types.Operation ops;
        /// @dev EIP-712 signature from the account authorizing all operations
        bytes signature;
    }

    /**
     * @notice Single-chain operations structure for standalone intent execution
     * @dev Contains all data needed for single-chain operation execution without cross-chain coordination.
     *      This is a simpler alternative to MultiChainOps for operations that don't require multi-chain support.
     *
     *      Key differences from MultiChainOps:
     *      - No chainIndex field (operations are for current chain only)
     *      - No otherChains array (no cross-chain coordination needed)
     *      - Uses standard EIP-712 hashing with chain ID (not chain-agnostic)
     *      - More gas efficient (~850 gas cheaper) due to simpler structure
     *
     *      Use this struct when operations are limited to a single chain and don't need
     *      cross-chain signature validation.
     */
    struct SingleChainOps {
        /// @dev The account address that owns and signed these operations
        address account;
        /// @dev Nonce for replay protection
        uint256 nonce;
        /// @dev Operations to execute on the current chain
        Types.Operation ops;
        /// @dev EIP-712 signature from the account authorizing the operations
        bytes signature;
    }

    /**
     * @notice Gas refund parameters for ERC20 token relayer compensation
     * @dev This struct defines the gas refund terms that the user commits to in their signature.
     *      The gas refund is paid by the user to compensate the relayer for gas costs.
     *      These parameters are hashed and included in the EIP-712 digest to prevent
     *      relayers from modifying refund terms after the user has signed.
     *
     *      Note: This struct is only used for ERC20 token refunds. Native ETH refunds use
     *      a hardcoded 1:1 exchange rate and only require the overhead parameter.
     */
    struct GasRefund {
        /// @dev ERC20 token address for gas refund (must not be Constants.NATIVE_TOKEN)
        address token;
        /// @dev Exchange rate: how many token units equal 1 ETH (scaled to 1e18)
        uint256 exchangeRate;
        /// @dev Fixed gas overhead to add to the gas calculation
        uint256 overhead;
    }

    /**
     * @notice Executes a multi-chain intent after signature validation
     * @dev Validates the chain-agnostic EIP-712 signature and executes operations
     * @param signedOps The complete multi-chain operations structure with signature
     */
    function executeMultichainOps(MultiChainOps calldata signedOps) external;

    /**
     * @notice Executes multi-chain operations with ERC20 token gas refund for relayer compensation
     * @dev This function includes the gas refund commitment in the EIP-712 signature validation.
     *      The user explicitly authorizes the gas refund terms when signing, preventing relayers
     *      from modifying refund amounts. After execution, tokens are transferred to the recipient.
     *
     *      For native ETH refunds, use executeMultichainOpsWithGasRefund_ETH instead.
     *
     * @param signedOps The complete multi-chain operations structure with signature
     * @param gasRefund The gas refund terms (ERC20 token, exchange rate, and overhead)
     * @param gasRefundRecipient Address that will receive the gas refund payment
     * @return account The account address that executed the operations
     * @return nonce The nonce that was consumed during execution
     * @custom:security Gas refund is included in signature to prevent relayer manipulation
     * @custom:security Reverts with InvalidGasToken if gasRefund.token is Constants.NATIVE_TOKEN
     */
    function executeMultichainOpsWithGasRefund_ERC20(
        MultiChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce);

    /**
     * @notice Executes multi-chain operations with native ETH gas refund for relayer compensation
     * @dev Optimized variant for native ETH gas refunds with automatic 1:1 exchange rate.
     *      This function is more gas efficient than the ERC20 variant for owner signatures
     *      because it skips the Paymaster intermediary and performs a direct ETH transfer.
     *
     *      The exchange rate is hardcoded to 1e18 (1:1) for ETH-to-ETH conversion.
     *
     * @param signedOps The complete multi-chain operations structure with signature
     * @param overhead The fixed gas overhead to add to the refund calculation (gas units)
     * @param gasRefundRecipient Address that will receive the gas refund payment
     * @return account The account address that executed the operations
     * @return nonce The nonce that was consumed during execution
     * @custom:security Exchange rate is hardcoded to 1:1 for ETH-to-ETH conversion
     * @custom:gas Owner signature modes save ~17-22k gas vs ERC20 variant by skipping Paymaster
     */
    function executeMultichainOpsWithGasRefund_ETH(
        MultiChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce);

    /**
     * @notice Executes a single-chain intent after signature validation
     * @dev Validates the EIP-712 signature and executes operations on a single chain
     * @param signedOps The complete single-chain operations structure with signature
     */
    function executeSinglechainOps(SingleChainOps calldata signedOps) external;

    /**
     * @notice Executes single-chain operations with ERC20 token gas refund for relayer compensation
     * @dev This function includes the gas refund commitment in the EIP-712 signature validation.
     *      The user explicitly authorizes the gas refund terms when signing, preventing relayers
     *      from modifying refund amounts. After execution, tokens are transferred to the recipient.
     *
     *      For native ETH refunds, use executeSinglechainOpsWithGasRefund_ETH instead.
     *
     * @param signedOps The complete single-chain operations structure with signature
     * @param gasRefund The gas refund terms (ERC20 token, exchange rate, and overhead)
     * @param gasRefundRecipient Address that will receive the gas refund payment
     * @return account The account address that executed the operations
     * @return nonce The nonce that was consumed during execution
     * @custom:security Gas refund is included in signature to prevent relayer manipulation
     * @custom:security Reverts with InvalidGasToken if gasRefund.token is Constants.NATIVE_TOKEN
     */
    function executeSinglechainOpsWithGasRefund_ERC20(
        SingleChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce);

    /**
     * @notice Executes single-chain operations with native ETH gas refund for relayer compensation
     * @dev Optimized variant for native ETH gas refunds with automatic 1:1 exchange rate.
     *      This function is more gas efficient than the ERC20 variant for owner signatures
     *      because it skips the Paymaster intermediary and performs a direct ETH transfer.
     *
     *      The exchange rate is hardcoded to 1e18 (1:1) for ETH-to-ETH conversion.
     *
     * @param signedOps The complete single-chain operations structure with signature
     * @param overhead The fixed gas overhead to add to the refund calculation (gas units)
     * @param gasRefundRecipient Address that will receive the gas refund payment
     * @return account The account address that executed the operations
     * @return nonce The nonce that was consumed during execution
     * @custom:security Exchange rate is hardcoded to 1:1 for ETH-to-ETH conversion
     * @custom:gas Owner signature modes save ~17-22k gas vs ERC20 variant by skipping Paymaster
     */
    function executeSinglechainOpsWithGasRefund_ETH(
        SingleChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce);

    /**
     * @notice Checks if a nonce has been used for a specific account
     * @dev Provides a way to check nonce usage for standalone intents
     * @param nonce The nonce value to check
     * @param account The account address that owns the nonce
     * @return used True if the nonce has been consumed, false otherwise
     */
    function isStandaloneIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used);
}
