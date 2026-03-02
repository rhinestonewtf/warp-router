// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { SingleCallAdapter_Unit_Test } from "test/unit/arbiters/SingleCallAdapter/SingleCallAdapter.t.sol";

// Contracts
import { SingleCallAdapter } from "@rhinestone/compact-utils/src/arbiters/multicall/SingleCallAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";

contract SingleCallAdapter_HandleFill_Unit_Test is SingleCallAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event RouterFilled(address sponsor, uint256 nonce);

    /* //////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_singleCall_handleFill_RevertsWhen_NotCalledViaRouter() public {
        uint256 nonce = 1;
        bytes memory packedData = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, 123));

        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        singleCallAdapter.singleCall_handleFill(nonce, solver, packedData);
    }

    function test_singleCall_handleFill_BasicCall() public {
        uint256 nonce = 42;
        uint256 param = 12_345;
        bytes memory packedData = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, param));

        bytes4 selector = _executeHandleFill(nonce, packedData);

        assertEq(selector, singleCallAdapter.singleCall_handleFill.selector, "Should return correct selector");
        assertEq(target.param(), param, "Target should have received the param");
    }

    function test_singleCall_handleFill_EmitsRouterFilledEvent() public {
        uint256 nonce = 100;
        uint256 param = 999;
        address sponsor = makeAddr("sponsor");
        bytes memory packedData = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, param));

        vm.expectEmit(true, true, false, false);
        emit RouterFilled(sponsor, nonce);

        _executeHandleFill(nonce, sponsor, packedData);
    }

    function test_singleCall_handleFill_RevertsWhen_TargetReverts() public {
        uint256 nonce = 1;
        bytes memory packedData = _packData(address(target), abi.encodeWithSelector(MockTarget.reverting.selector));

        vm.expectRevert(SingleCallAdapter.SingleCallFailed.selector);
        _executeHandleFill(nonce, packedData);
    }

    function test_singleCall_handleFill_WithEmptyCalldata() public {
        // Create a contract that accepts empty calldata
        EmptyCalldataReceiver receiver = new EmptyCalldataReceiver();

        uint256 nonce = 5;
        bytes memory packedData = _packData(address(receiver), "");

        bytes4 selector = _executeHandleFill(nonce, packedData);
        assertEq(selector, singleCallAdapter.singleCall_handleFill.selector);
        assertTrue(receiver.called(), "Receiver should have been called");
    }

    function test_singleCall_handleFill_MultipleCallsWithDifferentNonces() public {
        uint256 param1 = 100;
        uint256 param2 = 200;

        bytes memory packedData1 = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, param1));
        bytes memory packedData2 = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, param2));

        _executeHandleFill(1, packedData1);
        assertEq(target.param(), param1);

        _executeHandleFill(2, packedData2);
        assertEq(target.param(), param2);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_singleCall_handleFill(uint256 nonce, uint256 param) public {
        bytes memory packedData = _packData(address(target), abi.encodeWithSelector(MockTarget.targetFn.selector, param));

        bytes4 selector = _executeHandleFill(nonce, packedData);

        assertEq(selector, singleCallAdapter.singleCall_handleFill.selector);
        assertEq(target.param(), param);
    }

    function testFuzz_singleCall_handleFill_ExtractsTargetCorrectly(address fuzzTarget, uint256 nonce) public {
        vm.assume(fuzzTarget != address(0));
        vm.assume(uint160(fuzzTarget) > uint160(420_420_420_420)); // Avoid precompiles

        // Deploy target code at fuzz address
        vm.etch(fuzzTarget, address(target).code);
        MockTarget fuzzMockTarget = MockTarget(fuzzTarget);

        uint256 param = 777;
        bytes memory packedData = _packData(fuzzTarget, abi.encodeWithSelector(MockTarget.targetFn.selector, param));

        bytes4 selector = _executeHandleFill(nonce, packedData);

        assertEq(selector, singleCallAdapter.singleCall_handleFill.selector);
        assertEq(fuzzMockTarget.param(), param);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeHandleFill(uint256 nonce, bytes memory packedData) internal returns (bytes4) {
        return _executeHandleFill(nonce, solver, packedData);
    }

    function _executeHandleFill(uint256 nonce, address sponsor, bytes memory packedData) internal returns (bytes4) {
        // Encode the function call
        bytes memory adapterCalldata = abi.encodeWithSelector(SingleCallAdapter.singleCall_handleFill.selector, nonce, sponsor, packedData);

        // Append empty relayer context as router would do
        // Format: [original_calldata][relayer_context][context_length]
        bytes memory fullCalldata = abi.encodePacked(adapterCalldata, uint256(0));

        // Etch adapter code to router address for delegate call simulation
        _prankDelegateCall();

        // Perform the call as router
        vm.prank(solver);
        (bool success, bytes memory returnData) = router.call(fullCalldata);
        require(success, "Call failed");

        return abi.decode(returnData, (bytes4));
    }
}

/// @notice Helper contract that accepts empty calldata
contract EmptyCalldataReceiver {
    bool public called;

    fallback() external payable {
        called = true;
    }

    receive() external payable {
        called = true;
    }
}
