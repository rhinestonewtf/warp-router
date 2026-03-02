// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { AdapterCalldataPassthroughLib } from "@rhinestone/compact-utils/src/base/adapter/AdapterCalldataPassthroughLib.sol";

// Mocks
import { MockTarget } from "@rhinestone/compact-utils/src/tests/MockTarget.sol";
import { MockERC20 } from "@rhinestone/compact-utils/src/tests/MockERC20.sol";

contract AdapterCalldataPassthroughLib_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using AdapterCalldataPassthroughLib for *;

    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockTarget internal target;
    MockERC20 internal token;

    address internal user;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Deploy mock target
        target = new MockTarget();

        // Deploy mock token
        token = new MockERC20("Test", "TST", 18);

        // Setup addresses
        user = makeAddr("user");

        // Deal ETH for tests that need it
        vm.deal(user, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function callPassthroughCalldata(address _target, bytes4 selector, bytes calldata abiEncodedParams) public {
        AdapterCalldataPassthroughLib.passthrough(_target, selector, abiEncodedParams);
    }

    function callPassthroughCalldataGetReturn(
        address _target,
        bytes4 selector,
        bytes calldata abiEncodedParams
    )
        public
        returns (bytes memory)
    {
        return AdapterCalldataPassthroughLib.passthroughToBytes(_target, selector, abiEncodedParams);
    }

    function _encodeTargetFnCall(uint256 param) internal pure returns (bytes memory) {
        return abi.encode(param);
    }

    function _encodeDepositCall(address tokenAddr, uint256 amount) internal pure returns (bytes memory) {
        return abi.encode(tokenAddr, amount);
    }
}
