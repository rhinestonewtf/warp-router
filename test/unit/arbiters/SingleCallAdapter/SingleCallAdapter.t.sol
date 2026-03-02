// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { SingleCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/SingleCallAdapter.sol";
import { Caller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";

contract SingleCallAdapter_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    SingleCallAdapter internal singleCallAdapter;
    Caller internal caller;
    address internal router;

    MockTarget internal target;
    MockERC20 internal token;

    address internal solver;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Set up addresses
        router = makeAddr("router");
        solver = makeAddr("solver");

        // Deploy Caller (which acts as the arbiter)
        caller = new Caller();

        // Deploy the adapter
        singleCallAdapter = new SingleCallAdapter(router);

        // Deploy mock target and token
        target = new MockTarget();
        token = new MockERC20("Token", "TKN", 18);
        vm.label(address(target), "MockTarget");
        vm.label(address(token), "Token");

        // Setup initial balances
        token.mint(solver, 1000 ether);
        token.mint(address(singleCallAdapter), 100 ether);

        // Fund with ETH
        vm.deal(solver, 10 ether);
        vm.deal(router, 10 ether);
        vm.deal(address(singleCallAdapter), 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _prankDelegateCall() internal {
        // Etch singleCallAdapter code to the router address
        vm.etch(router, address(singleCallAdapter).code);
        singleCallAdapter = SingleCallAdapter(payable(router));
    }

    function _packData(address _target, bytes memory callData) internal pure returns (bytes memory) {
        return abi.encodePacked(_target, callData);
    }
}
