// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AdapterBase, SemVer } from "src/base/adapter/AdapterBase.sol";

/// @notice Adapter that returns an incorrect selector, triggering AdapterCallFailed
contract WrongSelectorAdapter is AdapterBase {
    constructor(address router) AdapterBase(router, address(0)) SemVer(0, 0) { }

    function wrongFill(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        return bytes4(0xdeadbeef); // Wrong selector
    }

    function wrongClaim(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        return bytes4(0xdeadbeef); // Wrong selector
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.wrongFill.selector || interfaceId == this.wrongClaim.selector
            || super.supportsInterface(interfaceId);
    }
}

/// @notice Adapter that always reverts, triggering DelegatecallFailed
contract RevertingAdapter is AdapterBase {
    constructor(address router) AdapterBase(router, address(0)) SemVer(0, 0) { }

    function revertingFill(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        revert("adapter exploded");
    }

    function revertingClaim(bytes32, address, uint256[2][] calldata) external onlyViaRouter returns (bytes4) {
        revert("adapter exploded");
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.revertingFill.selector || interfaceId == this.revertingClaim.selector
            || super.supportsInterface(interfaceId);
    }
}
