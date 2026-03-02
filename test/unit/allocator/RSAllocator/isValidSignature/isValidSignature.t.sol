// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RSAllocator_Unit_Test } from "test/unit/allocator/RSAllocator/RSAllocator.t.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";

contract RSAllocator_IsValidSignature_Unit_Test is RSAllocator_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidSignature();

    /* //////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_ValidSignature() public view {
        bytes32 digest = keccak256("test message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_isValidSignature_InvalidSignature() public view {
        bytes32 digest = keccak256("test message");

        // Sign with wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function test_isValidSignature_RevertsWhen_MalformedSignature() public {
        bytes32 digest = keccak256("test message");
        bytes memory malformedSignature = abi.encodePacked(hex"1234");

        vm.expectRevert(InvalidSignature.selector);
        allocator.isValidSignature(digest, malformedSignature);
    }

    function test_isValidSignature_ValidCompactSignature() public view {
        bytes32 digest = keccak256("test message");

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_isValidSignature_InvalidCompactSignature() public view {
        bytes32 digest = keccak256("test message");

        // Sign with wrong signer
        (bytes32 r, bytes32 vs) = vm.signCompact(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function test_isValidSignature_RevertsWhen_EmptySignature() public {
        bytes32 digest = keccak256("test message");
        bytes memory emptySignature = "";

        vm.expectRevert(InvalidSignature.selector);
        allocator.isValidSignature(digest, emptySignature);
    }

    function test_isValidSignature_SignatureTooLong() public {
        bytes32 digest = keccak256("test message");

        // Create a signature that's longer than expected (65 bytes + extra)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory longSignature = abi.encodePacked(r, s, v, hex"deadbeef");

        vm.expectRevert(InvalidSignature.selector);
        allocator.isValidSignature(digest, longSignature);
    }

    function test_isValidSignature_WithZeroDigest() public view {
        bytes32 zeroDigest = bytes32(0);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, zeroDigest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(zeroDigest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_isValidSignature_WithMaxDigest() public view {
        bytes32 maxDigest = bytes32(type(uint256).max);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, maxDigest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(maxDigest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_isValidSignature_ValidSignature(bytes32 digest) public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function testFuzz_isValidSignature_InvalidSigner(bytes32 digest, uint256 wrongPrivateKey) public view {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function testFuzz_isValidSignature_ValidCompactSignature(bytes32 digest) public view {
        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function testFuzz_isValidSignature_InvalidCompactSigner(bytes32 digest, uint256 wrongPrivateKey) public view {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        (bytes32 r, bytes32 vs) = vm.signCompact(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }
}
