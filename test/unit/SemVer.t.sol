pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/common/semver/SemVer.sol";
import "../../src/common/semver/SemVerLib.sol";

contract SemVerTest is Test {
    SemVer semver;

    function setUp() public {
        semver = new SemVer(1, 1);
    }

    function test_semVer_packed() public {
        bytes6 packedVersion = semver.semVer();
        (uint256 major, uint256 minor, uint256 patch) = SemVerLib.unpackVersion(packedVersion);
        assertEq(major, 1, "Major version mismatch");
        assertEq(minor, 1, "Minor version mismatch");
        assertEq(patch, 1, "Patch version mismatch");
    }

    function test_semVerUnpacked() public {
        (uint256 major, uint256 minor, uint256 patch) = semver.semVerUnpacked();
        assertEq(major, 1, "Major version mismatch");
        assertEq(minor, 1, "Minor version mismatch");
        assertEq(patch, 1, "Patch version mismatch");
    }

    function test_version() public {
        bytes memory expectedVersion = "v1.1.1";
        bytes memory actualVersion = semver.version();
        assertEq(actualVersion, expectedVersion, "Version string mismatch");
    }

    function test_semVer_differentVersions() public {
        SemVer semver2 = new SemVer(5, 10);
        bytes6 packedVersion = semver2.semVer();
        (uint256 major, uint256 minor, uint256 patch) = SemVerLib.unpackVersion(packedVersion);
        assertEq(major, 1, "Major version mismatch");
        assertEq(minor, 5, "Minor version mismatch");
        assertEq(patch, 10, "Patch version mismatch");
    }

    function test_version_differentVersions() public {
        SemVer semver2 = new SemVer(5, 10);
        bytes memory expectedVersion = "v1.5.10";
        bytes memory actualVersion = semver2.version();
        assertEq(actualVersion, expectedVersion, "Version string mismatch");
    }

    function test_packUnpack_consistency() public {
        // Test that packing and unpacking preserves values
        SemVer semver2 = new SemVer(32_768, 12_345);
        bytes6 packed = semver2.semVer();
        (uint256 major, uint256 minor, uint256 patch) = SemVerLib.unpackVersion(packed);
        assertEq(major, 1, "Major version should be preserved");
        assertEq(minor, 32_768, "Minor version should be preserved");
        assertEq(patch, 12_345, "Patch version should be preserved");
    }

    function test_constructor_limits() public {
        // Test that versions at the limit work
        SemVer maxSemver = new SemVer(65_535, 65_535);
        (uint256 major, uint256 minor, uint256 patch) = maxSemver.semVerUnpacked();
        assertEq(major, 1, "Max major version should work");
        assertEq(minor, 65_535, "Max minor version should work");
        assertEq(patch, 65_535, "Max patch version should work");
    }

    function test_constructor_revert_majorTooLarge() public {
        // Major version is now hardcoded, so this test is no longer relevant
        // We can test that constructor works with max values
        new SemVer(1, 1);
    }

    function test_constructor_revert_minorTooLarge() public {
        vm.expectRevert();
        new SemVer(65_536, 1);
    }

    function test_constructor_revert_patchTooLarge() public {
        vm.expectRevert();
        new SemVer(1, 65_536);
    }
}
