// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RSAllocator } from "@rhinestone/compact-utils/src/allocator/RSAllocator.sol";

// Base
import { Test } from "forge-std/Test.sol";

// Mocks
import { MockTheCompact } from "test/utils/mocks/MockTheCompact.sol";

abstract contract RSAllocator_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    RSAllocator public allocator;
    MockTheCompact public mockCompact;

    address public owner;
    address public signer;
    address public wrongSigner;
    uint256 public signerPrivateKey;
    uint256 public wrongSignerPrivateKey;

    bytes32 public constant TEST_CLAIM_HASH = keccak256("test_claim");
    bytes32 public constant TEST_QUALIFICATION_HASH = keccak256("test_qualification");

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create test accounts
        owner = makeAddr("owner");
        (signer, signerPrivateKey) = makeAddrAndKey("signer");
        (wrongSigner, wrongSignerPrivateKey) = makeAddrAndKey("wrongSigner");

        // Deploy mock compact
        mockCompact = new MockTheCompact();

        // Deploy allocator
        allocator = new RSAllocator(address(mockCompact), owner, signer);
    }
}
