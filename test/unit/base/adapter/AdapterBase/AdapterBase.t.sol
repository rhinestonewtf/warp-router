// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { MockAdapter } from "@rhinestone/compact-utils/src/tests/MockAdapter.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

// Mocks
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";

contract AdapterBase_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockAdapter internal adapter;
    address internal router;

    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    address internal solver;
    address internal recipient;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Set up addresses
        router = makeAddr("router");
        solver = makeAddr("solver");
        recipient = makeAddr("recipient");

        // Deploy MockAdapter with router and no arbiter
        adapter = new MockAdapter(router, address(0));

        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);

        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(token3), "Token3");

        // Fund test accounts
        token1.mint(solver, 1000 ether);
        token2.mint(solver, 1000 ether);
        token3.mint(solver, 1000 ether);

        // Fund router for prefund tests
        token1.mint(address(router), 1000 ether);
        token2.mint(address(router), 1000 ether);
        token3.mint(address(router), 1000 ether);

        // Deal ETH to various accounts
        vm.deal(solver, 10 ether);
        vm.deal(address(router), 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _prankDelegateCall() internal {
        // Etch adapter code to the router address for delegate call simulation
        vm.etch(router, address(adapter).code);
        adapter = MockAdapter(payable(router));
    }

    function _createBasicTokenOut() internal view returns (uint256[2][] memory) {
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), 100 ether];
        return tokenOut;
    }

    function _createMultipleTokenOut() internal view returns (uint256[2][] memory) {
        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0] = [uint256(uint160(address(token1))), 50 ether];
        tokenOut[1] = [uint256(uint160(address(token2))), 75 ether];
        return tokenOut;
    }

    function _executeFillViaRouter(bytes32 nonce, address recip, uint256[2][] memory tokenOut, bytes memory relayerContext) internal {
        _prankDelegateCall();

        // Encode the function call with solver context appended
        bytes memory adapterCalldata = abi.encodeCall(adapter.mockFill, (nonce, recip, tokenOut));
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        vm.prank(solver);
        (bool success,) = router.call(fullCalldata);
        assertTrue(success);
    }

    function _executeClaimViaRouter(bytes32 nonce, address recip, uint256[2][] memory tokenOut, bytes memory relayerContext) internal {
        _prankDelegateCall();

        bytes memory adapterCalldata = abi.encodeCall(adapter.mockClaim, (nonce, recip, tokenOut));
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length));

        vm.prank(solver);
        (bool success,) = router.call(fullCalldata);
        assertTrue(success);
    }
}
