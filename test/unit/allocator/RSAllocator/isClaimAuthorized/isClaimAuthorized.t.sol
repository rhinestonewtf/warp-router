// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RSAllocator_Unit_Test } from "test/unit/allocator/RSAllocator/RSAllocator.t.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";
import { AllocatorLib } from "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";

contract RSAllocator_IsClaimAuthorized_Unit_Test is RSAllocator_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isClaimAuthorized_ValidSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertTrue(result);
    }

    function test_isClaimAuthorized_InvalidSignature_WrongSigner() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Sign with wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function test_isClaimAuthorized_InvalidSignature_WrongClaimHash() public view {
        bytes32 wrongClaimHash = keccak256("wrong_claim");
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        // Use wrong claim hash
        bool result = allocator.isClaimAuthorized(
            wrongClaimHash,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function test_isClaimAuthorized_InvalidSignature_WrongQualificationHash() public view {
        bytes32 wrongQualificationHash = keccak256("wrong_qualification");
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // Use wrong qualification hash in allocator data
        bytes memory allocatorData = abi.encodePacked(wrongQualificationHash, signature);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function test_isClaimAuthorized_InvalidSignature_MalformedData() public {
        // Test with allocator data that's too short (less than 32 bytes)
        bytes memory malformedData = abi.encodePacked(hex"1234");

        vm.expectRevert();
        allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            malformedData
        );
    }

    function test_isClaimAuthorized_InvalidSignature_EmptyData() public {
        bytes memory emptyData = "";

        vm.expectRevert();
        allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            emptyData
        );
    }

    function test_isClaimAuthorized_ValidCompactSignature() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertTrue(result);
    }

    function test_isClaimAuthorized_InvalidCompactSignature_WrongSigner() public view {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Sign with wrong signer
        (bytes32 r, bytes32 vs) = vm.signCompact(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, signature);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function test_isClaimAuthorized_DirectSignature() public view {
        // Sign the claim hash directly (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature // Just the signature, no qualification hash
        );

        assertTrue(result);
    }

    function test_isClaimAuthorized_DirectCompactSignature() public view {
        // Sign the claim hash directly with compact signature (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature // Just the compact signature, no qualification hash
        );

        assertTrue(result);
    }

    function test_isClaimAuthorized_DirectSignature_WrongSigner() public view {
        // Sign the claim hash directly with wrong signer (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool result = allocator.isClaimAuthorized(
            TEST_CLAIM_HASH,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature // Just the signature, no qualification hash
        );

        assertFalse(result);
    }

    function test_isClaimAuthorized_BoundaryCase_66Bytes() public {
        // Test just above the 65-byte boundary (should be treated as qualified)
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // Add just 1 byte to make it 66 bytes total (partial qualification hash)
        bytes memory allocatorData = abi.encodePacked(bytes1(0x00), signature);

        assertEq(allocatorData.length, 66, "Should be 66 bytes");

        // This should fail as it's trying to use first 32 bytes as qualification hash
        // but it's only 1 byte + 65 byte signature
        vm.expectRevert();
        allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);
    }

    function test_isClaimAuthorized_WithZeroQualificationHash() public view {
        // Test with a zero qualification hash (valid edge case)
        bytes32 zeroQualHash = bytes32(0);
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, zeroQualHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(zeroQualHash, signature);

        bool result = allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), allocatorData);

        assertTrue(result, "Should handle zero qualification hash");
    }

    /* //////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_IsClaimAuthorized_ValidSignature(
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

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            nonce,
            expires,
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertTrue(result);
    }

    function testFuzz_IsClaimAuthorized_InvalidSigner(bytes32 claimHash, bytes32 qualificationHash, uint256 wrongPrivateKey) public view {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory allocatorData = abi.encodePacked(qualificationHash, signature);

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function testFuzz_IsClaimAuthorized_ValidCompactSignature(
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

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(qualificationHash, signature);

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            nonce,
            expires,
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertTrue(result);
    }

    function testFuzz_IsClaimAuthorized_InvalidCompactSigner(
        bytes32 claimHash,
        bytes32 qualificationHash,
        uint256 wrongPrivateKey
    )
        public
        view
    {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), qualifiedHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes memory allocatorData = abi.encodePacked(qualificationHash, signature);

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            allocatorData
        );

        assertFalse(result);
    }

    function testFuzz_IsClaimAuthorized_DirectSignature(bytes32 claimHash) public view {
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), claimHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature
        );

        assertTrue(result);
    }

    function testFuzz_IsClaimAuthorized_DirectSignature_InvalidSigner(bytes32 claimHash, uint256 wrongPrivateKey) public view {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), claimHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool result = allocator.isClaimAuthorized(
            claimHash,
            address(0), // arbiter
            address(0), // sponsor
            0, // nonce
            0, // expires
            new uint256[2][](0), // idsAndAmounts
            signature
        );

        assertFalse(result);
    }
}
