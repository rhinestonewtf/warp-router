// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { SemVer } from "./SemVer.sol";
import { SemVerLib } from "./SemVerLib.sol";

/**
 * @title SemVerCmp
 * @notice Library for comparing semantic versions using packed bytes6 representation
 */
library SemVerCmp {
    error MajorVersionTooLarge(uint256 major);
    error MinorVersionTooLarge(uint256 minor);
    error PatchVersionTooLarge(uint256 patch);

    /**
     * @notice Retrieves the semantic version from a SemVer contract
     * @param semVerContract Address of the contract implementing SemVer
     */
    function getSemVer(address semVerContract) internal view returns (bytes6) {
        return SemVer(semVerContract).semVer();
    }

    /**
     * @notice Compares two semantic versions
     * @param version1 Packed version to compare
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return majorCmp -1 if major1 < major2, 0 if equal, 1 if major1 > major2
     * @return minorCmp -1 if minor1 < minor2, 0 if equal, 1 if minor1 > minor2
     * @return patchCmp -1 if patch1 < patch2, 0 if equal, 1 if patch1 > patch2
     */
    function semVerCmp(bytes6 version1, address semVerContract) internal view returns (int8 majorCmp, int8 minorCmp, int8 patchCmp) {
        bytes6 version2 = SemVer(semVerContract).semVer();

        (uint256 major1, uint256 minor1, uint256 patch1) = SemVerLib.unpackVersion(version1);
        (uint256 major2, uint256 minor2, uint256 patch2) = SemVerLib.unpackVersion(version2);

        majorCmp = _compare(major1, major2);
        minorCmp = _compare(minor1, minor2);
        patchCmp = _compare(patch1, patch2);
    }

    /**
     * @notice Compares two semantic versions (alternative with individual components for convenience)
     * @param major1 Major version of first semver
     * @param minor1 Minor version of first semver
     * @param patch1 Patch version of first semver
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return majorCmp -1 if major1 < major2, 0 if equal, 1 if major1 > major2
     * @return minorCmp -1 if minor1 < minor2, 0 if equal, 1 if minor1 > minor2
     * @return patchCmp -1 if patch1 < patch2, 0 if equal, 1 if patch1 > patch2
     */
    function semVerCmp(
        uint256 major1,
        uint256 minor1,
        uint256 patch1,
        address semVerContract
    )
        internal
        view
        returns (int8 majorCmp, int8 minorCmp, int8 patchCmp)
    {
        bytes6 version1 = SemVerLib.packVersion(major1, minor1, patch1);
        return semVerCmp(version1, semVerContract);
    }

    /**
     * @notice Checks if version1 is only a patch upgrade (major and minor same, patch higher)
     * @param version1 Packed version to compare
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if major and minor are equal and patch is higher
     */
    function isOnlyPatch(bytes6 version1, address semVerContract) internal view returns (bool) {
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = semVerCmp(version1, semVerContract);
        return majorCmp == 0 && minorCmp == 0 && patchCmp == 1;
    }

    /**
     * @notice Checks if version1 is only a patch upgrade (convenience function with individual components)
     * @param major1 Major version of first semver
     * @param minor1 Minor version of first semver
     * @param patch1 Patch version of first semver
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if major and minor are equal and patch is higher
     */
    function isOnlyPatch(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool) {
        bytes6 version1 = SemVerLib.packVersion(major1, minor1, patch1);
        return isOnlyPatch(version1, semVerContract);
    }

    /**
     * @notice Checks if version1 is only a minor upgrade (major same, minor higher)
     * @param version1 Packed version to compare
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if major is equal and minor is higher
     */
    function isOnlyMinor(bytes6 version1, address semVerContract) internal view returns (bool) {
        (int8 majorCmp, int8 minorCmp,) = semVerCmp(version1, semVerContract);
        return majorCmp == 0 && minorCmp == 1;
    }

    /**
     * @notice Checks if version1 is only a minor upgrade (convenience function with individual components)
     * @param major1 Major version of first semver
     * @param minor1 Minor version of first semver
     * @param patch1 Patch version of first semver
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if major is equal and minor is higher
     */
    function isOnlyMinor(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool) {
        bytes6 version1 = SemVerLib.packVersion(major1, minor1, patch1);
        return isOnlyMinor(version1, semVerContract);
    }

    /**
     * @notice Checks if two versions have the same major version
     * @param version1 Packed version to compare
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if both versions have the same major version
     */
    function isSameMajor(bytes6 version1, address semVerContract) internal view returns (bool) {
        (int8 majorCmp,,) = semVerCmp(version1, semVerContract);
        return majorCmp == 0;
    }

    /**
     * @notice Checks if two versions have the same major version (convenience function with individual components)
     * @param major1 Major version of first semver
     * @param minor1 Minor version of first semver
     * @param patch1 Patch version of first semver
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if both versions have the same major version
     */
    function isSameMajor(uint256 major1, uint256 minor1, uint256 patch1, address semVerContract) internal view returns (bool) {
        bytes6 version1 = SemVerLib.packVersion(major1, minor1, patch1);
        return isSameMajor(version1, semVerContract);
    }

    /**
     * @notice Checks if a protocol version (bytes2) matches the major version of a semver contract
     * @dev Protocol versions are expected to directly represent the major version
     * @param protocolVersion Protocol version identifier (2 bytes)
     * @param semVerContract Address of the contract implementing SemVer to compare against
     * @return true if the protocol version matches the semver contract's major version
     */
    function isProtocolVersionCompatible(bytes2 protocolVersion, address semVerContract) internal view returns (bool) {
        uint256 expectedMajor = uint16(protocolVersion);
        bytes6 contractVersion = getSemVer(semVerContract);
        (uint256 contractMajor,,) = SemVerLib.unpackVersion(contractVersion);
        return expectedMajor == contractMajor;
    }

    /**
     * @notice Packs version components into bytes6
     * @param major Major version (must be <= 65535)
     * @param minor Minor version (must be <= 65535)
     * @param patch Patch version (must be <= 65535)
     * @return Packed version as bytes6
     */
    function packVersion(uint256 major, uint256 minor, uint256 patch) external pure returns (bytes6) {
        return _packVersion(major, minor, patch);
    }

    /**
     * @notice Unpacks bytes6 version into components
     * @param packedVersion Packed version as bytes6
     * @return major Major version
     * @return minor Minor version
     * @return patch Patch version
     */
    function unpackVersion(bytes6 packedVersion) external pure returns (uint256 major, uint256 minor, uint256 patch) {
        return _unpackVersion(packedVersion);
    }

    /**
     * @notice Internal helper function to pack version components
     */
    function _packVersion(uint256 major, uint256 minor, uint256 patch) internal pure returns (bytes6) {
        require(major <= 0xFFFF, MajorVersionTooLarge(major));
        require(minor <= 0xFFFF, MinorVersionTooLarge(minor));
        require(patch <= 0xFFFF, PatchVersionTooLarge(patch));
        return bytes6(bytes.concat(bytes2(uint16(major)), bytes2(uint16(minor)), bytes2(uint16(patch))));
    }

    /**
     * @notice Internal helper function to unpack version components
     */
    function _unpackVersion(bytes6 packedVersion) internal pure returns (uint256 major, uint256 minor, uint256 patch) {
        uint48 packed = uint48(packedVersion);
        major = (packed >> 32) & 0xFFFF;
        minor = (packed >> 16) & 0xFFFF;
        patch = packed & 0xFFFF;
    }

    /**
     * @notice Internal helper function to compare two uint256 values
     * @param a First value
     * @param b Second value
     * @return -1 if a < b, 0 if a == b, 1 if a > b
     */
    function _compare(uint256 a, uint256 b) private pure returns (int8) {
        if (a < b) return -1;
        if (a > b) return 1;
        return 0;
    }
}
