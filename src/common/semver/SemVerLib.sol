// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title SemVerLib
 * @notice Library for packing and unpacking semantic version data into bytes6
 */
library SemVerLib {
    error MajorVersionTooLarge(uint256 major);
    error MinorVersionTooLarge(uint256 minor);
    error PatchVersionTooLarge(uint256 patch);

    /**
     * @notice Packs version components into bytes6
     * @param major Major version (must be <= 65535)
     * @param minor Minor version (must be <= 65535)
     * @param patch Patch version (must be <= 65535)
     * @return Packed version as bytes6
     */
    function packVersion(uint256 major, uint256 minor, uint256 patch) internal pure returns (bytes6) {
        require(major <= 0xFFFF, MajorVersionTooLarge(major));
        require(minor <= 0xFFFF, MinorVersionTooLarge(minor));
        require(patch <= 0xFFFF, PatchVersionTooLarge(patch));
        return bytes6(bytes.concat(bytes2(uint16(major)), bytes2(uint16(minor)), bytes2(uint16(patch))));
    }

    /**
     * @notice Unpacks bytes6 version into components
     * @param packedVersion Packed version as bytes6
     * @return major Major version
     * @return minor Minor version
     * @return patch Patch version
     */
    function unpackVersion(bytes6 packedVersion) internal pure returns (uint256 major, uint256 minor, uint256 patch) {
        uint48 packed = uint48(packedVersion);
        major = (packed >> 32) & 0xFFFF;
        minor = (packed >> 16) & 0xFFFF;
        patch = packed & 0xFFFF;
    }
}
