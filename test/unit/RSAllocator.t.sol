// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";
import "@rhinestone/compact-utils/src/allocator/lib/AllocatorLib.sol";
import "the-compact/interfaces/IAllocator.sol";
import "the-compact/interfaces/ITheCompact.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract RSAllocatorTest is CompactEnvironment {
    RSAllocator public allocator;

    address public owner;
    address public signer;
    address public wrongSigner;
    uint256 public signerPrivateKey;
    uint256 public wrongSignerPrivateKey;

    bytes32 public constant TEST_CLAIM_HASH = keccak256("test_claim");
    bytes32 public constant TEST_QUALIFICATION_HASH = keccak256("test_qualification");

    event SignerUpdated(address newSigner);

    function setUp() public {
        _deployCompact();

        owner = makeAddr("owner");
        (signer, signerPrivateKey) = makeAddrAndKey("signer");
        (wrongSigner, wrongSignerPrivateKey) = makeAddrAndKey("wrongSigner");

        allocator = new RSAllocator(address(env.compact), owner, signer);
    }

    function test_Constructor() public view {
        assertEq(allocator.owner(), owner);
        assertEq(allocator.signer(), signer);
        // ALLOCATOR_ID will vary based on when this test runs, just verify it's > 0
        assertTrue(allocator.ALLOCATOR_ID() > 0);
    }

    function test_SetSigner() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(wrongSigner);
        allocator.setSigner(wrongSigner);

        assertEq(allocator.signer(), wrongSigner);
    }

    function test_SetSigner_OnlyOwner() public {
        vm.prank(signer);
        vm.expectRevert();
        allocator.setSigner(wrongSigner);
    }

    function test_IsClaimAuthorized_ValidSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsClaimAuthorized_InvalidSignature_WrongSigner() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsClaimAuthorized_InvalidSignature_WrongClaimHash() public {
        bytes32 wrongClaimHash = keccak256("wrong_claim");
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsClaimAuthorized_InvalidSignature_WrongQualificationHash() public {
        bytes32 wrongQualificationHash = keccak256("wrong_qualification");
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsClaimAuthorized_InvalidSignature_MalformedData() public {
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

    function test_IsClaimAuthorized_InvalidSignature_EmptyData() public {
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

    function test_AuthorizeClaim_ValidSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_AuthorizeClaim_InvalidSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsValidSignature_ValidSignature() public {
        bytes32 digest = keccak256("test message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_IsValidSignature_InvalidSignature() public {
        bytes32 digest = keccak256("test message");

        // Sign with wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function test_IsValidSignature_MalformedSignature() public {
        bytes32 digest = keccak256("test message");
        bytes memory malformedSignature = abi.encodePacked(hex"1234");

        vm.expectRevert();
        allocator.isValidSignature(digest, malformedSignature);
    }

    function testFuzz_IsClaimAuthorized_ValidSignature(
        bytes32 claimHash,
        bytes32 qualificationHash,
        uint256 nonce,
        uint256 expires
    )
        public
    {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function testFuzz_IsClaimAuthorized_InvalidSigner(bytes32 claimHash, bytes32 qualificationHash, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function testFuzz_IsValidSignature_ValidSignature(bytes32 digest) public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function testFuzz_IsValidSignature_InvalidSigner(bytes32 digest, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function test_SignerUpdate_AffectsValidation() public {
        // First, create a valid signature with the current signer
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    // Tests using vm.signCompact() for compact signatures
    function test_IsClaimAuthorized_ValidCompactSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsClaimAuthorized_InvalidCompactSignature_WrongSigner() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_AuthorizeClaim_ValidCompactSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_AuthorizeClaim_InvalidCompactSignature() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function test_IsValidSignature_ValidCompactSignature() public {
        bytes32 digest = keccak256("test message");

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function test_IsValidSignature_InvalidCompactSignature() public {
        bytes32 digest = keccak256("test message");

        // Sign with wrong signer
        (bytes32 r, bytes32 vs) = vm.signCompact(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function testFuzz_IsClaimAuthorized_ValidCompactSignature(
        bytes32 claimHash,
        bytes32 qualificationHash,
        uint256 nonce,
        uint256 expires
    )
        public
    {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function testFuzz_IsClaimAuthorized_InvalidCompactSigner(bytes32 claimHash, bytes32 qualificationHash, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 qualifiedHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

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

    function testFuzz_IsValidSignature_ValidCompactSignature(bytes32 digest) public {
        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, allocator.isValidSignature.selector);
    }

    function testFuzz_IsValidSignature_InvalidCompactSigner(bytes32 digest, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        (bytes32 r, bytes32 vs) = vm.signCompact(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        bytes4 result = allocator.isValidSignature(digest, signature);
        assertEq(result, bytes4(0xFFFFFFFF));
    }

    function test_MixedSignatureFormats() public {
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));

        // Test that both standard and compact signatures work for same message

        // Standard signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory standardSignature = abi.encodePacked(r, s, v);
        bytes memory standardAllocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, standardSignature);

        // Compact signature
        (bytes32 rCompact, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory compactSignature = abi.encodePacked(rCompact, vs);
        bytes memory compactAllocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, compactSignature);

        // Both should work
        assertTrue(allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), standardAllocatorData));

        assertTrue(allocator.isClaimAuthorized(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), compactAllocatorData));

        // Both should return the same result for authorizeClaim
        bytes4 standardResult =
            allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), standardAllocatorData);

        bytes4 compactResult =
            allocator.authorizeClaim(TEST_CLAIM_HASH, address(0), address(0), 0, 0, new uint256[2][](0), compactAllocatorData);

        assertEq(standardResult, compactResult);
        assertEq(standardResult, IAllocator.authorizeClaim.selector);
    }

    // Tests for direct signature validation (without qualification hash)
    function test_IsClaimAuthorized_DirectSignature() public {
        // Sign the claim hash directly (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

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

    function test_IsClaimAuthorized_DirectCompactSignature() public {
        // Sign the claim hash directly with compact signature (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

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

    function test_AuthorizeClaim_DirectSignature() public {
        // Sign the claim hash directly (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

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

    function test_AuthorizeClaim_DirectCompactSignature() public {
        // Sign the claim hash directly with compact signature (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

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

    function test_IsClaimAuthorized_DirectSignature_WrongSigner() public {
        // Sign the claim hash directly with wrong signer (no qualification hash)
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));

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

    function test_QualificationHashConditional() public {
        // Test that the same claim hash produces different results with and without qualification hash

        // Direct signature (claim hash only)
        bytes32 directDigest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), TEST_CLAIM_HASH));
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signerPrivateKey, directDigest);
        bytes memory directSignature = abi.encodePacked(r1, s1, v1);

        // Qualified signature (claim hash + qualification hash)
        bytes32 qualifiedHash = AllocatorLib.qualificationHash(TEST_CLAIM_HASH, TEST_QUALIFICATION_HASH);
        bytes32 qualifiedDigest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), qualifiedHash));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signerPrivateKey, qualifiedDigest);
        bytes memory qualifiedSignature = abi.encodePacked(r2, s2, v2);
        bytes memory qualifiedAllocatorData = abi.encodePacked(TEST_QUALIFICATION_HASH, qualifiedSignature);

        // Both should work for their respective scenarios
        assertTrue(
            allocator.isClaimAuthorized(
                TEST_CLAIM_HASH,
                address(0),
                address(0),
                0,
                0,
                new uint256[2][](0),
                directSignature // 65 bytes - direct signature
            )
        );

        assertTrue(
            allocator.isClaimAuthorized(
                TEST_CLAIM_HASH,
                address(0),
                address(0),
                0,
                0,
                new uint256[2][](0),
                qualifiedAllocatorData // 97 bytes - qualification hash + signature
            )
        );

        // But they shouldn't work cross-ways
        assertFalse(
            allocator.isClaimAuthorized(
                TEST_CLAIM_HASH,
                address(0),
                address(0),
                0,
                0,
                new uint256[2][](0),
                qualifiedSignature // Wrong: using qualified signature directly
            )
        );
    }

    function testFuzz_IsClaimAuthorized_DirectSignature(bytes32 claimHash) public {
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), claimHash));

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

    function testFuzz_IsClaimAuthorized_DirectSignature_InvalidSigner(bytes32 claimHash, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), claimHash));

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

    // Tests for consumeNonce function
    function test_ConsumeNonce_SingleNonce_ValidSignature() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 123;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonce is not consumed before
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));

        // Consume the nonce
        allocator.consumeNonce(nonces, signature);

        // Verify nonce is consumed after
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
    }

    function test_ConsumeNonce_MultipleNonces_ValidSignature() public {
        uint256[] memory nonces = new uint256[](3);
        nonces[0] = 100;
        nonces[1] = 200;
        nonces[2] = 300;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonces are not consumed before
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[1], address(allocator)));
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[2], address(allocator)));

        // Consume the nonces
        allocator.consumeNonce(nonces, signature);

        // Verify all nonces are consumed after
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[1], address(allocator)));
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[2], address(allocator)));
    }

    function test_ConsumeNonce_InvalidSignature_WrongSigner() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 123;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        // Sign with wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with InvalidSignature
        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, signature);

        // Verify nonce is not consumed
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
    }

    function test_ConsumeNonce_InvalidSignature_WrongNonces() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 123;

        uint256[] memory differentNonces = new uint256[](1);
        differentNonces[0] = 456;

        // Sign for nonces, but try to consume differentNonces
        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with InvalidSignature
        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(differentNonces, signature);

        // Verify neither nonce is consumed
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
        assertFalse(env.compact.hasConsumedAllocatorNonce(differentNonces[0], address(allocator)));
    }

    function test_ConsumeNonce_CompactSignature() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 123;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (bytes32 r, bytes32 vs) = vm.signCompact(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        // Verify nonce is not consumed before
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));

        // Consume the nonce
        allocator.consumeNonce(nonces, signature);

        // Verify nonce is consumed after
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
    }

    function testFuzz_ConsumeNonce_ValidSignature(uint256 nonce) public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = nonce;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonce is not consumed before
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonce, address(allocator)));

        // Consume the nonce
        allocator.consumeNonce(nonces, signature);

        // Verify nonce is consumed after
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonce, address(allocator)));
    }

    function testFuzz_ConsumeNonce_InvalidSigner(uint256 nonce, uint256 wrongPrivateKey) public {
        vm.assume(wrongPrivateKey != 0);
        vm.assume(wrongPrivateKey != signerPrivateKey);
        vm.assume(wrongPrivateKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);

        uint256[] memory nonces = new uint256[](1);
        nonces[0] = nonce;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with InvalidSignature
        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, signature);

        // Verify nonce is not consumed
        assertFalse(env.compact.hasConsumedAllocatorNonce(nonce, address(allocator)));
    }

    function test_ConsumeNonce_ReplayAttack_ShouldRevert() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 123;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First consumption should succeed
        allocator.consumeNonce(nonces, signature);
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));

        // Second consumption with the same signature should revert
        vm.expectRevert();
        allocator.consumeNonce(nonces, signature);
    }

    function test_ConsumeNonce_MultipleNonces_ReplayAttack_ShouldRevert() public {
        uint256[] memory nonces = new uint256[](3);
        nonces[0] = 100;
        nonces[1] = 200;
        nonces[2] = 300;

        bytes32 hash = keccak256(abi.encode(keccak256("ConsumeNonce(uint256[] nonces)"), keccak256(abi.encodePacked(nonces))));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), env.compact.DOMAIN_SEPARATOR(), hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First consumption should succeed
        allocator.consumeNonce(nonces, signature);
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[0], address(allocator)));
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[1], address(allocator)));
        assertTrue(env.compact.hasConsumedAllocatorNonce(nonces[2], address(allocator)));

        // Second consumption with the same signature should revert
        vm.expectRevert();
        allocator.consumeNonce(nonces, signature);
    }
}
