// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Libraries
import { AddressBookLib } from "./lib/AddressBookLib.sol";

/**
 * @title IAddressBook
 * @notice Interface for the AddressBook contract
 * @dev Defines the external interface for setting and retrieving stored values
 */
interface IAddressBook {
    /* //////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when an address value is set
    event AddressSet(AddressBookLib.ID id, address value);
    /// @dev Emitted when a uint256 value is set
    event UintSet(AddressBookLib.ID id, uint256 value);
    /// @dev Emitted when a bytes32 value is set
    event Bytes32Set(AddressBookLib.ID id, bytes32 value);
    /// @dev Emitted when a bytes value is set
    event BytesSet(AddressBookLib.ID id, bytes value);

    /* //////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Struct for setting an address value
    struct SetAddress {
        AddressBookLib.ID id;
        address value;
    }

    /// @dev Struct for setting a uint256 value
    struct SetUint {
        AddressBookLib.ID id;
        uint256 value;
    }

    /// @dev Struct for setting a bytes32 value
    struct SetBytes32 {
        AddressBookLib.ID id;
        bytes32 value;
    }

    /// @dev Struct for setting a bytes value
    struct SetBytess {
        AddressBookLib.ID id;
        bytes value;
    }

    /* //////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a single address value
     * @param id The identifier for the address
     * @param value The address value to store
     */
    function setAddress(AddressBookLib.ID id, address value) external;

    /**
     * @notice Sets multiple address values
     * @param values Array of SetAddress structs containing id/value pairs
     */
    function setAddresses(SetAddress[] calldata values) external;

    /**
     * @notice Sets a single uint256 value
     * @param id The identifier for the uint256
     * @param value The uint256 value to store
     */
    function setUint(AddressBookLib.ID id, uint256 value) external;

    /**
     * @notice Sets multiple uint256 values
     * @param values Array of SetUint structs containing id/value pairs
     */
    function setUints(SetUint[] calldata values) external;

    /**
     * @notice Sets a single bytes32 value
     * @param id The identifier for the bytes32
     * @param value The bytes32 value to store
     */
    function setBytes32(AddressBookLib.ID id, bytes32 value) external;

    /**
     * @notice Sets multiple bytes32 values
     * @param values Array of SetBytes32 structs containing id/value pairs
     */
    function setBytes32s(SetBytes32[] calldata values) external;

    /**
     * @notice Sets a single bytes value
     * @param id The identifier for the bytes
     * @param value The bytes value to store
     */
    function setBytes(AddressBookLib.ID id, bytes calldata value) external;

    /**
     * @notice Sets multiple bytes values
     * @param values Array of SetBytess structs containing id/value pairs
     */
    function setBytess(SetBytess[] calldata values) external;

    /* //////////////////////////////////////////////////////////////
                                  GET
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves an address value by ID
     * @param id The identifier for the address
     * @return The stored address value
     * @dev Reverts if the ID has not been initialized
     */
    function getAddress(AddressBookLib.ID id) external view returns (address);

    function unsafeGetAddress(AddressBookLib.ID id) external view returns (address);

    /**
     * @notice Retrieves a uint256 value by ID
     * @param id The identifier for the uint256
     * @return The stored uint256 value
     * @dev Reverts if the ID has not been initialized
     */
    function getUint(AddressBookLib.ID id) external view returns (uint256);

    /**
     * @notice Retrieves a bytes32 value by ID
     * @param id The identifier for the bytes32
     * @return The stored bytes32 value
     * @dev Reverts if the ID has not been initialized
     */
    function getBytes32(AddressBookLib.ID id) external view returns (bytes32);

    /**
     * @notice Retrieves a bytes value by ID
     * @param id The identifier for the bytes
     * @return The stored bytes value
     * @dev Reverts if the ID has not been initialized
     */
    function getBytes(AddressBookLib.ID id) external view returns (bytes memory);
}
