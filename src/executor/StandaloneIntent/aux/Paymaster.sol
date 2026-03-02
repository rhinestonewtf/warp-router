// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

/**
 * @title Paymaster
 * @author Rhinestone
 * @notice Manages gas refunds for intent execution by holding ETH deposits and settling refunds
 * @dev This contract acts as an escrow for native ETH used in gas refunds during intent execution.
 *      Users deposit ETH via the receive() function, and the IntentExecutor settles refunds after
 *      executing operations. The contract uses forceSafeTransferETH with gas stipends to prevent
 *      griefing attacks where malicious recipients could consume all gas or revert transactions.
 *
 * @custom:security Critical invariant: nativeAmounts[account] MUST always be zero after settleGasRefund
 *                  completes for native token refunds. This prevents double-spending and ensures
 *                  proper accounting of deposited funds.
 */
contract Paymaster {
    using SafeTransferLib for address;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Thrown when an account has insufficient ETH deposited to cover the requested refund
    error InsufficientETHDeposit();

    /// @dev Thrown when a caller other than the INTENT_EXECUTOR attempts to settle gas refunds
    error Unauthorized();

    /* //////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IntentExecutor contract authorized to settle gas refunds
    /// @dev Only this address can call settleGasRefund to prevent unauthorized withdrawals
    address public immutable INTENT_EXECUTOR;

    /// @notice Tracks native ETH deposits for each account
    /// @dev Maps account addresses to their deposited ETH balance available for gas refunds
    ///      This balance is zeroed out after each settlement to maintain the critical invariant
    mapping(address depositor => uint256 amount) internal nativeAmounts;

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the Paymaster with the authorized IntentExecutor
     * @dev Handles edge case where ETH is sent to the contract's counterfactual address before deployment.
     *      This can happen with CREATE2 deterministic deployments where the address is known in advance.
     *
     * @param intentExecutor The address of the IntentExecutor contract that can settle refunds
     * @param deployer The address to receive any ETH that was sent to the counterfactual address pre-deployment
     *
     * @custom:security The deployer parameter prevents using tx.origin (which would be vulnerable to front-running).
     *                  If deployer is a contract, it MUST have receive()/fallback() or deployment will revert.
     */
    constructor(address intentExecutor, address deployer) {
        INTENT_EXECUTOR = intentExecutor;

        // Check if ETH was sent to this contract's counterfactual address before deployment
        // This can occur with CREATE2 when users know the address in advance
        uint256 balance = address(this).balance;
        if (balance != 0) {
            // Return any pre-funded ETH to the specified deployer address
            // Note: This will revert if deployer is a contract without receive()/fallback()
            // The deployer parameter is used instead of tx.origin to prevent front-running attacks
            deployer.safeTransferETH(balance);
        }
    }

    /* //////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to only the INTENT_EXECUTOR
     * @dev Prevents unauthorized settlement of gas refunds
     */
    modifier onlyAuthorized() {
        require(msg.sender == INTENT_EXECUTOR, Unauthorized());
        _;
    }

    /* //////////////////////////////////////////////////////////////
                          SETTLEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes a maximum gas refund amount for the caller via transient storage
     * @dev This function enables a callback-based authorization pattern where:
     *      1. The account calls this function to pre-authorize a maximum refund amount
     *      2. The IntentExecutor executes operations on behalf of the account
     *      3. settleGasRefund_requireCallback verifies the authorization before settling
     *
     *      Uses EIP-1153 transient storage (TSTORE) which:
     *      - Automatically clears at the end of the transaction
     *      - Is cheaper than regular storage (~100 gas vs ~20000 gas for cold SSTORE)
     *      - Prevents cross-transaction authorization exploits
     *
     *      This pattern is critical for EMISSARY_EXECUTION mode (SigMode.EMISSARY_EXECUTION)
     *      where the account executes operations itself rather than delegating to the executor.
     *
     *      Security rationale - Exchange Rate Attack Prevention:
     *      Without this callback mechanism, a malicious session key could set an arbitrarily
     *      high exchangeRate in the GasRefund struct, draining the account's tokens far beyond
     *      actual gas costs. The callback allows the account itself to cap the maximum refund
     *      amount during execution, ensuring the session key cannot inflate the exchange rate
     *      to steal funds.
     *
     *      Example attack without callback:
     *      - Session key signs intent with exchangeRate = 1000000e18 (1M tokens per wei of gas)
     *      - Actual gas cost = 100k gas * 50 gwei = 5e15 wei
     *      - Attacker drains: 5e15 * 1000000e18 / 1e18 = 5e33 tokens (entire balance)
     *
     *      With callback protection:
     *      - Account sets maxAmount = 1e18 (1 token max)
     *      - Even with inflated exchangeRate, refund is capped at 1 token
     *
     *      Integration with Session Key Action Policies:
     *      Since callbackAllowMaxAmount is called by the account during EMISSARY_EXECUTION mode,
     *      the call originates from the session key's signed operations. This means the call to
     *      this function is validated by the session key's action policies, allowing policy
     *      enforcers to:
     *      - Whitelist this Paymaster address as an allowed target
     *      - Restrict which tokens can be used for gas refunds
     *      - Set upper bounds on maxAmount via policy parameters
     *      - Rate-limit how often gas refunds can be authorized
     *
     *      This creates a defense-in-depth approach where both the callback mechanism AND
     *      action policies work together to protect against exchange rate manipulation.
     *
     * @param token The token address for the gas refund (use Constants.NATIVE_TOKEN for ETH)
     * @param maxAmount The maximum amount the caller authorizes for gas refund settlement
     *
     * @custom:payable If ETH is sent with this call (msg.value > 0), it will be deposited into
     *                 the caller's native balance. This allows combining deposit + authorization
     *                 in a single call for native ETH gas refunds. Reverts if ETH is sent but
     *                 token != Constants.NATIVE_TOKEN.
     * @custom:security The authorization is scoped to (msg.sender, token) and stored in transient
     *                  storage, making it valid only within the current transaction
     */
    function callbackAllowMaxAmount(address token, uint256 maxAmount) external payable {
        // Cache msg.value and msg.sender to save gas on repeated access
        uint256 msgValue = msg.value;
        address account = msg.sender;

        // Native ETH deposit handling:
        // If ETH is sent with this call, deposit it into the account's native balance.
        // This allows combining authorization + deposit in a single call, which is useful
        // when the account wants to pay gas refunds in native ETH and needs to fund
        // the Paymaster in the same transaction as authorizing the refund.
        if (msgValue != 0) {
            // Sanity check: only accept ETH if the token being authorized is native ETH
            // This prevents accidentally sending ETH when authorizing an ERC20 refund
            require(token == Constants.NATIVE_TOKEN);
            // Credit the deposited ETH to the account's balance
            // This is equivalent to calling receive() but more gas efficient in a single tx
            nativeAmounts[account] += msgValue;
        }

        // Compute the unique slot for this (account, token) pair
        bytes32 slot = _callbackSlot({ account: account, token: token });
        // Store the max authorized amount in transient storage
        // TSTORE is used because authorization should only be valid within this transaction
        assembly {
            tstore(slot, maxAmount)
        }
    }

    /**
     * @notice Computes a unique transient storage slot for callback authorization
     * @dev Generates a deterministic slot by hashing the account and token addresses together.
     *      This ensures each (account, token) pair has its own isolated storage slot,
     *      preventing collisions between different accounts or tokens.
     *
     * @param account The account address that authorized the callback
     * @param token The token address for which the authorization applies
     * @return hash The keccak256 hash used as the transient storage slot
     *
     * @custom:gas Uses scratch space (0x00-0x40) for memory efficiency - no memory expansion needed
     */
    function _callbackSlot(address account, address token) internal pure returns (bytes32 hash) {
        assembly {
            // Use scratch space for efficient hashing (no memory allocation needed)
            mstore(0x00, account) // Store account at memory position 0x00
            mstore(0x20, token) // Store token at memory position 0x20
            hash := keccak256(0x00, 0x40) // Hash both values (64 bytes total)
        }
    }

    /**
     * @notice Settles gas refunds by transferring tokens from account to recipient
     * @dev This function handles both native ETH and ERC20 token refunds with different logic:
     *
     *      For native ETH (token == Constants.NATIVE_TOKEN):
     *      1. Retrieves the account's deposited balance
     *      2. IMMEDIATELY zeros the balance (CEI pattern - prevents reentrancy)
     *      3. Validates sufficient funds are available
     *      4. Calculates and refunds any excess ETH back to the account
     *      5. Transfers the refund amount to the recipient
     *      6. Uses forceSafeTransferETH with GAS_STIPEND_NO_GRIEF to prevent:
     *         - Griefing attacks where recipient consumes all gas
     *         - Transaction failures due to recipient revert
     *         - Ensures refunds complete even if recipient is a contract without receive()
     *
     *      For ERC20 tokens:
     *      - Transfers directly from the account (requires prior approval)
     *
     * @param account The account that deposited funds and will receive any excess refund
     * @param token The token address to refund (address(0) for native ETH per Constants.NATIVE_TOKEN)
     * @param amount The amount to refund to the recipient (gas cost)
     * @param recipient The address receiving the gas refund (typically the relayer/executor)
     *
     * @custom:security Uses forceSafeTransferETH to prevent DoS attacks and ensure transactions complete
     * @custom:invariant After native token settlement, nativeAmounts[account] MUST be zero
     */
    function settleGasRefund(address account, address token, uint256 amount, address recipient) external onlyAuthorized {
        _settleGasRefund(account, token, amount, recipient);
    }

    /**
     * @notice Settles gas refunds with callback authorization verification
     * @dev This function adds an authorization check on top of the standard settleGasRefund flow.
     *      It is used when the account has pre-authorized a maximum refund amount via callbackAllowMaxAmount.
     *
     *      Authorization flow:
     *      1. Load the pre-authorized maxAmount from transient storage
     *      2. Clear the authorization immediately (single-use pattern)
     *      3. Verify the requested amount does not exceed the authorization
     *      4. Proceed with the standard gas refund settlement
     *
     *      This pattern is essential for EMISSARY_EXECUTION mode where:
     *      - The account executes operations itself (not via executeFromExecutor)
     *      - The account wants to cap the gas refund that can be claimed
     *      - The IntentExecutor needs proof that the account consented to the refund
     *
     *      The authorization is consumed (cleared) regardless of the settlement outcome,
     *      preventing replay attacks within the same transaction.
     *
     * @param account The account that pre-authorized the refund and will pay the gas cost
     * @param token The token address to refund (address(0) for native ETH per Constants.NATIVE_TOKEN)
     * @param amount The actual gas cost to refund (must be <= pre-authorized maxAmount)
     * @param recipient The address receiving the gas refund (typically the relayer/executor)
     *
     * @custom:security Authorization is cleared BEFORE validation to prevent reentrancy exploits
     * @custom:security Uses TLOAD/TSTORE for gas-efficient, transaction-scoped authorization
     */
    function settleGasRefund_requireCallback(address account, address token, uint256 amount, address recipient) external onlyAuthorized {
        // Compute the transient storage slot for this (account, token) pair
        bytes32 slot = _callbackSlot({ account: account, token: token });
        uint256 maxAmount;
        assembly {
            // Load the pre-authorized maximum amount from transient storage
            maxAmount := tload(slot)
            // CRITICAL: Clear the authorization immediately (CEI pattern)
            // This ensures single-use authorization and prevents reentrancy exploits
            tstore(slot, 0)
        }

        // Verify the requested amount does not exceed the pre-authorized maximum
        // Reverts with Unauthorized if the account did not authorize this amount
        require(maxAmount >= amount, Unauthorized());

        // Proceed with the standard gas refund settlement
        _settleGasRefund(account, token, amount, recipient);
    }

    /**
     * @notice Internal implementation for settling gas refunds
     * @dev Handles the actual token transfer logic for both native ETH and ERC20 tokens.
     *      This function is called by both settleGasRefund and settleGasRefund_requireCallback.
     *
     * @param account The account paying for gas (source of funds)
     * @param token The token to transfer (Constants.NATIVE_TOKEN for ETH, otherwise ERC20)
     * @param amount The amount to transfer to the recipient
     * @param recipient The address receiving the gas refund
     */
    function _settleGasRefund(address account, address token, uint256 amount, address recipient) internal {
        // Early return for zero amount to save gas
        if (amount == 0) return;

        if (token == Constants.NATIVE_TOKEN) {
            // Load the available balance before zeroing (saves gas vs multiple SLOADs)
            uint256 available = nativeAmounts[account];

            // CEI Pattern: Zero balance BEFORE external calls to prevent reentrancy
            // CRITICAL INVARIANT: This ensures nativeAmounts[account] is always 0 after settlement
            nativeAmounts[account] = 0;

            // Validate sufficient funds AFTER zeroing (balance is cached in `available`)
            require(available >= amount, InsufficientETHDeposit());

            // Calculate excess to refund back to the account
            available -= amount;

            // Refund excess ETH back to account (if any)
            // Uses forceSafeTransferETH to prevent account from blocking refunds
            _refundAccount(account, available);

            // Transfer gas refund to recipient with gas stipend protection
            // GAS_STIPEND_NO_GRIEF (100k gas) prevents recipient from griefing
            // forceSafeTransferETH ensures delivery even if recipient reverts
            recipient.forceSafeTransferETH(amount);
        } else {
            // For ERC20 tokens, transfer directly from account to recipient
            // Requires account to have approved this Paymaster contract
            token.safeTransferFrom(account, recipient, amount);
        }
    }

    /**
     * @notice Internal helper to refund excess ETH back to the account
     * @dev Uses forceSafeTransferETH with gas stipend to prevent the account from blocking
     *      their own refund by reverting in receive()/fallback()
     * @param account The account receiving the excess ETH refund
     * @param amount The amount of excess ETH to refund
     */
    function _refundAccount(address account, uint256 amount) internal {
        if (amount > 0) {
            // Use forceSafeTransferETH to guarantee delivery even if account reverts
            // This prevents accounts from griefing themselves or blocking settlements
            account.forceSafeTransferETH(amount, SafeTransferLib.GAS_STIPEND_NO_GRIEF);
        }
    }

    /* //////////////////////////////////////////////////////////////
                          DEPOSIT MECHANISM
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receives ETH deposits and credits them to the sender's balance
     * @dev Users deposit ETH by sending it directly to this contract
     *      The deposited amount is tracked in nativeAmounts and can be used for gas refunds
     */
    receive() external payable {
        nativeAmounts[msg.sender] += msg.value;
    }
}
