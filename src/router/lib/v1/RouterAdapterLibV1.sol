// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { RouterManagerStorageLib, AdapterConfig } from "../RouterStorageLib.sol";
import { Version } from "../../../Version.sol";

library RouterManagerV1 {
    using RouterManagerStorageLib for bytes4;

    function withFillAdapter(bytes4 selector) internal pure returns (AdapterConfig storage $config) {
        return selector.withFillAdapter(Version.PROTOCOL_V1);
    }

    function withClaimAdapter(bytes4 selector) internal pure returns (AdapterConfig storage $config) {
        return selector.withClaimAdapter(Version.PROTOCOL_V1);
    }
}
