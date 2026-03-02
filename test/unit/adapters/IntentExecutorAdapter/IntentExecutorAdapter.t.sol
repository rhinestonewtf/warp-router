// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";

// Mocks
import { MockExecutor } from "test/utils/mocks/MockExecutor.sol";

abstract contract IntentExecutorAdapter_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    IntentExecutorAdapter internal intentExecutorAdapter;
    MockExecutor internal mockExecutor;
    address router;

    /* //////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Deploy a mock executor
        mockExecutor = new MockExecutor();
        // Set a mock router address
        router = makeAddr("router");
        // Deploy the adapter
        intentExecutorAdapter = new IntentExecutorAdapter(address(router), address(mockExecutor));
    }
}
