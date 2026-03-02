// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IArbiter } from "@rhinestone/compact-utils/src/interfaces/IArbiter.sol";

interface ISingleCaller {
    function singleCall(address target, bytes calldata callData) external;
}

contract SingleCaller {
    /**
     * @notice Fallback function that extracts target address from calldata and forwards the call.
     * @dev Uses assembly for gas efficiency. Expects calldata format: [target(20 bytes)][callData(...)]
     *      The first 20 bytes of calldata are treated as the target address,
     *      and the remaining bytes are forwarded as calldata to the target.
     *      Reverts if the forwarded call fails.
     */
    fallback() external payable {
        assembly {
            // Load target address from the first 20 bytes of calldata
            let target := shr(96, calldataload(0))

            // Calculate calldata length after target (i.e., total - 20)
            let dataOffset := 20
            let dataLength := sub(calldatasize(), dataOffset)

            // Copy the rest of calldata (actual callData) into memory
            calldatacopy(0x00, dataOffset, dataLength)

            // Perform the call
            let success := call(gas(), target, 0, 0x00, dataLength, 0x00, 0)

            // Revert if failed
            if iszero(success) { revert(0x00, 0) }

            // Return nothing
            return(0x00, 0)
        }
    }
}

/**
 * @title MultiCall
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice A simple contract that provides a `multiCall` function to execute a batch of transactions.
 *         It ensures that it can only be called by a designated Router, making it a secure, internal utility.
 */
contract MultiCaller {
    using IdLib for uint256;
    using SafeTransferLib for address;

    /// @notice Thrown when a function is called by an unauthorized address.
    error Unauthorized();
    /// @notice Thrown when one of the calls in a multicall batch fails.
    error ExecutionFailed();

    error WithdrawFailed();

    /**
     * @notice Executes a batch of calls.
     * @param executions An array of `Execution` structs, each containing a target, value, and callData.
     */
    function multiCall(Execution[] calldata executions) external payable {
        // Ensure that the caller is the authorized router.
        // Iterate through and execute each call in the batch.
        for (uint256 i = 0; i < executions.length; i++) {
            Execution calldata exec = executions[i];
            (bool success,) = exec.target.call{ value: exec.value }(exec.callData);
            // Revert the entire transaction if any call fails.
            require(success, ExecutionFailed());
        }
    }

    /**
     * @notice Executes a batch of calls.
     * @param executions An array of `Execution` structs, each containing a target, value, and callData.
     */
    function multiCallWithDrainToken(
        Execution[] calldata executions,
        uint256[2][] calldata tokenAndAmounts,
        address recipient
    )
        external
        payable
    {
        // Iterate through and execute each call in the batch.
        for (uint256 i = 0; i < executions.length; i++) {
            Execution calldata exec = executions[i];
            (bool success,) = exec.target.call{ value: exec.value }(exec.callData);
            // Revert the entire transaction if any call fails.
            require(success, ExecutionFailed());
        }
        _withdrawApprovedTokens(tokenAndAmounts, recipient);
    }

    /**
     * @notice Internal function to withdraw approved tokens to a recipient address.
     * @dev Handles both native ETH and ERC20 token transfers.
     *      For native ETH, ensures contract balance is sufficient.
     *      For ERC20 tokens, transfers from contract to recipient.
     * @param tokenAndAmounts Array of [tokenAddress, amount] pairs to withdraw
     * @param recipient Address to receive the withdrawn tokens
     */
    function _withdrawApprovedTokens(uint256[2][] calldata tokenAndAmounts, address recipient) internal {
        uint256 length = tokenAndAmounts.length;
        for (uint256 i; i < length; i++) {
            address token = tokenAndAmounts[i][0].toAddress();
            uint256 amount = tokenAndAmounts[i][1];
            if (token == Constants.NATIVE_TOKEN) {
                // For native ETH transfers, ensure the contract has sufficient balance
                require(amount <= address(this).balance, WithdrawFailed());
                recipient.safeTransferETH(amount);
            } else {
                // For ERC20 tokens, transfer from the source address to recipient
                token.safeTransfer(recipient, amount);
            }
        }
    }

    receive() external payable { }
}

contract Caller is SingleCaller, MultiCaller, IArbiter {
    function isContractDeployed(address addr) external view returns (bool) {
        return addr.code.length != 0;
    }

    function supportsInterface(bytes4 selector) public pure virtual returns (bool) {
        return selector == this.supportsInterface.selector || selector == type(IArbiter).interfaceId;
    }
}
