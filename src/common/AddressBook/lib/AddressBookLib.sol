// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title AddressBookLib
 * @notice Library containing core functionality for the AddressBook contract
 * @dev Provides types, constants, and helper functions for managing stored values
 */
library AddressBookLib {
    /* //////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @dev Custom type for storage identifiers
    type ID is bytes32;

    /* //////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Predefined IDs for common contract references
    ID public constant COMPACTLOCKER = ID.wrap(keccak256(abi.encodePacked("CompactLocker")));
    ID public constant ORIGINMODULE_ACTUAL = ID.wrap(keccak256(abi.encodePacked("OriginModuleCompactActual")));
    ID public constant ORIGINMODULE_LOCKER = ID.wrap(keccak256(abi.encodePacked("OriginModuleCompactLocker")));
    ID public constant PREVALIDATION_HOOK = ID.wrap(keccak256(abi.encodePacked("PreValidationHook")));
    ID public constant SAMECHAINMODULE_ACTUAL = ID.wrap(keccak256(abi.encodePacked("SameChainModuleCompactActual")));
    ID public constant SAMECHAINMODULE_LOCKER = ID.wrap(keccak256(abi.encodePacked("SameChainModuleCompactLocker")));
    ID public constant RHINESTONE_SPOKEPOOL = ID.wrap(keccak256(abi.encodePacked("RhinestoneSpokePool")));

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Thrown when attempting to access an uninitialized value
    error NotInitialized(ID id);

    /* //////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage struct for address values
    struct Address {
        address value;
        bool initialized;
    }

    /// @dev Storage struct for uint256 values
    struct Uint256 {
        uint256 value;
        bool initialized;
    }

    /// @dev Storage struct for bytes32 values
    struct Bytes32 {
        bytes32 value;
        bool initialized;
    }

    /// @dev Storage struct for bytes values
    struct Bytes {
        bytes value;
        bool initialized;
    }

    /* //////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets an address value and marks it as initialized
     * @param self The storage struct to update
     * @param value The new address value
     */
    function set(Address storage self, address value) internal {
        self.value = value;
        self.initialized = true;
    }

    /**
     * @notice Sets a uint256 value and marks it as initialized
     * @param self The storage struct to update
     * @param value The new uint256 value
     */
    function set(Uint256 storage self, uint256 value) internal {
        self.value = value;
        self.initialized = true;
    }

    /**
     * @notice Sets a bytes32 value and marks it as initialized
     * @param self The storage struct to update
     * @param value The new bytes32 value
     */
    function set(Bytes32 storage self, bytes32 value) internal {
        self.value = value;
        self.initialized = true;
    }

    /**
     * @notice Sets a bytes value and marks it as initialized
     * @param self The storage struct to update
     * @param value The new bytes value
     */
    function set(Bytes storage self, bytes calldata value) internal {
        self.value = value;
        self.initialized = true;
    }

    /* //////////////////////////////////////////////////////////////
                                  GET
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves an address value, reverting if not initialized
     * @param self The storage struct to read from
     * @param id The identifier of the value
     * @return The stored address value
     */
    function get(Address storage self, ID id) internal view returns (address) {
        require(self.initialized, NotInitialized(id));
        return self.value;
    }

    /**
     * @notice Retrieves an address value, reverting if not initialized
     * @param self The storage struct to read from
     * @return The stored address value
     */
    function unsafeGet(Address storage self) internal view returns (address) {
        return self.value;
    }

    /**
     * @notice Retrieves a uint256 value, reverting if not initialized
     * @param self The storage struct to read from
     * @param id The identifier of the value
     * @return The stored uint256 value
     */
    function get(Uint256 storage self, ID id) internal view returns (uint256) {
        require(self.initialized, NotInitialized(id));
        return self.value;
    }

    /**
     * @notice Retrieves a bytes32 value, reverting if not initialized
     * @param self The storage struct to read from
     * @param id The identifier of the value
     * @return The stored bytes32 value
     */
    function get(Bytes32 storage self, ID id) internal view returns (bytes32) {
        require(self.initialized, NotInitialized(id));
        return self.value;
    }

    /**
     * @notice Retrieves a bytes value, reverting if not initialized
     * @param self The storage struct to read from
     * @param id The identifier of the value
     * @return The stored bytes value
     */
    function get(Bytes storage self, ID id) internal view returns (bytes memory) {
        require(self.initialized, NotInitialized(id));
        return self.value;
    }
}
