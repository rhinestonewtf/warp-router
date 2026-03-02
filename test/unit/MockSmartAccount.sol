// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

// Simple mock smart account that can execute operations
contract MockSmartAccount {
    event Executed(address target, uint256 value, bytes data);

    // ERC7579 executeFromExecutor function
    function executeFromExecutor(bytes32 mode, bytes calldata executionCalldata) external returns (bytes[] memory) {
        // For single execution (mode = 0x00...), the data is packed: target (20 bytes) + value (32 bytes) + calldata
        // For batch execution (mode = 0x01...), it's encoded as an array

        // Check the first byte of mode to determine single vs batch
        uint8 modeType = uint8(uint256(mode) >> 248);

        if (modeType == 0x00) {
            // Single execution mode - packed format
            address target = address(bytes20(executionCalldata[0:20]));
            uint256 value = uint256(bytes32(executionCalldata[20:52]));
            bytes memory callData = executionCalldata[52:];

            (bool success, bytes memory result) = target.call{ value: value }(callData);
            require(success, "Execution failed");
            emit Executed(target, value, callData);

            bytes[] memory results = new bytes[](1);
            results[0] = result;
            return results;
        } else {
            // Batch execution mode
            Execution[] memory executions = abi.decode(executionCalldata, (Execution[]));

            bytes[] memory results = new bytes[](executions.length);

            for (uint256 i = 0; i < executions.length; i++) {
                (bool success, bytes memory result) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
                require(success, "Execution failed");
                results[i] = result;
                emit Executed(executions[i].target, executions[i].value, executions[i].callData);
            }

            return results;
        }
    }

    // Allow receiving ETH
    receive() external payable { }
}
