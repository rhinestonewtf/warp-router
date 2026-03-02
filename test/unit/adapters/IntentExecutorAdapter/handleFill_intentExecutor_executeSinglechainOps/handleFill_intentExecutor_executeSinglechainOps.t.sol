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

contract IntentExecutorAdapter_HandleFill_IntentExecutor_ExecuteSinglechainOps_Unit_Test is IntentExecutorAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handleFill_intentExecutor_executeSinglechainOps_RevertsWhen_OnlyDelegateCall() public {
        // Setup proper single-chain ops calldata
        IStandaloneIntentExecutor.SingleChainOps memory singleChainOps = _createSingleChainOps();
        bytes memory callData = abi.encode(singleChainOps);

        // Expect revert
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        intentExecutorAdapter.handleFill_intentExecutor_executeSinglechainOps(callData);
    }

    function test_handleFill_intentExecutor_executeSinglechainOps() public {
        vm.skip(true);
        // Setup proper single-chain ops calldata
        IStandaloneIntentExecutor.SingleChainOps memory singleChainOps = _createSingleChainOps();
        bytes memory callData = abi.encode(singleChainOps);

        // Etch the adapter code to the router address to mock a delegate call
        vm.etch(address(router), address(intentExecutorAdapter).code);

        // Expect the Filled event to be emitted
        // vm.expectEmit(true, true, true, true);
        // emit AdapterBase.Filled(singleChainOps.nonce);

        // Call the function
        vm.expectCall(
            address(mockExecutor), abi.encodeWithSelector(IStandaloneIntentExecutor.executeSinglechainOps.selector, singleChainOps)
        );
        IntentExecutorAdapter(address(router)).handleFill_intentExecutor_executeSinglechainOps(callData);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createSingleChainOps() internal pure returns (IStandaloneIntentExecutor.SingleChainOps memory) {
        // Create dummy operation
        Types.Operation memory ops = Types.Operation({ data: hex"4206969420" });

        // Create dummy signature
        bytes memory signature = new bytes(65);
        signature[64] = 0x1b; // v value

        return IStandaloneIntentExecutor.SingleChainOps({
            account: address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa), nonce: 42, ops: ops, signature: signature
        });
    }
}
