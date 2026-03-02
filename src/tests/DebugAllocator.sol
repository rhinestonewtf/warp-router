// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";

contract TestAllocator is RSAllocator {
    constructor(address compact, address _owner, address _signer) RSAllocator(compact, _owner, _signer) { }

    function _compactDomainSeparator() internal view virtual override returns (bytes32) {
        return _compactDomainSeparator(block.chainid);
    }
}
