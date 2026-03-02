pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/common/semver/SemVer.sol";
import "../../src/common/semver/SemVerCmp.sol";

contract SemVerCmpTest is Test {
    SemVer semver1;
    SemVer semver2;
    SemVer semver3;

    function setUp() public {
        semver1 = new SemVer(2, 3); // v1.2.3
        semver2 = new SemVer(1, 0); // v1.1.0
        semver3 = new SemVer(2, 3); // v1.2.3 (same as semver1)
    }

    // Tests for bytes6 API
    function test_semVerCmp_bytes6_allEqual() public {
        bytes6 version = SemVerCmp.packVersion(1, 2, 3);
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(version, address(semver1));

        assertEq(majorCmp, 0, "Major should be equal");
        assertEq(minorCmp, 0, "Minor should be equal");
        assertEq(patchCmp, 0, "Patch should be equal");
    }

    function test_semVerCmp_bytes6_allLower() public {
        bytes6 version = SemVerCmp.packVersion(0, 1, 2);
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(version, address(semver1));

        assertEq(majorCmp, -1, "Major should be lower");
        assertEq(minorCmp, -1, "Minor should be lower");
        assertEq(patchCmp, -1, "Patch should be lower");
    }

    function test_semVerCmp_bytes6_allHigher() public {
        bytes6 version = SemVerCmp.packVersion(2, 3, 4);
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(version, address(semver1));

        assertEq(majorCmp, 1, "Major should be higher");
        assertEq(minorCmp, 1, "Minor should be higher");
        assertEq(patchCmp, 1, "Patch should be higher");
    }

    function test_isOnlyPatch_bytes6_true() public {
        bytes6 version = SemVerCmp.packVersion(1, 2, 4);
        bool result = SemVerCmp.isOnlyPatch(version, address(semver1));
        assertTrue(result, "Should be only patch upgrade");
    }

    function test_isOnlyPatch_bytes6_false() public {
        bytes6 version = SemVerCmp.packVersion(1, 3, 4);
        bool result = SemVerCmp.isOnlyPatch(version, address(semver1));
        assertFalse(result, "Should not be only patch upgrade when minor differs");
    }

    function test_isOnlyMinor_bytes6_true() public {
        bytes6 version = SemVerCmp.packVersion(1, 3, 0);
        bool result = SemVerCmp.isOnlyMinor(version, address(semver1));
        assertTrue(result, "Should be only minor upgrade");
    }

    function test_isOnlyMinor_bytes6_false() public {
        bytes6 version = SemVerCmp.packVersion(2, 3, 0);
        bool result = SemVerCmp.isOnlyMinor(version, address(semver1));
        assertFalse(result, "Should not be only minor upgrade when major differs");
    }

    function test_packUnpack_utility() public {
        bytes6 packed = SemVerCmp.packVersion(12_345, 54_321, 9876);
        (uint256 major, uint256 minor, uint256 patch) = SemVerCmp.unpackVersion(packed);
        assertEq(major, 12_345, "Major should be preserved");
        assertEq(minor, 54_321, "Minor should be preserved");
        assertEq(patch, 9876, "Patch should be preserved");
    }

    function test_packVersion_revert_majorTooLarge() public {
        vm.expectRevert();
        SemVerCmp.packVersion(65_536, 1, 1);
    }

    function test_packVersion_revert_minorTooLarge() public {
        vm.expectRevert();
        SemVerCmp.packVersion(1, 65_536, 1);
    }

    function test_packVersion_revert_patchTooLarge() public {
        vm.expectRevert();
        SemVerCmp.packVersion(1, 1, 65_536);
    }

    // Backward compatibility tests for individual component API
    function test_semVerCmp_allEqual() public {
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(1, 2, 3, address(semver1));

        assertEq(majorCmp, 0, "Major should be equal");
        assertEq(minorCmp, 0, "Minor should be equal");
        assertEq(patchCmp, 0, "Patch should be equal");
    }

    function test_semVerCmp_allLower() public {
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(0, 1, 2, address(semver1));

        assertEq(majorCmp, -1, "Major should be lower");
        assertEq(minorCmp, -1, "Minor should be lower");
        assertEq(patchCmp, -1, "Patch should be lower");
    }

    function test_semVerCmp_allHigher() public {
        (int8 majorCmp, int8 minorCmp, int8 patchCmp) = SemVerCmp.semVerCmp(2, 3, 4, address(semver1));

        assertEq(majorCmp, 1, "Major should be higher");
        assertEq(minorCmp, 1, "Minor should be higher");
        assertEq(patchCmp, 1, "Patch should be higher");
    }

    function test_isOnlyPatch_true() public {
        bool result = SemVerCmp.isOnlyPatch(1, 2, 4, address(semver1));
        assertTrue(result, "Should be only patch upgrade");
    }

    function test_isOnlyMinor_true() public {
        bool result = SemVerCmp.isOnlyMinor(1, 3, 0, address(semver1));
        assertTrue(result, "Should be only minor upgrade");
    }
}
