// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IStandaloneIntentExecutor } from "../interfaces/IStandaloneIntent.sol";
import { ConsumeNonceLib } from "../lib/ConsumeNonceLib.sol";
import { IntentExecutorNonceLib } from "../lib/IntentExecutorNonceLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { EIP712Lib } from "./lib/EIP712Lib.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { IntentExecutorBase } from "../IntentExecutorBase.sol";
import { ValidateSignature } from "@rhinestone/compact-utils/src/executor/VerifySignature/VerifySignature.sol";
import { LibERC7579 } from "@rhinestone/compact-utils/src/common/LibERC7579.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Paymaster } from "./aux/Paymaster.sol";
import { AddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/AddressBook.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";

/**
 * @title StandaloneIntentExecutor
 * @notice Executor contract for standalone multi-chain intent execution without external protocols
 * @dev This contract enables self-contained intent execution with the following key features:
 *
 *      - Chain-agnostic signature validation using EIP-712 without chain-specific components
 *      - Direct nonce management for replay protection at the account level
 *      - ERC-1271 signature validation supporting both EOA and smart contract accounts
 *      - Batch operation execution with gas-optimized single vs. multi-operation handling
 *
 *      The execution flow:
 *      1. User signs a MultiChainOps struct containing operations and metadata
 *      2. Anyone can submit the signed operations for execution
 *      3. Contract validates the signature using chain-agnostic EIP-712 hashing
 *      4. Nonce is consumed to prevent replay attacks
 *      5. Operations are executed on behalf of the signing account
 *
 *      Key differences from other executors:
 *      - No dependency on external protocols (Compact, Permit2)
 *      - Chain-agnostic signatures work across different networks
 *      - Direct account-based authorization without intermediaries
 *
 * @custom:security Security considerations:
 *                  - Chain-agnostic signatures prevent replay across different chains
 *                  - Account-level nonce management provides granular replay protection
 *                  - ERC-1271 validation ensures compatibility with various account types
 *                  - No external protocol dependencies reduce attack surface
 */
abstract contract StandaloneIntentExecutor is
    IStandaloneIntentExecutor,
    EIP712,
    IntentExecutorBase,
    ValidateSignature,
    ReentrancyGuardTransient
{
    using IntentExecutorNonceLib for uint256;
    using ConsumeNonceLib for bytes32;
    using EIP712Lib for MultiChainOps;
    using EIP712Lib for SingleChainOps;
    using SignatureCheckerLib for address;
    using SmartExecutionLib for SmartExecutionLib.SigMode;
    using SmartExecutionLib for Types.Operation;

    Paymaster internal immutable PAYMASTER;

    /// @notice Gas overhead NOT captured by gasleft() measurement
    /// @dev This accounts for gas spent before and after the measured execution window:
    ///      - Function dispatch and calldata decoding
    ///      - EIP712 hashing for gas refund commitment
    ///      - nonReentrant modifier (TSTORE/TLOAD)
    ///      - getCostInToken computation
    ///      - settleGasRefund call (~7k warm, ~34k cold recipient)
    ///      Measured total overhead: ~50k gas. Using 55k for safety margin.
    uint256 internal constant GAS_OVERHEAD = 55_000;

    /// @notice 1e18 constant for exchange rate calculations
    uint256 internal constant ONE_ETHER = 1e18;

    constructor(address addressBook) {
        PAYMASTER = Paymaster(payable(AddressBook(addressBook).getAddress(Constants.PAYMASTER_ID)));
    }

    /**
     * @notice Executes a batch of multi-chain operations after verifying signature and nonce
     * @dev This is the main entry point for standalone intent execution without gas refund.
     *      The function performs comprehensive validation before execution:
     *
     *      1. Computes the EIP-712 hash with NO_GASREFUND flag and extracts the nonce
     *      2. Consumes the nonce immediately to prevent replay attacks
     *      3. Computes the EIP-712 typed data digest for signature validation
     *      4. Validates the signature using the configured validation mode
     *      5. Executes the operations on behalf of the signing account
     *
     *      Chain-agnostic design: The signature validation excludes chain ID from the digest,
     *      allowing the same signature to be valid across different chains. However, the
     *      chain ID is still included in the hash computation by the EIP712Lib to maintain
     *      security while enabling cross-chain compatibility.
     *
     * @param signedOps The MultiChainOps struct containing account, operations, nonce, and signature
     *
     * @custom:security The nonce consumption happens before signature validation to prevent
     *                  partial state changes in case of signature validation failure
     */
    function executeMultichainOps(MultiChainOps calldata signedOps) external {
        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID for security while maintaining cross-chain compatibility
        (bytes32 hash, uint256 nonce) = signedOps.hashAndDecode(EIP712Lib.NO_GASREFUND);

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedDataSansChainId to create chain-agnostic signatures
        bytes32 digest = _hashTypedDataSansChainId(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: signedOps.account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });
    }

    /**
     * @notice Executes multi-chain operations with ERC20 token gas refund after verifying signature and nonce
     * @dev Handles gas refunds in ERC20 tokens only (reverts if token is native ETH).
     *      For native ETH refunds, use executeMultichainOpsWithGasRefund_ETH instead.
     *
     *      Gas Refund Flow:
     *      1. Compute EIP-712 hash including gasRefund commitment
     *      2. Measure gas before execution (gasStart = gasleft())
     *      3. Execute operations via _checkSigAndExecute
     *      4. Calculate gas used and convert to token amount via getCostInToken
     *      5. Settle the gas refund via Paymaster (requires prior token approval)
     *
     *      Settlement Method Selection (SigMode-dependent):
     *      - Execution Emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION):
     *        Uses settleGasRefund_requireCallback. These modes involve the account executing operations
     *        via a session key. The account must pre-authorize a max refund via callback to prevent
     *        session keys from draining funds through inflated exchange rates.
     *
     *      - Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
     *        Uses settleGasRefund directly. The signature comes from the account owner,
     *        so exchange rate is trusted.
     *
     * @param signedOps The MultiChainOps struct containing account, operations, nonce, and signature
     * @param gasRefund The gas refund details (ERC20 token address and exchangeRate for conversion)
     * @param gasRefundRecipient The address that will receive the gas refund payment (typically relayer)
     * @return account The account that was executed on behalf of
     * @return nonce The nonce that was consumed during execution
     *
     * @custom:security The gas refund hash is included in the signature to prevent relayers from
     *                  modifying refund terms. The signer must explicitly authorize the gas costs.
     * @custom:security For execution emissary modes, the account must call Paymaster.callbackAllowMaxAmount
     *                  during execution to cap the refund amount, preventing exchange rate manipulation.
     * @custom:security Reverts with InvalidGasToken if gasRefund.token is Constants.NATIVE_TOKEN
     */
    function executeMultichainOpsWithGasRefund_ERC20(
        MultiChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        nonReentrant
        returns (address account, uint256 nonce)
    {
        account = signedOps.account;
        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID for security while maintaining cross-chain compatibility
        bytes32 hash;

        address gasToken = gasRefund.token;
        // Only ERC20 tokens are allowed
        require(gasToken != Constants.NATIVE_TOKEN, InvalidGasToken());
        uint256 exchangeRate = gasRefund.exchangeRate;
        uint256 overhead = gasRefund.overhead;
        (hash, nonce) = signedOps.hashAndDecode(EIP712Lib.hashGasRefund(gasToken, exchangeRate, overhead));

        // Cache gas price to avoid multiple GASPRICE opcodes
        uint256 gasPrice = tx.gasprice;

        // Measure gas before execution to calculate refund amount dynamically
        uint256 gasStart = gasleft();

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedDataSansChainId to create chain-agnostic signatures
        bytes32 digest = _hashTypedDataSansChainId(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });

        // Calculate token amount: (totalGasCost + overhead) * exchangeRate / 1e18
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasAmount = getCostInToken(gasUsed * gasPrice, gasPrice, exchangeRate, overhead);

        // Determine settlement method based on signature mode
        // Extract the SigMode from the first byte of ops.data
        SmartExecutionLib.SigMode sigMode = signedOps.ops.extractSigMode();
        if (sigMode.isExecutionEmissary()) {
            // Execution emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION)
            // are used when session keys execute operations via the account.
            // Session keys can sign intents on behalf of the account, but they could potentially
            // set a maliciously high exchangeRate to drain the account's funds as "gas refund".
            //
            // To prevent this attack, we require the account to explicitly authorize the max
            // refund amount during execution via Paymaster.callbackAllowMaxAmount(). This call
            // is part of the session key's signed operations and is validated by the session
            // key's action policies, creating defense-in-depth:
            // 1. Action policies can whitelist/restrict calls to callbackAllowMaxAmount
            // 2. The callback caps the actual refund regardless of the signed exchangeRate
            //
            // The account MUST include a call to Paymaster.callbackAllowMaxAmount in its ops
            // for this settlement to succeed.
            PAYMASTER.settleGasRefund_requireCallback(account, gasToken, gasAmount, gasRefundRecipient);
        } else {
            // Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
            // Signature comes from the account owner (not a session key)
            // The owner is trusted to set a reasonable exchangeRate, so no callback required
            PAYMASTER.settleGasRefund(account, gasToken, gasAmount, gasRefundRecipient);
        }
    }

    /**
     * @notice Executes multi-chain operations with native ETH gas refund after verifying signature and nonce
     * @dev Optimized variant for native ETH gas refunds with automatic 1:1 exchange rate.
     *      This function is more gas efficient than the ERC20 variant for owner signatures
     *      because it skips the Paymaster intermediary and performs a direct ETH transfer.
     *
     *      Gas Refund Flow:
     *      1. Compute EIP-712 hash with hardcoded NATIVE_TOKEN and 1e18 exchange rate
     *      2. Measure gas before execution (gasStart = gasleft())
     *      3. Execute operations via _checkSigAndExecute
     *      4. Calculate ETH amount needed for gas refund
     *      5. Settlement (SigMode-dependent):
     *         - Execution emissary modes: Paymaster flow with callback protection (~30k gas)
     *         - Owner signature modes: Direct ETH transfer via executeFromExecutor (~2.8k gas)
     *
     *      Settlement Method Selection (SigMode-dependent):
     *      - Execution Emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION):
     *        Uses settleGasRefund_requireCallback. These modes involve the account executing operations
     *        via a session key. The account must pre-authorize a max refund via callback to prevent
     *        session keys from draining funds through inflated exchange rates.
     *
     *      - Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
     *        Uses direct ETH transfer via executeSingleETHTransfer for gas optimization.
     *        The signature comes from the account owner, so exchange rate is trusted.
     *
     *      Gas Optimization for Owner Signatures:
     *      Owner-signed intents bypass the Paymaster contract entirely, saving ~17-22k gas by:
     *      - Skipping Paymaster's nativeAmounts storage operations (SLOAD + SSTORE)
     *      - Avoiding intermediate transfer (account → Paymaster → recipient)
     *      - Using direct transfer (account → recipient) via executeFromExecutor
     *
     *      Session Key Security:
     *      Execution emissary modes still use the Paymaster callback flow to prevent session keys
     *      from draining accounts via inflated exchange rates. The account must call
     *      Paymaster.callbackAllowMaxAmount during execution to authorize the max refund amount,
     *      which is validated by the session key's action policies.
     *
     * @param signedOps The MultiChainOps struct containing account, operations, nonce, and signature
     * @param overhead The fixed gas overhead to add to the refund calculation (gas units)
     * @param gasRefundRecipient The address that will receive the gas refund payment (typically relayer)
     * @return account The account that was executed on behalf of
     * @return nonce The nonce that was consumed during execution
     *
     * @custom:security Exchange rate is hardcoded to 1e18 (1:1) for ETH-to-ETH conversion
     * @custom:security For execution emissary modes, the account must call Paymaster.callbackAllowMaxAmount
     *                  during execution to cap the refund amount
     * @custom:gas Owner signature modes save ~17-22k gas vs ERC20 variant by skipping Paymaster
     */
    function executeMultichainOpsWithGasRefund_ETH(
        MultiChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        nonReentrant
        returns (address account, uint256 nonce)
    {
        account = signedOps.account;

        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID for security while maintaining cross-chain compatibility
        bytes32 hash;
        // Hardcode NATIVE_TOKEN as token and 1:1 exchange rate for ETH refunds
        (hash, nonce) = signedOps.hashAndDecode(
            EIP712Lib.hashGasRefund({ token: Constants.NATIVE_TOKEN, exchangeRate: ONE_ETHER, overhead: overhead })
        );

        // Cache gas price to avoid multiple GASPRICE opcodes
        uint256 gasPrice = tx.gasprice;

        // Measure gas before execution to calculate refund amount dynamically
        uint256 gasStart = gasleft();

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedDataSansChainId to create chain-agnostic signatures
        bytes32 digest = _hashTypedDataSansChainId(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });

        // Calculate token amount: (totalGasCost + overhead) * exchangeRate / 1e18
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasAmount = (gasUsed + overhead) * gasPrice;

        // Determine settlement method based on signature mode
        // Extract the SigMode from the first byte of ops.data
        SmartExecutionLib.SigMode sigMode = signedOps.ops.extractSigMode();
        if (sigMode.isExecutionEmissary()) {
            // Execution emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION)
            // are used when session keys execute operations via the account.
            // Session keys can sign intents on behalf of the account, and while the exchangeRate
            // for ETH refunds is hardcoded to 1e18 (1:1) and cannot be manipulated, they can set
            // a maliciously high `overhead` value to inflate `gasAmount` and drain the account's
            // funds as "gas refund".
            //
            // To prevent this attack, we require the account to explicitly authorize the max
            // refund amount during execution via Paymaster.callbackAllowMaxAmount(). This call
            // is part of the session key's signed operations and is validated by the session
            // key's action policies, creating defense-in-depth:
            // 1. Action policies can whitelist/restrict calls to callbackAllowMaxAmount
            // 2. The callback caps the actual refund regardless of the signed `overhead`
            //
            // The account MUST include a call to Paymaster.callbackAllowMaxAmount in its ops
            // for this settlement to succeed.
            PAYMASTER.settleGasRefund_requireCallback(account, Constants.NATIVE_TOKEN, gasAmount, gasRefundRecipient);
        } else {
            // Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
            // Signature comes from the account owner (not a session key)
            // Execute a simple ETH transfer to the gas refund recipient
            LibERC7579.executeSingleETHTransfer({ account: account, target: gasRefundRecipient, value: gasAmount });
        }
    }

    /**
     * @notice Executes a single-chain intent after signature validation without gas refund
     * @dev This function handles intent execution limited to a single chain. Unlike the multi-chain
     *      variant, this uses standard chain-specific EIP-712 signature validation which includes
     *      the chain ID in the signature digest.
     *
     *      The execution flow:
     *      1. Computes the EIP-712 hash with NO_GASREFUND flag and extracts the nonce
     *      2. Consumes the nonce immediately to prevent replay attacks
     *      3. Computes the EIP-712 typed data digest for signature validation
     *      4. Validates the signature using the configured validation mode
     *      5. Executes the operations on behalf of the signing account
     *
     *      Key differences from executeMultichainOps:
     *      - Uses _hashTypedData (includes chain ID) instead of _hashTypedDataSansChainId
     *      - Simpler struct (SingleChainOps) without chainIndex and otherChains fields
     *      - More gas efficient (~3.4% cheaper) due to smaller calldata and simpler hashing
     *      - Signatures are NOT valid across different chains (chain-specific)
     *
     * @param signedOps The SingleChainOps struct containing account, operations, nonce, and signature
     *
     * @custom:security The nonce consumption happens before signature validation to prevent
     *                  partial state changes in case of signature validation failure
     * @custom:gas Approximately 850 gas cheaper than executeMultichainOps due to simpler struct
     *             and hashing requirements
     */
    function executeSinglechainOps(SingleChainOps calldata signedOps) external {
        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID in the standard EIP-712 way (not chain-agnostic)
        (bytes32 hash, uint256 nonce) = signedOps.hashAndDecode(EIP712Lib.NO_GASREFUND);

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedData which includes chain ID, making signatures chain-specific
        bytes32 digest = _hashTypedData(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: signedOps.account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });
    }

    /**
     * @notice Executes single-chain operations with ERC20 token gas refund after signature validation
     * @dev Handles gas refunds in ERC20 tokens only (reverts if token is native ETH).
     *      For native ETH refunds, use executeSinglechainOpsWithGasRefund_ETH instead.
     *
     *      Gas Refund Flow:
     *      1. Compute EIP-712 hash including gasRefund commitment (with chain ID)
     *      2. Measure gas before execution (gasStart = gasleft())
     *      3. Execute operations via _checkSigAndExecute
     *      4. Calculate gas used and convert to token amount via getCostInToken
     *      5. Settle the gas refund via Paymaster (requires prior token approval)
     *
     *      Settlement Method Selection (SigMode-dependent):
     *      - Execution Emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION):
     *        Uses settleGasRefund_requireCallback. These modes involve the account executing operations
     *        via a session key. The account must pre-authorize a max refund via callback to prevent
     *        session keys from draining funds through inflated exchange rates.
     *
     *      - Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
     *        Uses settleGasRefund directly. The signature comes from the account owner,
     *        so exchange rate is trusted.
     *
     * @param signedOps The SingleChainOps struct containing account, operations, nonce, and signature
     * @param gasRefund The gas refund details (ERC20 token address and exchangeRate for conversion)
     * @param gasRefundRecipient The address that will receive the gas refund payment (typically relayer)
     * @return account The account that was executed on behalf of
     * @return nonce The nonce that was consumed during execution
     *
     * @custom:security The gas refund hash is included in the signature to prevent relayers from
     *                  modifying refund terms. The signer must explicitly authorize the gas costs.
     * @custom:security For execution emissary modes, the account must call Paymaster.callbackAllowMaxAmount
     *                  during execution to cap the refund amount, preventing exchange rate manipulation.
     * @custom:security Reverts with InvalidGasToken if gasRefund.token is Constants.NATIVE_TOKEN
     */
    function executeSinglechainOpsWithGasRefund_ERC20(
        SingleChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        nonReentrant
        returns (address account, uint256 nonce)
    {
        account = signedOps.account;

        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID in the standard EIP-712 way (not chain-agnostic)
        bytes32 hash;
        address gasToken = gasRefund.token;
        // Only ERC20 tokens are allowed
        require(gasToken != Constants.NATIVE_TOKEN, InvalidGasToken());
        uint256 exchangeRate = gasRefund.exchangeRate;
        uint256 overhead = gasRefund.overhead;
        (hash, nonce) =
            signedOps.hashAndDecode(EIP712Lib.hashGasRefund({ token: gasToken, exchangeRate: exchangeRate, overhead: overhead }));

        // Cache gas price to avoid multiple GASPRICE opcodes
        uint256 gasPrice = tx.gasprice;

        // Measure gas before execution to calculate refund amount dynamically
        uint256 gasStart = gasleft();

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedData which includes chain ID, making signatures chain-specific
        bytes32 digest = _hashTypedData(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });

        // Calculate token amount: (totalGasCost + overhead) * exchangeRate / 1e18
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasAmount = getCostInToken(gasUsed * gasPrice, gasPrice, exchangeRate, overhead);

        // Determine settlement method based on signature mode
        // Extract the SigMode from the first byte of ops.data
        SmartExecutionLib.SigMode sigMode = signedOps.ops.extractSigMode();
        if (sigMode.isExecutionEmissary()) {
            // Execution emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION)
            // are used when session keys execute operations via the account.
            // Session keys can sign intents on behalf of the account, but they could potentially
            // set a maliciously high exchangeRate to drain the account's funds as "gas refund".
            //
            // To prevent this attack, we require the account to explicitly authorize the max
            // refund amount during execution via Paymaster.callbackAllowMaxAmount(). This call
            // is part of the session key's signed operations and is validated by the session
            // key's action policies, creating defense-in-depth:
            // 1. Action policies can whitelist/restrict calls to callbackAllowMaxAmount
            // 2. The callback caps the actual refund regardless of the signed exchangeRate
            //
            // The account MUST include a call to Paymaster.callbackAllowMaxAmount in its ops
            // for this settlement to succeed.
            PAYMASTER.settleGasRefund_requireCallback(account, gasToken, gasAmount, gasRefundRecipient);
        } else {
            // Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
            // Signature comes from the account owner (not a session key)
            // The owner is trusted to set a reasonable exchangeRate, so no callback required
            PAYMASTER.settleGasRefund(account, gasToken, gasAmount, gasRefundRecipient);
        }
    }

    /**
     * @notice Executes single-chain operations with native ETH gas refund after signature validation
     * @dev Optimized variant for native ETH gas refunds with automatic 1:1 exchange rate.
     *      This function is more gas efficient than the ERC20 variant for owner signatures
     *      because it skips the Paymaster intermediary and performs a direct ETH transfer.
     *
     *      Gas Refund Flow:
     *      1. Compute EIP-712 hash with hardcoded NATIVE_TOKEN and 1e18 exchange rate (with chain ID)
     *      2. Measure gas before execution (gasStart = gasleft())
     *      3. Execute operations via _checkSigAndExecute
     *      4. Calculate ETH amount needed for gas refund
     *      5. Settlement (SigMode-dependent):
     *         - Execution emissary modes: Paymaster flow with callback protection (~30k gas)
     *         - Owner signature modes: Direct ETH transfer via executeFromExecutor (~2.8k gas)
     *
     *      Settlement Method Selection (SigMode-dependent):
     *      - Execution Emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION):
     *        Uses settleGasRefund_requireCallback. These modes involve the account executing operations
     *        via a session key. The account must pre-authorize a max refund via callback to prevent
     *        session keys from draining funds through inflated exchange rates.
     *
     *      - Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
     *        Uses direct ETH transfer via executeSingleETHTransfer for gas optimization.
     *        The signature comes from the account owner, so exchange rate is trusted.
     *
     *      Gas Optimization for Owner Signatures:
     *      Owner-signed intents bypass the Paymaster contract entirely, saving ~17-22k gas by:
     *      - Skipping Paymaster's nativeAmounts storage operations (SLOAD + SSTORE)
     *      - Avoiding intermediate transfer (account → Paymaster → recipient)
     *      - Using direct transfer (account → recipient) via executeFromExecutor
     *
     *      Session Key Security:
     *      Execution emissary modes still use the Paymaster callback flow to prevent session keys
     *      from draining accounts via inflated exchange rates. The account must call
     *      Paymaster.callbackAllowMaxAmount during execution to authorize the max refund amount,
     *      which is validated by the session key's action policies.
     *
     * @param signedOps The SingleChainOps struct containing account, operations, nonce, and signature
     * @param overhead The fixed gas overhead to add to the refund calculation (gas units)
     * @param gasRefundRecipient The address that will receive the gas refund payment (typically relayer)
     * @return account The account that was executed on behalf of
     * @return nonce The nonce that was consumed during execution
     *
     * @custom:security Exchange rate is hardcoded to 1e18 (1:1) for ETH-to-ETH conversion
     * @custom:security For execution emissary modes, the account must call Paymaster.callbackAllowMaxAmount
     *                  during execution to cap the refund amount
     * @custom:gas Owner signature modes save ~17-22k gas vs ERC20 variant by skipping Paymaster
     */
    function executeSinglechainOpsWithGasRefund_ETH(
        SingleChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        nonReentrant
        returns (address account, uint256 nonce)
    {
        account = signedOps.account;

        // Compute the EIP-712 hash and extract the nonce from the signed operations
        // The hash includes chain ID in the standard EIP-712 way (not chain-agnostic)
        bytes32 hash;
        // Hardcode NATIVE_TOKEN as token and 1:1 exchange rate for ETH refunds
        (hash, nonce) = signedOps.hashAndDecode(
            EIP712Lib.hashGasRefund({
                token: Constants.NATIVE_TOKEN,
                exchangeRate: ONE_ETHER, // 1:1 for ETH
                overhead: overhead
            })
        );

        // Cache gas price to avoid multiple GASPRICE opcodes
        uint256 gasPrice = tx.gasprice;

        // Measure gas before execution to calculate refund amount dynamically
        uint256 gasStart = gasleft();

        // Compute the EIP-712 typed data digest for signature verification
        // Uses _hashTypedData which includes chain ID, making signatures chain-specific
        bytes32 digest = _hashTypedData(hash);

        // Execute the operations after signature and nonce validation
        _checkSigAndExecute({
            account: account, nonce: nonce, hash: hash, digest: digest, ops: signedOps.ops, signature: signedOps.signature
        });

        // Calculate token amount: (totalGasCost + overhead) * exchangeRate / 1e18
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasAmount = (gasUsed + overhead) * gasPrice;

        // Determine settlement method based on signature mode
        // Extract the SigMode from the first byte of ops.data
        SmartExecutionLib.SigMode sigMode = signedOps.ops.extractSigMode();
        if (sigMode.isExecutionEmissary()) {
            // Execution emissary modes (EMISSARY_EXECUTION, EMISSARYEXECUTION_ERC1271, ERC1271_EMISSARYEXECUTION)
            // are used when session keys execute operations via the account.
            // Session keys can sign intents on behalf of the account, and for ETH refunds the
            // exchangeRate is hardcoded to 1e18 (1:1) and cannot be manipulated. The actual risk
            // is that a session key could set a maliciously high `overhead` value, inflating the
            // computed gas refund amount and draining the account's funds.
            //
            // To prevent this attack, we require the account to explicitly authorize the max
            // refund amount during execution via Paymaster.callbackAllowMaxAmount(). This call
            // is part of the session key's signed operations and is validated by the session
            // key's action policies, creating defense-in-depth:
            // 1. Action policies can whitelist/restrict calls to callbackAllowMaxAmount
            // 2. The callback caps the actual refund regardless of the signed `overhead`
            //
            // The account MUST include a call to Paymaster.callbackAllowMaxAmount in its ops
            // for this settlement to succeed.
            PAYMASTER.settleGasRefund_requireCallback(account, Constants.NATIVE_TOKEN, gasAmount, gasRefundRecipient);
        } else {
            // Other modes (EMISSARY, ERC1271, EMISSARY_ERC1271, ERC1271_EMISSARY):
            // Signature comes from the account owner (not a session key)
            // Execute a simple ETH transfer to the gas refund recipient
            LibERC7579.executeSingleETHTransfer({ account: account, target: gasRefundRecipient, value: gasAmount });
        }
    }

    /**
     * @notice Converts gas costs from wei to token amount using an exchange rate
     * @dev Formula: tokenAmount = (totalWeiCost * exchangeRate) / 1e18
     *
     *      The calculation accounts for:
     *      1. Actual execution cost: gas already consumed × gas price (passed as _actualGasCost)
     *      2. Uncaptured overhead: overhead × gas price
     *
     *      Example with concrete numbers:
     *      - _actualGasCost = 100,000 gas × 50 gwei = 5,000,000 gwei = 0.005 ETH in wei
     *      - GAS_OVERHEAD = 55,000 gas (overhead not captured by gasleft())
     *      - _actualOpFeePerGas = 50 gwei (current gas price)
     *      - _exchangeRate = 2000e6 (if 1 ETH = 2000 USDC, scaled to token decimals)
     *
     *      Result: ((0.005 ETH + 55000 × 50 gwei) × 2000e6) / 1e18 ≈ 15.5 USDC
     *
     * @param _actualGasCost The total wei spent on execution (gasUsed × tx.gasprice)
     * @param _actualOpFeePerGas The current gas price in wei (tx.gasprice)
     * @param _exchangeRate How many token units (in token decimals) equal 1 ETH (1e18 wei)
     * @param _overhead The fixed gas overhead to add (gas units not captured by gasleft measurement)
     * @return The gas cost denominated in tokens
     */
    function getCostInToken(
        uint256 _actualGasCost,
        uint256 _actualOpFeePerGas,
        uint256 _exchangeRate,
        uint256 _overhead
    )
        public
        pure
        returns (uint256)
    {
        // Total cost in wei = actual execution cost + uncaptured overhead cost
        // Token amount = (total wei cost × exchange rate) / 1e18
        return ((_actualGasCost + (_overhead * _actualOpFeePerGas)) * _exchangeRate) / 1e18;
    }

    /**
     * @notice Internal helper that validates signature and executes operations
     * @dev This function performs the core validation and execution flow:
     *      1. Consumes the nonce to prevent replay attacks (CEI pattern - checks first)
     *      2. Computes the EIP-712 typed data digest
     *      3. Validates the signature using the ValidateSignature base contract
     *      4. Executes the operations via LibERC7579
     *
     *      The signature validation mode is determined by extracting the sigMode from the ops parameter,
     *      which controls whether ERC-1271, emissary, or hybrid validation is used.
     *
     * @param account The account that should have authorized the operations
     * @param nonce The nonce to consume for replay protection
     * @param hash The EIP-712 struct hash (before domain separator wrapping)
     * @param digest The EIP-712 typed data digest (with domain separator)
     * @param ops The operation to execute, containing signature mode and execution data
     * @param signature The signature bytes to validate
     *
     * @custom:security Nonce consumption happens before signature validation following CEI pattern
     */
    function _checkSigAndExecute(
        address account,
        uint256 nonce,
        bytes32 hash,
        bytes32 digest,
        Types.Operation calldata ops,
        bytes calldata signature
    )
        internal
    {
        // Consume the nonce immediately to prevent replay attacks
        // This modifies storage before signature validation for security
        nonce.standaloneNonceSlot(account).consumeNonce();

        // Verify the execution signature using the execution signature checker
        require(_isValidSignature(account, LOCKTAG, digest, hash, ops, signature), InvalidSignature());

        // Execute the operations on behalf of the validated account
        LibERC7579.executeOps(account, ops);

        emit IntentExecuted(account, nonce);
    }

    /**
     * @notice Checks if a nonce has been used for a specific account
     * @dev This function provides a clean way to check nonce usage without relying on low-level storage access
     * @param nonce The nonce value to check
     * @param account The account address that owns the nonce
     * @return used True if the nonce has been consumed, false otherwise
     */
    function isStandaloneIntentNonceConsumed(uint256 nonce, address account) external view returns (bool used) {
        return nonce.standaloneNonceSlot(account).isConsumed();
    }

    /**
     * @notice Provides the EIP-712 domain name and version for signature validation
     * @dev These values are used in the EIP-712 domain separator computation and must remain
     *      constant to ensure signature compatibility across deployments
     * @return name The domain name used in EIP-712 signatures ("IntentExecutor")
     * @return version The version string used in EIP-712 signatures ("v0.0.1")
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "IntentExecutor";
        version = "v0.0.1";
    }
}
