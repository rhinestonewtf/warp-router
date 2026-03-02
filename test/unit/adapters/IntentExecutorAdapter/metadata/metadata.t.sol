// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { IntentExecutorAdapter_Unit_Test } from "test/unit/adapters/IntentExecutorAdapter/IntentExecutorAdapter.t.sol";

// Contracts
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";

contract IntentExecutorAdapter_Metadata_Unit_Test is IntentExecutorAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface() public view {
        assertTrue(intentExecutorAdapter.supportsInterface(IntentExecutorAdapter.supportsInterface.selector));
        assertTrue(intentExecutorAdapter.supportsInterface(IntentExecutorAdapter.handleFill_intentExecutor_handleCompactTargetOps.selector));
        assertTrue(intentExecutorAdapter.supportsInterface(IntentExecutorAdapter.handleFill_intentExecutor_handlePermit2TargetOps.selector));
        assertTrue(intentExecutorAdapter.supportsInterface(IntentExecutorAdapter.handleFill_intentExecutor_executeMultichainOps.selector));
    }
}
