// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Simple mock for Permit2 that just returns a domain separator
contract MockPermit2 {
    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return bytes32(0x1234567890123456789012345678901234567890123456789012345678901234);
    }
}
