import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/arbiters/samechain/SameChainAdapter.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Caller, MultiCaller, ISingleCaller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

contract SimpleCallAdapterTest is CompactEnvironment {
    MockTarget public target;

    function setUp() public {
        _deployCompact();
        target = new MockTarget();
    }

    function test_simpleCall() public {
        // Use singleCall to call targetFn
        bytes memory targetCall = abi.encodeCall(MockTarget.targetFn, (42));

        // Pass empty arrays since singleCall doesn't consume solver contexts
        bytes[] memory emptyContexts = new bytes[](0);
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = abi.encodePacked(ISingleCaller.singleCall.selector, address(target), targetCall);

        _fill(block.chainid, emptyContexts, adapterCalldatas);

        // Verify the call happened
        assertEq(target.param(), 42);
    }

    function test_multiCall() public {
        // Create multiple executions that call targetFn with different params
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (100)) });
        executions[1] = Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.targetFn, (200)) });

        bytes memory multiCallData = abi.encodeCall(MultiCaller.multiCall, (executions));

        // Pass empty arrays since multiCall doesn't consume solver contexts
        bytes[] memory emptyContexts = new bytes[](0);
        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = multiCallData;

        _fill(block.chainid, emptyContexts, adapterCalldatas);

        // Verify the last call's params (200 and 0 value)
        assertEq(target.param(), 200);
        assertEq(target.value(), 0);
    }
}
