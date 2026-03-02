// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "test/unit/router/core/RouterLogic/RouterLogic.t.sol";

// Contracts
import { ISingleCaller, MultiCaller } from "src/router/utils/Caller.sol";
import { IDirectRoute } from "src/router/core/DirectRoutes.sol";
import { FeeCollector } from "src/router/utils/FeeCollector.sol";

contract DirectRoutes_ProcessDirectRoute_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                    PROCESS DIRECT FILL ROUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_processDirectFillRoute_SingleCall_ReturnsTrue() public {
        bytes memory callData =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 50 ether)));

        token1.mint(address(routerLogic.CALLER()), 100 ether);

        bool result = routerLogic.exposed_processDirectFillRoute(ISingleCaller.singleCall.selector, callData);

        assertTrue(result);
        assertEq(token1.balanceOf(recipient), 50 ether);
    }

    function test_processDirectFillRoute_CollectFee_ReturnsTrue() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory callData = abi.encodeWithSelector(IDirectRoute.onFill_inRouter_collectFee.selector, fee);

        vm.prank(solver);
        token1.approve(address(routerLogic), 10 ether);

        vm.prank(solver);
        bool result = routerLogic.exposed_processDirectFillRoute(IDirectRoute.onFill_inRouter_collectFee.selector, callData);

        assertTrue(result);
        assertEq(token1.balanceOf(feeRecipient), 10 ether);
    }

    function test_processDirectFillRoute_CollectFees_ReturnsTrue() public {
        address feeRecipient = makeAddr("feeRecipient");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 5 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token2))), 15 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts2 });

        bytes memory callData = abi.encodeWithSelector(IDirectRoute.onFill_inRouter_collectFees.selector, fees);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), 5 ether);
        token2.approve(address(routerLogic), 15 ether);
        vm.stopPrank();

        vm.prank(solver);
        bool result = routerLogic.exposed_processDirectFillRoute(IDirectRoute.onFill_inRouter_collectFees.selector, callData);

        assertTrue(result);
        assertEq(token1.balanceOf(feeRecipient), 5 ether);
        assertEq(token2.balanceOf(feeRecipient), 15 ether);
    }

    function test_processDirectFillRoute_UnknownSelector_ReturnsFalse() public {
        bytes4 unknownSelector = bytes4(keccak256("unknown()"));
        bytes memory callData = abi.encodeWithSelector(unknownSelector);

        bool result = routerLogic.exposed_processDirectFillRoute(unknownSelector, callData);

        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                    PROCESS DIRECT CLAIM ROUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_processDirectClaimRoute_SingleCall_ReturnsTrue() public {
        bytes memory callData =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 60 ether)));

        token1.mint(address(routerLogic.CALLER()), 100 ether);

        bool result = routerLogic.exposed_processDirectClaimRoute(ISingleCaller.singleCall.selector, callData);

        assertTrue(result);
        assertEq(token1.balanceOf(recipient), 60 ether);
    }

    function test_processDirectClaimRoute_FeeCollector_ReturnsFalse() public {
        // Fee collection is NOT a direct claim route
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory callData = abi.encodeWithSelector(IDirectRoute.onFill_inRouter_collectFee.selector, fee);

        bool result = routerLogic.exposed_processDirectClaimRoute(IDirectRoute.onFill_inRouter_collectFee.selector, callData);

        assertFalse(result);
    }

    function test_processDirectClaimRoute_UnknownSelector_ReturnsFalse() public {
        bytes4 unknownSelector = bytes4(keccak256("unknown()"));
        bytes memory callData = abi.encodeWithSelector(unknownSelector);

        bool result = routerLogic.exposed_processDirectClaimRoute(unknownSelector, callData);

        assertFalse(result);
    }

    /* //////////////////////////////////////////////////////////////
                        REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_processDirectFillRoute_RevertsWhen_CallFails() public {
        // Try to transfer more than balance
        bytes memory callData =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 1000 ether)));

        token1.mint(address(routerLogic), 10 ether);

        vm.expectRevert();
        routerLogic.exposed_processDirectFillRoute(ISingleCaller.singleCall.selector, callData);
    }

    function test_processDirectClaimRoute_RevertsWhen_CallFails() public {
        bytes memory callData =
            abi.encodePacked(ISingleCaller.singleCall.selector, address(token1), abi.encodeCall(token1.transfer, (recipient, 1000 ether)));

        token1.mint(address(routerLogic), 10 ether);

        vm.expectRevert();
        routerLogic.exposed_processDirectClaimRoute(ISingleCaller.singleCall.selector, callData);
    }

    function test_processDirectFillRoute_RevertsWhen_FeeCollectionFails() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 100 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory callData = abi.encodeWithSelector(IDirectRoute.onFill_inRouter_collectFee.selector, fee);

        // Solver doesn't have enough balance/approval
        vm.expectRevert();
        vm.prank(solver);
        routerLogic.exposed_processDirectFillRoute(IDirectRoute.onFill_inRouter_collectFee.selector, callData);
    }
}
