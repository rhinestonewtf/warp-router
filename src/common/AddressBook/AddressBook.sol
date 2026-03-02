// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// Interfaces
import { IAddressBook } from "./IAddressBook.sol";

// Libraries
import { AddressBookLib } from "./lib/AddressBookLib.sol";

/// @title AddressBook
/// @notice An on-chain registry for storing and retrieving different types of values by ID
contract AddressBook is IAddressBook {
    /* //////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using AddressBookLib for AddressBookLib.ID;

    /* //////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from ID to Address storage struct
    mapping(AddressBookLib.ID id => AddressBookLib.Address value) private $addresses;

    /// @dev Mapping from ID to Uint256 storage struct
    mapping(AddressBookLib.ID id => AddressBookLib.Uint256 value) private $uints;

    /// @dev Mapping from ID to Bytes32 storage struct
    mapping(AddressBookLib.ID id => AddressBookLib.Bytes32 value) private $byte32s;

    /// @dev Mapping from ID to Bytes storage struct
    mapping(AddressBookLib.ID id => AddressBookLib.Bytes value) private $bytess;

    bool public initialized;

    address public immutable OWNER;

    error AlreadyInitialized();

    error NotOwner(address sender, address owner);

    modifier onlyOwner() {
        require(msg.sender == OWNER, NotOwner(msg.sender, OWNER));
        _;
    }

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param owner The address that will own this contract
    /// @dev Sets up initial ownership of the contract
    constructor(address owner) {
        OWNER = owner;
    }

    function initialize() external {
        require(!initialized, AlreadyInitialized());
        initialized = true;
    }

    /* //////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAddressBook
    function setAddress(AddressBookLib.ID id, address value) public onlyOwner {
        AddressBookLib.set($addresses[id], value);
        emit AddressSet(id, value);
    }

    /// @inheritdoc IAddressBook
    function setAddresses(SetAddress[] calldata values) external onlyOwner {
        for (uint256 i = 0; i < values.length; i++) {
            setAddress(values[i].id, values[i].value);
        }
    }

    /// @inheritdoc IAddressBook
    function setUint(AddressBookLib.ID id, uint256 value) public onlyOwner {
        AddressBookLib.set($uints[id], value);
        emit UintSet(id, value);
    }

    /// @inheritdoc IAddressBook
    function setUints(SetUint[] calldata values) external onlyOwner {
        for (uint256 i = 0; i < values.length; i++) {
            setUint(values[i].id, values[i].value);
        }
    }

    /// @inheritdoc IAddressBook
    function setBytes32(AddressBookLib.ID id, bytes32 value) public onlyOwner {
        AddressBookLib.set($byte32s[id], value);
        emit Bytes32Set(id, value);
    }

    /// @inheritdoc IAddressBook
    function setBytes32s(SetBytes32[] calldata values) external onlyOwner {
        for (uint256 i = 0; i < values.length; i++) {
            setBytes32(values[i].id, values[i].value);
        }
    }

    /// @inheritdoc IAddressBook
    function setBytes(AddressBookLib.ID id, bytes calldata value) public onlyOwner {
        AddressBookLib.set($bytess[id], value);
        emit BytesSet(id, value);
    }

    /// @inheritdoc IAddressBook
    function setBytess(SetBytess[] calldata values) external onlyOwner {
        for (uint256 i = 0; i < values.length; i++) {
            setBytes(values[i].id, values[i].value);
        }
    }

    /* //////////////////////////////////////////////////////////////
                                  GET
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAddressBook
    function getAddress(AddressBookLib.ID id) external view override returns (address value) {
        return AddressBookLib.get($addresses[id], id);
    }

    function unsafeGetAddress(AddressBookLib.ID id) external view returns (address value) {
        return AddressBookLib.unsafeGet($addresses[id]);
    }

    /// @inheritdoc IAddressBook
    function getUint(AddressBookLib.ID id) external view override returns (uint256 value) {
        return AddressBookLib.get($uints[id], id);
    }

    /// @inheritdoc IAddressBook
    function getBytes32(AddressBookLib.ID id) external view override returns (bytes32 value) {
        return AddressBookLib.get($byte32s[id], id);
    }

    /// @inheritdoc IAddressBook
    function getBytes(AddressBookLib.ID id) external view override returns (bytes memory value) {
        return AddressBookLib.get($bytess[id], id);
    }
}
