// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RSAllocator_Unit_Test } from "test/unit/allocator/RSAllocator/RSAllocator.t.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";
import { IAllocator } from "the-compact/interfaces/IAllocator.sol";

contract RSAllocator_SetSigner_Unit_Test is RSAllocator_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SignerUpdated(address newSigner);

    /* //////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setSigner() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(wrongSigner);
        allocator.setSigner(wrongSigner);

        assertEq(allocator.signer(), wrongSigner);
    }

    function test_setSigner_RevertsWhen_OnlyOwner() public {
        vm.prank(signer);
        vm.expectRevert();
        allocator.setSigner(wrongSigner);
    }

    function test_signerUpdate_AffectsValidation() public {
        // First, create a valid signature with the current signer
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        // Verify it works with current signer
        assertTrue(allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData));

        // Change signer
        vm.prank(owner);
        allocator.setSigner(wrongSigner);

        // Same signature should now fail
        assertFalse(allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData));

        // But signature from new signer should work
        (v, r, s) = vm.sign(wrongSignerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
        allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        assertTrue(allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData));
    }

    function test_setSigner_RevertsWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(RSAllocator.InvalidConstructor.selector);
        allocator.setSigner(address(0));
    }

    function test_setSigner_MultipleTimes() public {
        address signer1 = makeAddr("signer1");
        address signer2 = makeAddr("signer2");
        address signer3 = makeAddr("signer3");

        // First update
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(signer1);
        allocator.setSigner(signer1);
        assertEq(allocator.signer(), signer1);

        // Second update
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(signer2);
        allocator.setSigner(signer2);
        assertEq(allocator.signer(), signer2);

        // Third update
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(signer3);
        allocator.setSigner(signer3);
        assertEq(allocator.signer(), signer3);
    }

    function test_setSigner_ToSameAddress() public {
        // Set signer to the same address it already is
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(signer);
        allocator.setSigner(signer);

        assertEq(allocator.signer(), signer);
    }

    function test_setSigner_RevertsWhen_NonOwnerAttempts() public {
        address randomUser = makeAddr("randomUser");

        // Random user tries to set signer
        vm.prank(randomUser);
        vm.expectRevert(); // Ownable will revert
        allocator.setSigner(wrongSigner);

        // Verify signer unchanged
        assertEq(allocator.signer(), signer);

        // Even the current signer can't change the signer
        vm.prank(signer);
        vm.expectRevert(); // Ownable will revert
        allocator.setSigner(wrongSigner);

        // Verify signer still unchanged
        assertEq(allocator.signer(), signer);
    }

    function test_setSigner_AffectsIsValidSignature() public {
        bytes32 digest = keccak256("test message");

        // Create signature with current signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should be valid with current signer
        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);

        // Change signer
        vm.prank(owner);
        allocator.setSigner(wrongSigner);

        // Same signature should now be invalid
        result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));

        // But new signer's signature should work
        (v, r, s) = vm.sign(wrongSignerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);

        result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_setSigner_AffectsAuthorizeClaim() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Create signature with current signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        // Should work with current signer
        bytes4 result = allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);
        assertEq(result, IAllocator.authorizeClaim.selector);

        // Change signer
        vm.prank(owner);
        allocator.setSigner(wrongSigner);

        // Same signature should now fail
        result = allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);
        assertEq(result, bytes4(0));

        // But new signer's signature should work
        (v, r, s) = vm.sign(wrongSignerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
        allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        result = allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);
        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_setSigner_ValidAddress(address newSigner) public {
        vm.assume(newSigner != address(0));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(newSigner);
        allocator.setSigner(newSigner);

        assertEq(allocator.signer(), newSigner);
    }

    function testFuzz_setSigner_RevertsWhen_OnlyOwnerCanSet(address caller, address newSigner) public {
        vm.assume(caller != owner);
        vm.assume(newSigner != address(0));

        vm.prank(caller);
        vm.expectRevert(); // Ownable will revert
        allocator.setSigner(newSigner);

        // Verify signer unchanged
        assertEq(allocator.signer(), signer);
    }
}
