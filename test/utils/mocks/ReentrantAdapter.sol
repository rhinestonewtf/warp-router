// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AdapterBase, SemVer } from "src/base/adapter/AdapterBase.sol";
import { IRouter } from "src/interfaces/IRouter.sol";
import { IArbiter } from "src/interfaces/IArbiter.sol";

/// @notice Mock adapter that attempts to re-enter the Router during delegatecall execution.
/// @dev When delegatecalled from the Router, `address(this)` is the Router's address.
///      The adapter makes an external call back into the Router, which should be blocked
///      by the nonReentrant guard.
contract ReentrantAdapter is AdapterBase {
    constructor(address router) AdapterBase(router, address(0)) SemVer(0, 0) { }

    function reentrantFill(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        // address(this) == Router in delegatecall context
        // Attempt to re-enter via batch routeClaim (empty arrays still hit the nonReentrant guard)
        bytes[] memory contexts = new bytes[](0);
        bytes[] memory calldatas = new bytes[](0);
        IRouter(address(this)).routeClaim(contexts, calldatas);
        return this.reentrantFill.selector;
    }

    function reentrantClaim(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        bytes[] memory contexts = new bytes[](0);
        bytes[] memory calldatas = new bytes[](0);
        IRouter(address(this)).routeClaim(contexts, calldatas);
        return this.reentrantClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.reentrantFill.selector || interfaceId == this.reentrantClaim.selector
            || super.supportsInterface(interfaceId);
    }
}

contract ReentrantArbiter is IArbiter {
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IArbiter).interfaceId;
    }
}
