// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { MultiCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/MultiCallAdapter.sol";
import { Caller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";

// Mocks
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";

contract MultiCallAdapter_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MultiCallAdapter internal multiCallAdapter;
    Caller internal multiCaller;
    address internal router;

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    address internal solver;
    address internal account;
    address internal tokenInRecipient;
    address internal refundRecipient;
    address internal multiCallAdapterAddress;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Set up addresses
        router = makeAddr("router");
        solver = makeAddr("solver");
        account = makeAddr("account");
        tokenInRecipient = makeAddr("tokenInRecipient");
        refundRecipient = makeAddr("refundRecipient");

        // Deploy Caller (which acts as the arbiter)
        multiCaller = new Caller();

        // Deploy the adapter with MultiCaller as arbiter
        multiCallAdapter = new MultiCallAdapter(router);
        multiCallAdapterAddress = address(multiCallAdapter);

        // Deploy mock tokens
        tokenA = new MockERC20("TokenA", "TKA", 18);
        tokenB = new MockERC20("TokenB", "TKB", 18);
        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");

        // Setup initial balances for testing
        tokenA.mint(solver, 1000 ether);
        tokenB.mint(solver, 1000 ether);
        tokenA.mint(address(multiCallAdapter), 100 ether);
        tokenB.mint(address(multiCallAdapter), 100 ether);

        // Fund with ETH
        vm.deal(solver, 10 ether);
        vm.deal(router, 10 ether);
        vm.deal(address(multiCallAdapter), 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _prankDelegateCall() internal {
        // Etch multiCaller code to the router address
        vm.etch(router, address(multiCallAdapter).code);
        multiCallAdapter = MultiCallAdapter(payable(router));
    }
}
