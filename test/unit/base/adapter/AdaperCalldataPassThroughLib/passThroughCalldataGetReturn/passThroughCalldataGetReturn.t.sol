// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import {
    AdapterCalldataPassthroughLib_Unit_Test
} from "test/unit/base/adapter/AdaperCalldataPassThroughLib/AdaperCalldataPassThoughLib.t.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";

contract AdapterCalldataPassthroughLib_PassthroughCalldataGetReturn_Unit_Test is AdapterCalldataPassthroughLib_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        RETURN DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_passthroughCalldataGetReturn_BasicReturn() public {
        // Set a value first
        target.targetFn(42);

        // Call getter and check return
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), bytes4(0x883d87b1), "");

        uint256 returnedParam = abi.decode(returnData, (uint256));
        assertEq(returnedParam, 42);
    }

    function test_passthroughCalldataGetReturn_CallWithParamsAndReturn() public {
        uint256 paramValue = 9999;
        bytes memory params = _encodeTargetFnCall(paramValue);

        // targetFn doesn't have a return value in the actual MockTarget
        // So we need to call it, then get param separately
        this.callPassthroughCalldata(address(target), MockTarget.targetFn.selector, params);

        // Now get the param value
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), bytes4(0x883d87b1), "");

        uint256 returnedValue = abi.decode(returnData, (uint256));
        assertEq(returnedValue, paramValue);
    }

    function test_passthroughCalldataGetReturn_LargeReturnData() public {
        target.targetFn(type(uint256).max);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), bytes4(0x883d87b1), "");

        uint256 returnedParam = abi.decode(returnData, (uint256));
        assertEq(returnedParam, type(uint256).max);
    }

    function test_passthroughCalldataGetReturn_ZeroValue() public {
        // MockTarget handles 0 just fine
        target.targetFn(0);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), bytes4(0x883d87b1), "");

        uint256 returnedParam = abi.decode(returnData, (uint256));
        assertEq(returnedParam, 0);
    }

    function test_passthroughCalldataGetReturn_AddressReturn() public {
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getAddress.selector, "");

        address returnedAddress = abi.decode(returnData, (address));
        assertEq(returnedAddress, address(target));
    }

    function test_passthroughCalldataGetReturn_BoolReturn() public {
        // Set param > 0 for true
        target.targetFn(100);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getBool.selector, "");

        bool returnedBool = abi.decode(returnData, (bool));
        assertTrue(returnedBool);

        // Set param = 0 for false
        target.targetFn(0);

        returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getBool.selector, "");

        returnedBool = abi.decode(returnData, (bool));
        assertFalse(returnedBool);
    }

    function test_passthroughCalldataGetReturn_Bytes32Return() public {
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getBytes32.selector, "");

        bytes32 returnedBytes32 = abi.decode(returnData, (bytes32));
        assertEq(returnedBytes32, keccak256("test"));
    }

    function test_passthroughCalldataGetReturn_StringReturn() public {
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getString.selector, "");

        string memory returnedString = abi.decode(returnData, (string));
        assertEq(returnedString, "hello world");
    }

    function test_passthroughCalldataGetReturn_ArrayReturn() public {
        target.targetFn(10);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getArray.selector, "");

        uint256[] memory returnedArray = abi.decode(returnData, (uint256[]));
        assertEq(returnedArray.length, 3);
        assertEq(returnedArray[0], 10);
        assertEq(returnedArray[1], 20);
        assertEq(returnedArray[2], 30);
    }

    function test_passthroughCalldataGetReturn_TupleReturn() public {
        target.targetFn(42);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getTuple.selector, "");

        (uint256 num, address addr, bool flag) = abi.decode(returnData, (uint256, address, bool));
        assertEq(num, 42);
        assertEq(addr, address(target));
        assertTrue(flag);
    }

    function test_passthroughCalldataGetReturn_BytesReturn() public {
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.getBytes.selector, "");

        bytes memory returnedBytes = abi.decode(returnData, (bytes));

        // Decode the inner content
        (uint256 num, address addr, string memory str) = abi.decode(returnedBytes, (uint256, address, string));
        assertEq(num, 123);
        assertEq(addr, address(0xdead));
        assertEq(str, "test");
    }

    function test_passthroughCalldataGetReturn_EmptyReturn() public {
        // Call a function that returns nothing (targetFn)
        bytes memory params = _encodeTargetFnCall(555);

        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), MockTarget.targetFn.selector, params);

        // Should return empty bytes for a function with no return value
        assertEq(returnData.length, 0);
    }

    function test_passthroughCalldataGetReturn_TargetNotContract() public {
        address notContract = makeAddr("notContract");

        bytes memory returnData = this.callPassthroughCalldataGetReturn(notContract, bytes4(0x883d87b1), "");

        // Should return empty bytes since there's no code
        assertEq(returnData.length, 0);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_passthroughCalldataGetReturn_RevertsWhen_InvalidSelector() public {
        bytes4 invalidSelector = bytes4(keccak256("nonexistent()"));

        vm.expectRevert();
        this.callPassthroughCalldataGetReturn(address(target), invalidSelector, "");
    }

    function test_passthroughCalldataGetReturn_RevertsWhen_WrongParams() public {
        // Try calling deposit with wrong params
        bytes memory wrongParams = abi.encode(uint256(123)); // deposit expects (address, uint256)

        vm.expectRevert();
        this.callPassthroughCalldataGetReturn(address(target), MockTarget.deposit.selector, wrongParams);
    }

    /* //////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_passthroughCalldataGetReturn_GetterValues(uint256 setValue) public {
        // Set value first
        target.targetFn(setValue);

        // Get value through passthrough
        bytes memory returnData = this.callPassthroughCalldataGetReturn(address(target), bytes4(0x883d87b1), "");

        uint256 returnedValue = abi.decode(returnData, (uint256));
        assertEq(returnedValue, setValue);
    }
}
