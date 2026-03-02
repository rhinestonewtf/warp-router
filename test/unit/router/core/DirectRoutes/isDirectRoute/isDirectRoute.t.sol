// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { DirectRoutes_Unit_Test } from "../DirectRoutes.t.sol";

// Contracts
import { IDirectRoute } from "src/router/core/DirectRoutes.sol";
import { ISingleCaller, MultiCaller } from "src/router/utils/Caller.sol";

contract DirectRoutes_IsDirectRoute_Unit_Test is DirectRoutes_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        IS DIRECT FILL ROUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isDirectFillRoute_SingleCall_ReturnsTrue() public {
        bytes4 selector = ISingleCaller.singleCall.selector;
        assertTrue(directRoutes.exposed_isDirectFillRoute(selector));
    }

    function test_isDirectFillRoute_MultiCall_ReturnsTrue() public {
        bytes4 selector = MultiCaller.multiCall.selector;
        assertTrue(directRoutes.exposed_isDirectFillRoute(selector));
    }

    function test_isDirectFillRoute_CollectFee_ReturnsTrue() public {
        bytes4 selector = IDirectRoute.onFill_inRouter_collectFee.selector;
        assertTrue(directRoutes.exposed_isDirectFillRoute(selector));
    }

    function test_isDirectFillRoute_CollectFees_ReturnsTrue() public {
        bytes4 selector = IDirectRoute.onFill_inRouter_collectFees.selector;
        assertTrue(directRoutes.exposed_isDirectFillRoute(selector));
    }

    function test_isDirectFillRoute_UnknownSelector_ReturnsFalse() public {
        bytes4 unknownSelector = bytes4(keccak256("unknownFunction()"));
        assertFalse(directRoutes.exposed_isDirectFillRoute(unknownSelector));
    }

    function test_isDirectFillRoute_EmptySelector_ReturnsFalse() public {
        bytes4 emptySelector = bytes4(0);
        assertFalse(directRoutes.exposed_isDirectFillRoute(emptySelector));
    }

    /* //////////////////////////////////////////////////////////////
                        IS DIRECT CLAIM ROUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isDirectClaimRoute_SingleCall_ReturnsTrue() public {
        bytes4 selector = ISingleCaller.singleCall.selector;
        assertTrue(directRoutes.exposed_isDirectClaimRoute(selector));
    }

    function test_isDirectClaimRoute_MultiCall_ReturnsTrue() public {
        bytes4 selector = MultiCaller.multiCall.selector;
        assertTrue(directRoutes.exposed_isDirectClaimRoute(selector));
    }

    function test_isDirectClaimRoute_CollectFee_ReturnsFalse() public {
        bytes4 selector = IDirectRoute.onFill_inRouter_collectFee.selector;
        assertFalse(directRoutes.exposed_isDirectClaimRoute(selector));
    }

    function test_isDirectClaimRoute_CollectFees_ReturnsFalse() public {
        bytes4 selector = IDirectRoute.onFill_inRouter_collectFees.selector;
        assertFalse(directRoutes.exposed_isDirectClaimRoute(selector));
    }

    function test_isDirectClaimRoute_UnknownSelector_ReturnsFalse() public {
        bytes4 unknownSelector = bytes4(keccak256("unknownFunction()"));
        assertFalse(directRoutes.exposed_isDirectClaimRoute(unknownSelector));
    }

    function test_isDirectClaimRoute_EmptySelector_ReturnsFalse() public {
        bytes4 emptySelector = bytes4(0);
        assertFalse(directRoutes.exposed_isDirectClaimRoute(emptySelector));
    }
}
