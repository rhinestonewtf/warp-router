// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RSAllocator_Unit_Test } from "test/unit/allocator/RSAllocator/RSAllocator.t.sol";

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";

contract RSAllocator_ConsumeNonce_Unit_Test is RSAllocator_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev `keccak256("ConsumeNonce(uint256[] nonces)")`.
    bytes32 internal constant TYPEHASH_CONSUMENONCE = 0xc388303b4ae891d202248584dad8838f8418a633b4f603df8eaf6a69ac7c9030;

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _signConsumeNonce(uint256[] memory nonces, uint256 privateKey) internal view returns (bytes memory) {
        bytes32 structHash = EfficientHashLib.hash(TYPEHASH_CONSUMENONCE, keccak256(abi.encodePacked(nonces)));
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), mockCompact.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /* //////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_consumeNonce_SingleNonce() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        bytes memory signature = _signConsumeNonce(nonces, signerPrivateKey);

        allocator.consumeNonce(nonces, signature);

        assertTrue(mockCompact.consumedNonces(42));
    }

    function test_consumeNonce_MultipleNonces() public {
        uint256[] memory nonces = new uint256[](3);
        nonces[0] = 1;
        nonces[1] = 2;
        nonces[2] = 3;

        bytes memory signature = _signConsumeNonce(nonces, signerPrivateKey);

        allocator.consumeNonce(nonces, signature);

        assertTrue(mockCompact.consumedNonces(1));
        assertTrue(mockCompact.consumedNonces(2));
        assertTrue(mockCompact.consumedNonces(3));
    }

    function test_consumeNonce_RevertsWhen_WrongSigner() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        bytes memory signature = _signConsumeNonce(nonces, wrongSignerPrivateKey);

        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, signature);
    }

    function test_consumeNonce_RevertsWhen_SignatureForDifferentNonces() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        // Sign for different nonces
        uint256[] memory differentNonces = new uint256[](1);
        differentNonces[0] = 99;
        bytes memory signature = _signConsumeNonce(differentNonces, signerPrivateKey);

        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, signature);
    }

    function test_consumeNonce_RevertsWhen_EmptySignature() public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        vm.expectRevert();
        allocator.consumeNonce(nonces, "");
    }

    function test_consumeNonce_AnyoneCanCall() public {
        // consumeNonce has no access control — anyone can submit a valid signature
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        bytes memory signature = _signConsumeNonce(nonces, signerPrivateKey);

        address random = makeAddr("random");
        vm.prank(random);
        allocator.consumeNonce(nonces, signature);

        assertTrue(mockCompact.consumedNonces(42));
    }

    function test_consumeNonce_WorksAfterSignerChange() public {
        // Change signer
        vm.prank(owner);
        allocator.setSigner(wrongSigner);

        // Old signer's signature should fail
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        bytes memory oldSig = _signConsumeNonce(nonces, signerPrivateKey);
        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, oldSig);

        // New signer's signature should succeed
        bytes memory newSig = _signConsumeNonce(nonces, wrongSignerPrivateKey);
        allocator.consumeNonce(nonces, newSig);

        assertTrue(mockCompact.consumedNonces(42));
    }

    /* //////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_consumeNonce(uint256 nonce) public {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = nonce;

        bytes memory signature = _signConsumeNonce(nonces, signerPrivateKey);

        allocator.consumeNonce(nonces, signature);

        assertTrue(mockCompact.consumedNonces(nonce));
    }

    function testFuzz_consumeNonce_RevertsWhen_WrongSigner(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint248).max);
        vm.assume(privateKey != signerPrivateKey);

        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 42;

        bytes memory signature = _signConsumeNonce(nonces, privateKey);

        vm.expectRevert(RSAllocator.InvalidSignature.selector);
        allocator.consumeNonce(nonces, signature);
    }
}
