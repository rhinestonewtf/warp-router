import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";

contract MockSimpleAccount is Ownable {
    using SignatureCheckerLib for address;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    function execute(
        Execution[] calldata executions,
        bytes calldata /* signature */
    )
        external
    {
        for (uint256 i; i < executions.length; i++) {
            Execution calldata execution = executions[i];

            (bool success,) = execution.target.call{ value: execution.value }(execution.callData);
            require(success, "MockSimpleAccount Execution failed");
        }
    }

    function executeOne(address target, bytes calldata callData, bytes calldata sig) external {
        bytes32 hash = keccak256(abi.encode(target, callData));
        address signer = owner();
        require(signer.isValidSignatureNowCalldata(hash, sig), "Invalid signature");
        (bool success,) = target.call{ value: 0 }(callData);
        require(success, "MockSimpleAccount Execution failed");
    }

    function executeFromExecutor(
        bytes32,
        /* executionHash */
        bytes calldata executionCalldata
    )
        external
    {
        // Debug: log the raw execution calldata to understand the format
        // Based on the trace, it looks like the executionCalldata is already the full calldata for the target
        // The first 20 bytes might not be the target address as expected

        // Let's try a different approach - the executionCalldata might be the full encoded call
        // If the target is 'this' (the account itself), we should execute the calldata directly

        // Extract potential target (first 20 bytes)
        address target = address(bytes20(executionCalldata[0:20]));

        // If target is this contract, execute the remaining calldata on this contract
        if (target == address(this)) {
            // The remaining calldata should be the function call
            bytes calldata functionCall = executionCalldata[20:];
            (bool success,) = address(this).call(functionCall);
            require(success, "MockSimpleAccount Execution failed");
        } else {
            // Otherwise, treat as external call
            bytes calldata callData = executionCalldata[20:];
            (bool success,) = target.call{ value: 0 }(callData);
            require(success, "MockSimpleAccount Execution failed");
        }
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        address signer = owner();
        if (signer.isValidSignatureNow(hash, signature)) {
            return 0x1626ba7e; // ERC-1271 magic value for valid signature
        } else {
            return 0x00000000; // Invalid signature
        }
    }
}
