// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title RouterUtils
 * @notice Utility library providing helper functions for router operations
 * @dev Contains pure utility functions that can be used across the router system
 *      to perform common checks and validations
 */
contract RouterUtils {
    /**
     * @notice Checks whether a contract is deployed at the specified address
     * @dev Uses the EXTCODESIZE opcode via `.code.length` to determine if bytecode
     *      exists at the given address. Returns true for contracts, false for EOAs
     *      or undeployed addresses.
     *
     *      Note: This check will return false for addresses in the middle of construction,
     *      as constructor code is not yet stored at the address during deployment.
     *
     * @param addr The address to check for contract deployment
     * @return True if a contract is deployed at the address, false otherwise
     */
    function isContractDeployed(address addr) external view returns (bool) {
        // Check if bytecode exists at the address using EXTCODESIZE
        // An address with code.length > 0 indicates a deployed contract
        return addr.code.length > 0;
    }

    /**
     * @notice Returns the contract code for a given address
     * @dev Retrieves the bytecode stored at the specified address.
     *     Returns an empty bytes if no contract is deployed there.
     * @param addr The address to retrieve contract code from
     * @return The bytecode of the contract at the address, or empty if none
     */
    function getContractCode(address addr) external view returns (bytes memory) {
        return addr.code;
    }
}
