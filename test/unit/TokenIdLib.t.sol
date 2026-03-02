// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { TokenIdLib } from "@rhinestone/compact-utils/src/common/TokenIdLib.sol";

contract TokenIdLibTest is Test {
    // Original implementation using abi.encode
    function toClaimantOriginal(address claimant) internal pure returns (uint256 id) {
        return abi.decode(abi.encodePacked(bytes12(bytes32(0)), claimant), (uint256));
    }

    // Assembly-optimized implementation
    function toClaimantAssembly(address claimant) internal pure returns (uint256 id) {
        assembly {
            id := claimant
        }
    }

    function test_toClaimant_ImplementationsAreEquivalent() public {
        // Test with various addresses to ensure both implementations produce identical results
        address[] memory testAddresses = new address[](10);
        testAddresses[0] = address(0x0);
        testAddresses[1] = address(0x1);
        testAddresses[2] = address(0xdEaD);
        testAddresses[3] = address(0x1234567890123456789012345678901234567890);
        testAddresses[4] = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        testAddresses[5] = makeAddr("alice");
        testAddresses[6] = makeAddr("bob");
        testAddresses[7] = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
        testAddresses[8] = 0x000000000000000000000000000000000000dEaD;
        testAddresses[9] = 0x1111111111111111111111111111111111111111;

        for (uint256 i = 0; i < testAddresses.length; i++) {
            address testAddr = testAddresses[i];

            uint256 originalResult = toClaimantOriginal(testAddr);
            uint256 assemblyResult = toClaimantAssembly(testAddr);
            uint256 libraryResult = TokenIdLib.toClaimant(testAddr);

            // Verify all three implementations produce the same result
            assertEq(originalResult, assemblyResult, "Original and assembly implementations should match");
            assertEq(originalResult, libraryResult, "Original and library implementations should match");
            assertEq(assemblyResult, libraryResult, "Assembly and library implementations should match");

            // Verify the result is the address cast to uint256
            assertEq(originalResult, uint256(uint160(testAddr)), "Result should equal address cast to uint256");
        }
    }

    function test_toClaimant_FuzzEquivalent(address claimant) public {
        uint256 originalResult = toClaimantOriginal(claimant);
        uint256 assemblyResult = toClaimantAssembly(claimant);
        uint256 libraryResult = TokenIdLib.toClaimant(claimant);

        // All implementations should produce identical results
        assertEq(originalResult, assemblyResult, "Original and assembly implementations should match");
        assertEq(originalResult, libraryResult, "Original and library implementations should match");
        assertEq(assemblyResult, libraryResult, "Assembly and library implementations should match");

        // The result should equal the address cast to uint256
        assertEq(originalResult, uint256(uint160(claimant)), "Result should equal address cast to uint256");
    }

    function test_toClaimant_VerifyBehavior() public {
        address testAddr = 0x1234567890123456789012345678901234567890;
        uint256 result = TokenIdLib.toClaimant(testAddr);

        // The result should be the address with upper 96 bits zeroed
        uint256 expectedResult = uint256(uint160(testAddr));
        assertEq(result, expectedResult);

        // Verify upper 96 bits are zero
        assertEq(result >> 160, 0, "Upper 96 bits should be zero");

        // Verify lower 160 bits contain the address
        assertEq(address(uint160(result)), testAddr, "Lower 160 bits should contain the original address");
    }

    function test_toClaimant_GasComparison() public {
        address testAddr = 0x1234567890123456789012345678901234567890;

        uint256 gasStart;
        uint256 gasEnd;
        uint256 gasUsedOriginal;
        uint256 gasUsedAssembly;

        // Test original implementation
        gasStart = gasleft();
        toClaimantOriginal(testAddr);
        gasEnd = gasleft();
        gasUsedOriginal = gasStart - gasEnd;

        // Test assembly implementation
        gasStart = gasleft();
        toClaimantAssembly(testAddr);
        gasEnd = gasleft();
        gasUsedAssembly = gasStart - gasEnd;

        // Assembly should be more gas efficient
        assertLt(gasUsedAssembly, gasUsedOriginal, "Assembly implementation should use less gas");

        emit log_named_uint("Original implementation gas", gasUsedOriginal);
        emit log_named_uint("Assembly implementation gas", gasUsedAssembly);
        emit log_named_uint("Gas saved", gasUsedOriginal - gasUsedAssembly);
    }
}
