// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { RSAllocator } from "../allocator/RSAllocator.sol";

contract SimulateAllocator is RSAllocator {
    constructor(address compact, address _owner, address _signer) RSAllocator(compact, _owner, _signer) { }

    function _authorizeClaim(bytes32 claimHash, bytes calldata allocatorData) internal view virtual override returns (bool) {
        super._authorizeClaim(claimHash, allocatorData);
        return true;
    }
}
