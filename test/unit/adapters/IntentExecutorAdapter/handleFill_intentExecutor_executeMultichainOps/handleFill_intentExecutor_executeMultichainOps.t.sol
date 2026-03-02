// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { IntentExecutorAdapter_Unit_Test } from "test/unit/adapters/IntentExecutorAdapter/IntentExecutorAdapter.t.sol";

// Contracts
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";

// Interfaces
import { IStandaloneIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IStandaloneIntent.sol";

// Mocks
import { MockExecutor } from "test/utils/mocks/MockExecutor.sol";

// Types
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract IntentExecutorAdapter_HandleFill_IntentExecutor_ExecuteMultichainOps_Unit_Test is IntentExecutorAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handleFill_intentExecutor_executeMultichainOps_RevertsWhen_OnlyDelegateCall() public {
        // Setup proper multichain ops calldata
        IStandaloneIntentExecutor.MultiChainOps memory multiChainOps = _createMultiChainOps();
        bytes memory callData = abi.encode(multiChainOps);

        // Expect revert
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        intentExecutorAdapter.handleFill_intentExecutor_executeMultichainOps(callData);
    }

    function test_handleFill_intentExecutor_executeMultichainOps() public {
        vm.skip(true);
        // Setup proper multichain ops calldata
        IStandaloneIntentExecutor.MultiChainOps memory multiChainOps = _createMultiChainOps();
        bytes memory callData = abi.encode(multiChainOps);

        // Etch the adapter code to the router address to mock a delegate call
        vm.etch(address(router), address(intentExecutorAdapter).code);

        // Expect the Filled event to be emitted
        // vm.expectEmit(true, true, true, true);
        // emit AdapterBase.Filled(multiChainOps.nonce);

        // Call the function
        vm.expectCall(address(mockExecutor), abi.encodeWithSelector(IStandaloneIntentExecutor.executeMultichainOps.selector, multiChainOps));
        IntentExecutorAdapter(address(router)).handleFill_intentExecutor_executeMultichainOps(callData);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createMultiChainOps() internal pure returns (IStandaloneIntentExecutor.MultiChainOps memory) {
        // Create dummy operation
        Types.Operation memory ops = Types.Operation({ data: hex"4206969420" });

        // Create other chain hashes
        bytes32[] memory otherChains = new bytes32[](2);
        otherChains[0] = keccak256("chain1");
        otherChains[1] = keccak256("chain2");

        // Create dummy signature
        bytes memory signature = new bytes(65);
        signature[64] = 0x1b; // v value

        return IStandaloneIntentExecutor.MultiChainOps({
            account: address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa),
            chainIndex: 0,
            otherChains: otherChains,
            nonce: 42,
            ops: ops,
            signature: signature
        });
    }
}
