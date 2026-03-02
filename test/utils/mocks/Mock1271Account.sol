// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Interfaces
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

// Types
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

// Simple mock for an account that implements EIP-1271
contract Mock1271Account is IERC1271 {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    bool public sigIsValid;

    constructor(bool _isValid) {
        sigIsValid = _isValid;
    }

    function isValidSignature(bytes32, bytes memory) external view override returns (bytes4) {
        return sigIsValid ? MAGICVALUE : bytes4(0xffffffff);
    }

    function setSigIsValid(bool _isValid) external {
        sigIsValid = _isValid;
    }

    function executeFromExecutor(
        bytes32,
        /* executionHash */
        bytes calldata executionCalldata
    )
        external
    {
        // Execution[] memory executions = new Execution[](2);
        // executions[0] =
        // Execution({ target: address(tokenC), value: 0, callData: abi.encodeCall(IERC20.approve, (address(target), 50 ether)) });
        // executions[1] = Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (12_345)) });

        // Decode the executionCalldata to extract target and callData
        Execution[] memory executions = abi.decode(executionCalldata, (Execution[]));

        for (uint256 i; i < executions.length; i++) {
            Execution memory execution = executions[i];

            (bool success,) = execution.target.call{ value: execution.value }(execution.callData);
            require(success, "Mock1271Account Execution failed");
        }
    }
}
