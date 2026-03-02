// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RSAllocator_Unit_Test } from "test/unit/allocator/RSAllocator/RSAllocator.t.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";

// Interfaces
import { IAllocator } from "the-compact/interfaces/IAllocator.sol";

contract RSAllocator_AuthorizeClaim_Unit_Test is RSAllocator_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_authorizeClaim_ValidSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    function test_authorizeClaim_InvalidSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Sign with wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertEq(result, bytes4(0));
    }

    function test_authorizeClaim_ValidCompactSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    function test_authorizeClaim_InvalidCompactSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Sign with wrong signer
        (bytes32 r, bytes32 vs) = vm.signCompact(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertEq(result, bytes4(0));
    }

    function test_authorizeClaim_DirectSignature() public view {
        // Sign the claim hash directly (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature // Just the signature, no qualification hash
        );

        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    function test_authorizeClaim_DirectCompactSignature() public view {
        // Sign the claim hash directly with compact signature (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.authorizeClaim(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature // Just the compact signature, no qualification hash
        );

        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    function test_MixedSignatureFormats() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Test that both standard and compact signatures work for same message

        // Standard signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory standardSignature = abi.encodePacked(r, s, v);
        bytes memory standardAllocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, standardSignature);

        // Compact signature
        (bytes32 rCompact, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory compactSignature = abi.encodePacked(rCompact, vs);
        bytes memory compactAllocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, compactSignature);

        // Both should return the same result for authorizeClaim
        bytes4 standardResult =
            allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), standardAllocatorData);

        bytes4 compactResult =
            allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), compactAllocatorData);

        assertEq(standardResult, compactResult);
        assertEq(standardResult, IAllocator.authorizeClaim.selector);
    }

    function test_authorizeClaim_WrongClaimHash() public view {
        // Test with wrong claim hash (signature is for a different claim)
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        // Use different claim hash than what was signed
        bytes32 wrongClaimHash = keccak256("wrong_claim");

        bytes4 result = allocator.authorizeClaim(
            wrongClaimHash, // Wrong claim hash
            address(0),
            address(0),
            0,
            0,
            new uint256[2][](0),
            allocatorData
        );

        assertEq(result, bytes4(0), "Should return zero for wrong claim hash");
    }

    function test_authorizeClaim_EmptyAllocatorData() public {
        // Test with empty allocator data
        bytes memory emptyData = "";

        vm.expectRevert();
        allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), emptyData);
    }

    function test_authorizeClaim_MalformedSignature() public {
        // Test with signature that's too short
        bytes memory malformedSig = hex"1234";

        vm.expectRevert();
        allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), malformedSig);
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_authorizeClaim_ValidSignature(
        bytes32 claimHash,
        bytes32 qualificationHash,
        uint256 nonce,
        uint256 expires
    )
        public
        view
    {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(qualificationHash, signature);

        bytes4 result = allocator.authorizeClaim(claimHash, address(0), address(0), nonce, expires, new uint256[2][](0), allocatorData);

        assertEq(result, IAllocator.authorizeClaim.selector);
    }

    function testFuzz_authorizeClaim_InvalidSigner(bytes32 claimHash, bytes32 qualificationHash, uint256 wrongPrivateKey) public view {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(qualificationHash, signature);

        bytes4 result = allocator.authorizeClaim(claimHash, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);

        assertEq(result, bytes4(0));
    }

    function testFuzz_authorizeClaim_DirectSignature(bytes32 claimHash) public view {
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), claimHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.authorizeClaim(claimHash, address(0), address(0), 0, 0, new uint256[2][](0), signature);

        assertEq(result, IAllocator.authorizeClaim.selector);
    }
}
