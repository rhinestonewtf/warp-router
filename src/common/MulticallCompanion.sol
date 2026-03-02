// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { IWETH } from "@rhinestone/compact-utils/src/interfaces/IWETH.sol";

/**
 * @title MulticallCompanion
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice An abstract base contract for handling multicalls
 */
abstract contract MulticallCompanion is ReentrancyGuardTransient {
    // Enable SafeTransferLib for address type to safely hand le ERC20 transfers.
    using SafeTransferLib for address;

    // Custom error definitions for various failure conditions.
    // / @notice Thrown if a function call is not authorized.
    error Unauthorized();
    /// @notice Thrown if a function intended for self-call is called by an external address.
    error NotSelf();

    /// @notice Thrown when one of the calls in a multicall batch fails.
    error ExecutionFailed();

    // Event definitions for logging important actions.
    // / @notice Emitted when leftover tokens are drained and sent to a fallback recipient.
    // / @param recipient The address that received the drained tokens.
    // / @param token The address of the token that was drained.
    // / @param amount The amount of tokens drained.
    event DrainedTokens(address indexed recipient, address indexed token, uint256 indexed amount);

    function _weth() internal view virtual returns (address);

    /**
     * @dev Modifier to ensure only the contract itself can call the function.
     *      This is crucial for functions that are part of a controlled multi-call execution
     *      and should not be directly callable by external users.
     */
    modifier onlySelf() {
        _requireSelf(); // Call the internal helper function to check the caller.
        _; // Continue with the function execution.
    }

    /**
     * @dev Internal function to ensure the caller of the current function is this contract itself.
     *      This is a security mechanism to prevent unauthorized external calls to functions that
     *      are designed to be part of an internal, controlled execution flow (e.g., within a
     * multicall).
     */
    function _requireSelf() internal view {
        // Revert if the message sender is not the address of this contract.
        // This ensures that certain sensitive operations can only be triggered by the contract's
        // own logic, often as part of a multi-step process initiated by a depositor.
        if (msg.sender != address(this)) revert NotSelf();
    }

    /**
     * @dev Internal function to drain remaining tokens (ERC20 or native Ether) to a specified
     * destination.
     *      This function is crucial for cleaning up any residual tokens that might be left in the
     * contract
     *      after an operation, preventing them from being locked or stolen.
     * @param token The address of the token to drain. If `address(0x0)` (Constants.NATIVE_TOKEN),
     * native Ether will be drained.
     * @param destination The address to send the drained tokens to.
     */
    function _drainRemainingToken(address token, address destination) internal {
        // Check if the token is an ERC20 token by comparing its address with Constants.NATIVE_TOKEN
        // (address(0)).
        if (token != Constants.NATIVE_TOKEN) {
            // Case: ERC20 token.
            // Get the current balance of the ERC20 token held by this contract.
            uint256 amount = IERC20(token).balanceOf(address(this));
            // If there's a positive amount, transfer it to the destination.
            if (amount > 0) {
                // Safely transfer the ERC20 tokens using SafeTransferLib.
                token.safeTransfer(destination, amount);
                // Emit an event indicating that the tokens were drained, for off-chain monitoring.
                emit DrainedTokens(destination, token, amount);
            }
        } else {
            // Case: Native token (ETH).
            // Get the current native Ether balance of this contract.
            uint256 amount = address(this).balance;
            // If there's a positive amount, transfer it to the destination.
            if (amount > 0) {
                // Safely transfer native Ether using SafeTransferLib's `safeTransferETH`.
                destination.safeTransferETH(amount);
            }
        }
    }

    /**
     * @notice Drains a list of leftover tokens from this contract to a specified destination.
     * @dev This function can only be called by the contract itself, typically as part of a
     * multicall.
     *      It iterates through the provided array of token addresses and calls
     * `_drainRemainingToken` for each.
     * @param tokens An array of token addresses to drain. This can include `address(0)` for native
     * Ether.
     * @param destination The address to send all the drained tokens to.
     */
    function _drainLeftoverTokens(address[] calldata tokens, address destination) internal {
        uint256 length = tokens.length;
        // Iterate through each token in the provided array.
        for (uint256 i; i < length;) {
            // Call the internal helper function to drain each token.
            _drainRemainingToken(tokens[i], destination);
            unchecked {
                ++i;
            }
        }
    }

    function drainLeftoverTokens(address[] calldata tokens, address destination)
        external
        onlySelf // Enforce that only the contract itself can call this.

    {
        _drainLeftoverTokens(tokens, destination);
    }

    /**
     * @notice Drains a single leftover token from this contract to a specified destination.
     * @dev This function can only be called by the contract itself, typically as part of a
     * multicall.
     *      It delegates the draining logic to `_drainRemainingToken`.
     * @param token The address of the token to drain. If `address(0)`, native tokens (ETH) will be
     * drained.
     * @param destination The address to send the drained tokens to.
     */
    function drainLeftoverToken(address token, address destination) external onlySelf {
        // Delegate to the internal helper function for draining a single token.
        _drainRemainingToken(token, destination);
    }

    /**
     * @notice Withdraws a specified amount of WETH (Wrapped Ether) and sends the corresponding
     * Ether to a recipient.
     * @dev This function can only be called by the contract itself. It first unwraps WETH to ETH
     *      and then transfers the ETH to the `recipient`.
     * @param recipient The address to which the unwrapped Ether will be sent.
     * @param amount The amount of WETH to withdraw and convert to Ether.
     */
    function withdrawWETH(address recipient, uint256 amount) external onlySelf {
        // Unwrap the specified amount of WETH into native Ether.
        // Assumes `WETH` is an instance of `IWETH` and has a `withdraw` function.
        IWETH(_weth()).withdraw(amount);
        // Safely transfer the unwrapped Ether to the designated recipient.
        recipient.safeTransferETH(amount);
    }

    /**
     * @notice Withdraws all WETH (Wrapped Ether) held by this contract and sends the corresponding
     * Ether to a recipient.
     * @dev This function can only be called by the contract itself. It retrieves the contract's
     * entire
     *      WETH balance, unwraps it to ETH, and then transfers all the ETH to the `recipient`.
     * @param recipient The address to which all unwrapped Ether will be sent.
     */
    function withdrawAllWETH(address recipient) external onlySelf {
        IWETH weth = IWETH(_weth());
        // Get the current WETH balance of this contract.
        uint256 amount = weth.balanceOf(address(this));
        // Unwrap the entire WETH balance into native Ether.
        weth.withdraw(amount);
        // Safely transfer all unwrapped Ether to the designated recipient.
        recipient.safeTransferETH(amount);
    }

    function _multiCall(Execution[] calldata executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            Execution calldata exec = executions[i];
            _singleCall(exec.target, exec.value, exec.callData);
        }
    }

    function _singleCall(address target, uint256 value, bytes calldata callData) internal {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)
            let callDataLength := callData.length

            // Copy calldata to memory
            calldatacopy(ptr, callData.offset, callDataLength)

            // Make the call
            let success :=
                call(
                    gas(), // Forward all gas
                    target, // Target address
                    value, // Ether value
                    ptr, // Input data location
                    callDataLength, // Input data size
                    0, // Output data location (we don't need return data)
                    0 // Output data size
                )

            // Revert if call failed
            if iszero(success) {
                // Store error selector for ExecutionFailed()
                mstore(0x00, 0x8e0242e1)
                revert(0x00, 0x04)
            }
        }
    }

    /**
     * @notice Fallback function to receive native tokens (ETH).
     * @dev This `receive` function allows the contract to accept incoming Ether.
     *      It is marked `external payable` to enable direct Ether transfers to this contract.
     *      This is particularly useful if the caller intends to unwrap native tokens to this
     * contract.
     */
    receive() external payable { }

    function _useTransientReentrancyGuardOnlyOnMainnet() internal pure override returns (bool) {
        return false;
    }
}
