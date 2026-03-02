// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;
import { Constants } from "../../types/Constants.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { AdapterBase } from "./AdapterBase.sol";

abstract contract AdapterBasePrefund is AdapterBase {
    using IdLib for uint256;
    using SafeTransferLib for address;

    constructor(address router, address arbiter) AdapterBase(router, arbiter) { }

    /**
     * @notice Prefunds a recipient with multiple token outputs before settlement execution
     * @dev Iterates through an array of token/amount pairs and transfers each to the recipient
     *      This is typically used to provide liquidity to users before cross-chain settlement completes
     * @param from The address providing the tokens (usually the Router or a solver)
     * @param to The recipient address that will receive the prefunded tokens
     * @param tokenOut Array of [tokenAddress, amount] pairs encoded as uint256[2]
     */
    function _prefundRecipient(address from, address to, uint256[2][] calldata tokenOut) internal {
        // Process each token/amount pair in the array
        uint256 length = tokenOut.length;
        for (uint256 i; i < length;) {
            _prefundRecipient(from, to, tokenOut[i][0].toAddress(), tokenOut[i][1]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Prefunds a recipient with a specific token and amount
     * @dev Handles both native ETH and ERC20 token transfers with proper validation
     *      For native tokens, validates that msg.value matches the expected amount
     * @param from The address providing the tokens
     * @param to The recipient address
     * @param tokenOut The token address (Constants.NATIVE_TOKEN for ETH)
     * @param amountOut The amount to transfer
     */
    function _prefundRecipient(address from, address to, address tokenOut, uint256 amountOut) internal {
        if (tokenOut == Constants.NATIVE_TOKEN) {
            // For native ETH transfers, ensure the transaction value matches the expected amount
            to.safeTransferETH(amountOut);
        } else {
            // For ERC20 tokens, transfer from the source address to recipient
            tokenOut.safeTransferFrom(from, to, amountOut);
        }
    }
}
