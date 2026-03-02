// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Test
import { Test } from "forge-std/Test.sol";

// Contracts
import { AddressBook, IAddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/AddressBook.sol";

// Libraries
import { AddressBookLib } from "@rhinestone/compact-utils/src/common/AddressBook/lib/AddressBookLib.sol";

contract AddressBook_Test is Test {
    /* //////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using AddressBookLib for AddressBookLib.ID;

    /* //////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    AddressBook book;
    address owner;
    address user;

    /* //////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        owner = makeAddr("owner");
        user = makeAddr("user");

        vm.prank(owner);
        book = new AddressBook(owner);
    }

    /* //////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotInitialized(AddressBookLib.ID id);

    /* //////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    function test_setAddress_WhenOwner() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");
        address value = makeAddr("value");

        // Act
        vm.prank(owner);
        book.setAddress(id, value);

        // Assert
        assertEq(book.getAddress(id), value);
    }

    function test_setUint_WhenOwner() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");
        uint256 value = 123;

        // Act
        vm.prank(owner);
        book.setUint(id, value);

        // Assert
        assertEq(book.getUint(id), value);
    }

    function test_setBytes32_WhenOwner() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");
        bytes32 value = bytes32(uint256(123));

        // Act
        vm.prank(owner);
        book.setBytes32(id, value);

        // Assert
        assertEq(book.getBytes32(id), value);
    }

    function test_setBytes_WhenOwner() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");
        bytes memory value = "test value";

        // Act
        vm.prank(owner);
        book.setBytes(id, value);

        // Assert
        assertEq(book.getBytes(id), value);
    }

    /* //////////////////////////////////////////////////////////////
                                 BATCH
    //////////////////////////////////////////////////////////////*/

    function test_setAddresses_WhenOwner() public {
        // Arrange
        IAddressBook.SetAddress[] memory values = new IAddressBook.SetAddress[](2);
        values[0] = IAddressBook.SetAddress({ id: _createID("test1"), value: makeAddr("value1") });
        values[1] = IAddressBook.SetAddress({ id: _createID("test2"), value: makeAddr("value2") });

        // Act
        vm.prank(owner);
        book.setAddresses(values);

        // Assert
        assertEq(book.getAddress(values[0].id), values[0].value);
        assertEq(book.getAddress(values[1].id), values[1].value);
    }

    function test_setUints_WhenOwner() public {
        // Arrange
        IAddressBook.SetUint[] memory values = new IAddressBook.SetUint[](2);
        values[0] = IAddressBook.SetUint({ id: _createID("test1"), value: 123 });
        values[1] = IAddressBook.SetUint({ id: _createID("test2"), value: 456 });

        // Act
        vm.prank(owner);
        book.setUints(values);

        // Assert
        assertEq(book.getUint(values[0].id), values[0].value);
        assertEq(book.getUint(values[1].id), values[1].value);
    }

    function test_setBytes32s_WhenOwner() public {
        // Arrange
        IAddressBook.SetBytes32[] memory values = new IAddressBook.SetBytes32[](2);
        values[0] = IAddressBook.SetBytes32({ id: _createID("test1"), value: bytes32(uint256(123)) });
        values[1] = IAddressBook.SetBytes32({ id: _createID("test2"), value: bytes32(uint256(456)) });

        // Act
        vm.prank(owner);
        book.setBytes32s(values);

        // Assert
        assertEq(book.getBytes32(values[0].id), values[0].value);
        assertEq(book.getBytes32(values[1].id), values[1].value);
    }

    function test_setBytess_WhenOwner() public {
        // Arrange
        IAddressBook.SetBytess[] memory values = new IAddressBook.SetBytess[](2);
        values[0] = IAddressBook.SetBytess({ id: _createID("test1"), value: "test1" });
        values[1] = IAddressBook.SetBytess({ id: _createID("test2"), value: "test2" });

        // Act
        vm.prank(owner);
        book.setBytess(values);

        // Assert
        assertEq(book.getBytes(values[0].id), values[0].value);
        assertEq(book.getBytes(values[1].id), values[1].value);
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    function test_getAddress_RevertsWhen_NotInitialized() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");

        // Act/Assert
        vm.expectRevert(abi.encodeWithSelector(NotInitialized.selector, id));
        book.getAddress(id);
    }

    function test_setAddress_RevertsWhen_NotOwner() public {
        // Arrange
        AddressBookLib.ID id = _createID("test");
        address value = makeAddr("value");

        // Act/Assert
        vm.prank(user);
        vm.expectRevert();
        book.setAddress(id, value);
    }

    /* //////////////////////////////////////////////////////////////
                           CONSTANT VALUES
    //////////////////////////////////////////////////////////////*/

    function test_ConstantIDs() public pure {
        // Assert
        assertEq(
            AddressBookLib.ID.unwrap(AddressBookLib.COMPACTLOCKER),
            keccak256(abi.encodePacked("CompactLocker")),
            "CompactLocker ID mismatch"
        );
        assertEq(
            AddressBookLib.ID.unwrap(AddressBookLib.ORIGINMODULE_ACTUAL),
            keccak256(abi.encodePacked("OriginModuleCompactActual")),
            "OriginModuleCompactActual ID mismatch"
        );
        assertEq(
            AddressBookLib.ID.unwrap(AddressBookLib.ORIGINMODULE_LOCKER),
            keccak256(abi.encodePacked("OriginModuleCompactLocker")),
            "OriginModuleCompactLocker ID mismatch"
        );
        assertEq(
            AddressBookLib.ID.unwrap(AddressBookLib.PREVALIDATION_HOOK), keccak256("PreValidationHook"), "PreValidationHook ID mismatch"
        );
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createID(string memory name) internal pure returns (AddressBookLib.ID) {
        return AddressBookLib.ID.wrap(keccak256(bytes(name)));
    }
}
