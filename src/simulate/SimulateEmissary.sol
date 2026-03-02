// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Emissary } from "../emissary/Emissary.sol";

contract SimulateEmissary is Emissary {
    bytes32 public constant foo = keccak256("SimulateEmissary");

    constructor(address compact) { }

    function verifyClaim(
        address sponsor,
        bytes32 digest,
        bytes32, /* claimHash*/
        bytes calldata emissaryData,
        bytes12 lockTag
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return _validateSignature(sponsor, digest, emissaryData, lockTag) ? this.verifyClaim.selector : INVALID_SIGNATURE;
    }
}
