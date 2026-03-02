// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Base
import {
    AdapterCalldataPassthroughLib_Unit_Test
} from "test/unit/base/adapter/AdaperCalldataPassThroughLib/AdaperCalldataPassThoughLib.t.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract AdapterCalldataPassthroughLib_PassthroughCalldata_Unit_Test is AdapterCalldataPassthroughLib_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                        BASIC PASSTHROUGH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_passthroughCalldata_BasicCall() public {
        uint256 paramValue = 12_345;
        bytes memory params = _encodeTargetFnCall(paramValue);

        this.callPassthroughCalldata(address(target), MockTarget.targetFn.selector, params);

        assertEq(target.param(), paramValue);
    }

    function test_passthroughCalldata_MultipleParams() public {
        uint256 amount = 100 ether;
        token.mint(address(this), amount);
        token.approve(address(target), amount);

        bytes memory params = _encodeDepositCall(address(token), amount);

        this.callPassthroughCalldata(address(target), MockTarget.deposit.selector, params);

        assertEq(token.balanceOf(address(target)), amount);
    }

    function test_passthroughCalldata_EmptyParams() public {
        // Set initial value
        target.targetFn(999);
        uint256 initialParam = target.param();

        // Call getter with no params
        this.callPassthroughCalldata(address(target), bytes4(0x883d87b1), "");

        // State shouldn't change from getter
        assertEq(target.param(), initialParam);
    }

    function test_passthroughCalldata_WithZeroParam() public {
        // MockTarget doesn't revert on 0, it just sets it
        bytes memory params = _encodeTargetFnCall(0);

        this.callPassthroughCalldata(address(target), MockTarget.targetFn.selector, params);

        assertEq(target.param(), 0);
    }

    function test_passthroughCalldata_LargeParams() public {
        // Create large param set (like a big array)
        uint256[] memory bigArray = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            bigArray[i] = i * 1000;
        }

        // Should handle large params without issue
        this.callPassthroughCalldata(address(target), MockTarget.targetFn.selector, abi.encode(bigArray.length));

        assertEq(target.param(), bigArray.length);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_passthroughCalldata_RevertsWhen_InvalidSelector() public {
        bytes memory params = _encodeTargetFnCall(123);
        bytes4 invalidSelector = bytes4(keccak256("nonexistent()"));

        vm.expectRevert();
        this.callPassthroughCalldata(address(target), invalidSelector, params);
    }

    function test_passthroughCalldata_RevertsWhen_InsufficientBalance() public {
        // This should revert due to insufficient token balance
        uint256 amount = 100 ether;
        bytes memory params = _encodeDepositCall(address(token), amount);

        vm.expectRevert(); // ERC20 transfer will fail
        this.callPassthroughCalldata(address(target), MockTarget.deposit.selector, params);
    }

    /* //////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_passthroughCalldata(uint256 param) public {
        bytes memory params = _encodeTargetFnCall(param);

        this.callPassthroughCalldata(address(target), MockTarget.targetFn.selector, params);

        assertEq(target.param(), param);
    }

    function testFuzz_passthroughCalldata_DifferentSelectors(bytes4 selector) public {
        // Test with random selectors that don't exist
        vm.assume(selector != MockTarget.targetFn.selector);
        vm.assume(selector != MockTarget.deposit.selector);
        vm.assume(selector != bytes4(0x883d87b1)); // param selector

        bytes memory params = _encodeTargetFnCall(123);

        // Should revert for non-existent functions
        vm.expectRevert();
        this.callPassthroughCalldata(address(target), selector, params);
    }
}
