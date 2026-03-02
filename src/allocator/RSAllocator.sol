// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IAllocator } from "the-compact/interfaces/IAllocator.sol";
import { ITheCompact } from "the-compact/interfaces/ITheCompact.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { AllocatorLib } from "./lib/AllocatorLib.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { CompactEIP712 } from "../common/CompactEIP712.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";

/**
 * @title RSAllocator
 * @notice Rhinestone's implementation of a TheCompact Allocator that validates signatures made on claims
 * @dev This contract rebuilds the domain separator from TheCompact and produces the digest for signature validation.
 *      It implements signature-based claim authorization where a designated signer must approve claims.
 *
 *      Key features:
 *      - Signature-based claim authorization using ECDSA
 *      - EIP-712 typed data hashing for secure message signing
 *      - EIP-1271 compliance for contract-based signature validation
 *      - Ownable pattern for signer management
 *      - Integration with TheCompact protocol
 */
contract RSAllocator is Ownable, CompactEIP712 {
    using SignatureCheckerLib for address;

    /// @dev `keccak256("ConsumeNonce(uint256[] nonces)")`.
    bytes32 internal constant TYPEHASH_CONSUMENONCE = 0xc388303b4ae891d202248584dad8838f8418a633b4f603df8eaf6a69ac7c9030;

    error InvalidConstructor();
    error InvalidSignature();

    /**
     * @notice Emitted when the authorized signer address is updated
     * @param newSigner The new signer address
     */
    event SignerUpdated(address newSigner);

    /// @notice The authorized signer address for claim validation
    address public signer;

    /// @notice Constant returned by isValidSignature for invalid signatures (EIP-1271)
    bytes4 internal constant ERROR = bytes4(0xFFFFFFFF);

    /// @notice The unique identifier assigned by TheCompact upon registration
    uint96 public immutable ALLOCATOR_ID;

    /**
     * @notice Initializes the RSAllocator with TheCompact registration
     * @param compact Address of TheCompact contract
     * @param _owner Address that will own the allocator (can update signer)
     * @param _signer Initial signer address for claim validation
     * @dev The constructor registers this allocator with TheCompact and sets up ownership
     */
    constructor(address compact, address _owner, address _signer) CompactEIP712(compact) {
        require(_signer != address(0), InvalidConstructor());
        // Register this allocator with TheCompact and receive a unique ID
        ALLOCATOR_ID = ITheCompact(compact).__registerAllocator(address(this), "");

        // Set the initial authorized signer
        signer = _signer;

        // Initialize ownership using Solady's Ownable
        _initializeOwner(_owner);
    }

    /**
     * @notice Updates the authorized signer address
     * @param _signer New signer address
     * @dev Only the contract owner can call this function
     *      Emits SignerUpdated event after successful update
     */
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), InvalidConstructor());
        // Update the authorized signer
        signer = _signer;

        // Emit event for off-chain monitoring
        emit SignerUpdated(_signer);
    }

    /**
     * @notice Consumes allocator nonces, invalidating any claims that use them
     * @param nonces Array of nonce values to consume
     * @param signature EIP-712 signature from the authorized signer approving the nonce consumption
     * @dev DANGER: This is a potentially dangerous function that gives the allocator the power to break existing compacts.
     *      When a nonce is consumed, any claims that depend on that nonce will become invalid and unable to be processed.
     *      This effectively allows the allocator to revoke or cancel pending claims by invalidating their nonces.
     *
     *      Use cases for this function:
     *      - Emergency cancellation of pending claims
     *      - Revoking access before a claim can be processed
     *      - Invalidating claims that are no longer desired
     *
     *      Security considerations:
     *      - Only the authorized signer can approve nonce consumption via EIP-712 signature
     *      - Nonces are permanently consumed and cannot be reused
     *      - This action is irreversible - consumed nonces cannot be "unconsumed"
     *      - Users relying on claims with these nonces will have their claims fail
     *
     *      The signature must be over the EIP-712 typed data hash:
     *      ConsumeNonce(uint256[] nonces)
     *      combined with TheCompact's domain separator to prevent cross-chain and cross-contract replay attacks.
     */
    function consumeNonce(uint256[] calldata nonces, bytes calldata signature) external {
        // Construct the EIP-712 struct hash: keccak256(abi.encode(TYPEHASH_CONSUMENONCE, keccak256(abi.encodePacked(nonces))))
        // This creates the typed data hash for the ConsumeNonce message with the array of nonces to invalidate
        bytes32 hash = EfficientHashLib.hash(TYPEHASH_CONSUMENONCE, keccak256(abi.encodePacked(nonces)));

        // Wrap the struct hash with TheCompact's domain separator to create the final EIP-712 digest
        // This prevents replay attacks across different chains or contract instances
        bytes32 digest = _compactHashTypedData(hash);

        // Validate that the signature was created by the authorized signer
        // Uses EIP-1271 signature validation which returns the function selector on success
        require(isValidSignature(digest, signature) == this.isValidSignature.selector, InvalidSignature());

        // Forward the nonce consumption request to TheCompact contract
        // This permanently invalidates the nonces, breaking any claims that depend on them
        ITheCompact(COMPACT).consume(nonces);
    }

    /**
     * @notice Checks if a claim is authorized by validating the signature in allocatorData
     * @param claimHash The message hash representing the claim to be authorized
     * @param allocatorData Signature data, optionally prefixed with qualification hash if length > 65 bytes
     * @return bool True if the claim is authorized, false otherwise
     * @dev This function is called by TheCompact to validate claims before processing.
     *      Supports both qualified claims (with qualification hash) and direct signature verification.
     */
    function isClaimAuthorized(
        bytes32 claimHash, // The message hash representing the claim.
        address,
        /* arbiter*/
        // The account tasked with verifying and submitting the claim.
        address,
        /* sponsor*/
        // The account to source the tokens from.
        uint256,
        /* nonce*/
        // A parameter to enforce replay protection, scoped to allocator.
        uint256,
        /* expires*/
        // The time at which the claim expires.
        uint256[2][] calldata,
        /* idsAndAmounts*/
        // The allocated token IDs and amounts.
        bytes calldata allocatorData // Arbitrary data provided by the arbiter.
    )
        external
        view
        returns (bool)
    {
        return _authorizeClaim(claimHash, allocatorData);
    }

    /**
     * @notice Authorizes a claim by validating the signature and returns the function selector if valid
     * @param claimHash The message hash representing the claim to be authorized
     * @param allocatorData Signature data, optionally prefixed with qualification hash if length > 65 bytes
     * @return ret The function selector if authorized, zero bytes otherwise
     * @dev This function is called by TheCompact during claim processing.
     *      Supports both qualified claims (with qualification hash) and direct signature verification.
     */
    function authorizeClaim(
        bytes32 claimHash,
        address, /* arbiter*/
        address, /* sponsor*/
        uint256, /* nonce*/
        uint256, /* expires*/
        uint256[2][] calldata, /* idsAndAmounts*/
        bytes calldata allocatorData
    )
        external
        view
        returns (bytes4 ret)
    {
        // Return the function selector if claim is authorized, zero bytes otherwise
        if (_authorizeClaim(claimHash, allocatorData)) ret = IAllocator.authorizeClaim.selector;
    }

    /**
     * @notice Internal function to validate claim authorization through signature verification
     * @param claimHash The original claim hash to be validated
     * @param allocatorData The signature data, optionally prefixed with qualification hash
     * @return valid True if the signature is valid and matches the authorized signer
     * @dev This function implements the core signature verification logic used by both public authorization functions.
     *      If allocatorData is longer than 65 bytes, the first 32 bytes are treated as a qualification hash
     *      which is combined with the claim hash. Otherwise, the claim hash is used directly for verification.
     */
    function _authorizeClaim(bytes32 claimHash, bytes calldata allocatorData) internal view virtual returns (bool valid) {
        // should allocatorClaimData be larger than an ECDSA signature, we know that the AllocatorQualification is used
        if (allocatorData.length > 65) {
            // Extract the qualification hash from the first 32 bytes of allocatorData
            bytes32 qualificationHash = bytes32(allocatorData[:32]);

            // Remove the qualification hash from allocatorData, leaving only the signature
            allocatorData = allocatorData[32:];

            // Combine the claim hash with the qualification hash using AllocatorLib
            claimHash = AllocatorLib.qualificationHash(claimHash, qualificationHash);
        }

        // Create the EIP-712 typed data hash for signature verification
        bytes32 digest = _compactHashTypedData(claimHash);

        // sload and cache the signer
        address _signer = signer;
        // should for some reason the signer not be set. it should always return false
        if (_signer == address(0)) return false;
        // Recover the signer from the signature and compare with authorized signer
        valid = _signer == ECDSA.recoverCalldata(digest, allocatorData);
    }

    /**
     * @notice EIP-1271 signature validation interface for contract-based signature verification
     * @param digest The message hash to validate
     * @param signature The signature bytes to validate against the digest
     * @return bytes4 The function selector if signature is valid, ERROR constant if invalid
     * @dev This allows the contract to act as a signer for EIP-1271 compliant systems
     *      Returns the function selector (0x1626ba7e) for valid signatures, ERROR (0xFFFFFFFF) for invalid ones
     */
    function isValidSignature(bytes32 digest, bytes calldata signature) public view returns (bytes4) {
        // sload and cache the signer
        address _signer = signer;
        // should for some reason the signer not be set. it should always return false
        if (_signer == address(0)) return ERROR;
        // Recover the signer from the signature and compare with authorized signer
        // Return function selector if valid, ERROR constant if invalid
        return (ECDSA.recoverCalldata(digest, signature) == _signer) ? this.isValidSignature.selector : ERROR;
    }
}
