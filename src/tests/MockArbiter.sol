// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ArbiterBase } from "@rhinestone/compact-utils/src/base/arbiter/ArbiterBase.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IArbiter } from "@rhinestone/compact-utils/src/interfaces/IArbiter.sol";

contract MockArbiter is ArbiterBase {
    constructor(address router, address compact, address addressBook) ArbiterBase(router, compact, addressBook) { }

    function testCompactPreClaimOps(
        Types.Order calldata order,
        Types.Signatures calldata sigs,
        bytes32[] calldata otherElements,
        uint256 elementOffset,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend
    )
        external
        onlyRouter
        returns (bytes32)
    {
        return _compactPreClaimOps(order, sigs, otherElements, elementOffset, notarizedChainId);
    }

    function testPermit2PreClaimOps(
        Types.Order calldata order,
        Types.Signatures calldata sigs,
        uint256 preClaimGasStipend
    )
        external
        onlyRouter
        returns (bytes32)
    {
        return _permit2PreClaimOps(order, sigs);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IArbiter).interfaceId;
    }
}
