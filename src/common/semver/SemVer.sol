pragma solidity ^0.8.28;

import { LibString } from "solady/utils/LibString.sol";
import { SemVerLib } from "./SemVerLib.sol";
import { Version } from "@rhinestone/compact-utils/src/Version.sol";

// contract SemVerBase is SemVer {
// constructor(uint256 minor, uint256 patch) SemVer(1, minor, patch) { }
//}

contract SemVer {
    uint256 internal immutable MAJOR;
    uint256 internal immutable MINOR;
    uint256 internal immutable PATCH;
    bytes6 internal immutable PACKED_VERSION;

    constructor(uint256 minor, uint256 patch) {
        MAJOR = Version.MAJOR_V1;
        MINOR = minor;
        PATCH = patch;
        PACKED_VERSION = SemVerLib.packVersion(MAJOR, minor, patch);
    }

    function semVer() external view returns (bytes6 packedVersion) {
        return PACKED_VERSION;
    }

    function semVerUnpacked() external view returns (uint256 major, uint256 minor, uint256 patch) {
        return (MAJOR, MINOR, PATCH);
    }

    function version() external view returns (bytes memory) {
        return abi.encodePacked("v", LibString.toString(MAJOR), ".", LibString.toString(MINOR), ".", LibString.toString(PATCH));
    }
}
