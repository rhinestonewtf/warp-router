// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IdLib } from "the-compact/lib/IdLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title FeeCollector
 * @notice Contract for collecting fees from relayers during fill operations
 * @dev Fees are collected by relayers on fills and are expected to be priced into
 *      the user's intent pricing if fees are user-facing. This contract provides
 *      the core functionality for distributing fees to multiple recipients.
 */
contract FeeCollector {
    using SafeTransferLib for address;
    using IdLib for uint256;

    /**
     * @notice Structure representing a fee collection with token and recipient details
     * @param token The ERC20 token address to collect fees in
     * @param recipientsAndAmount Array of [recipient, amount] pairs for fee distribution
     */
    struct Fee {
        address recipient;
        uint256[2][] tokenAndAmounts;
    }

    /**
     * @notice Collects fees from the sender and distributes them to specified recipients
     * @dev Transfers tokens from msg.sender to multiple recipients as specified in the fee structure.
     *      Relayers are expected to have already received tokens from users and this function
     *      distributes the fee portion to the intended recipients.
     * @param fee The fee structure containing token address and recipient/amount pairs
     */
    function _collectFee(Fee calldata fee) internal virtual {
        _collectFee(fee.recipient, fee.tokenAndAmounts);
    }

    /**
     * @notice Collects fees with separated parameters (for direct calldata manipulation)
     * @param recipient The address to receive the fees
     * @param tokenAndAmounts Array of [token, amount] pairs for fee distribution
     */
    function _collectFee(address recipient, uint256[2][] calldata tokenAndAmounts) internal virtual {
        address relayer = msg.sender;

        // Iterate through all token/amount pairs and transfer fees
        uint256 length = tokenAndAmounts.length;
        for (uint256 i; i < length;) {
            // Convert packed address from uint256 to address using IdLib
            address token = tokenAndAmounts[i][0].toAddress();
            uint256 amount = tokenAndAmounts[i][1];

            // Transfer fee from sender (relayer) to recipient using safe transfer
            // This assumes the relayer has already received tokens from the user
            token.safeTransferFrom(relayer, recipient, amount);

            unchecked {
                ++i;
            }
        }
    }

    function _collectFee(Fee[] calldata fees) internal virtual {
        uint256 length = fees.length;
        for (uint256 i; i < length; i++) {
            _collectFee(fees[i]);
        }
    }
}
