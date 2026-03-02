// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Bytes32ArrayLib } from "@rhinestone/compact-utils/src/common/Bytes32ArrayLib.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";

// Test helper contract to access internal functions
contract Bytes32ArrayLibHelper {
    function insertAt(bytes32[] calldata array, uint256 index, bytes32 element) external pure returns (bytes32[] memory) {
        return Bytes32ArrayLib.insertAt(array, index, element);
    }

    function insertAtAndHash(bytes32[] calldata array, uint256 index, bytes32 element) external pure returns (bytes32) {
        return Bytes32ArrayLib.insertAtAndHash(array, index, element);
    }
}

contract Bytes32ArrayLibTest is Test {
    using EfficientHashLib for bytes32[];

    Bytes32ArrayLibHelper helper;

    function setUp() public {
        helper = new Bytes32ArrayLibHelper();
    }

    function test_insertAt_EmptyArray() public {
        bytes32[] memory emptyArray = new bytes32[](0);
        bytes32 element = keccak256("test");

        bytes32[] memory result = helper.insertAt(emptyArray, 0, element);

        assertEq(result.length, 1);
        assertEq(result[0], element);
    }

    function test_insertAt_BeginningOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32[] memory result = helper.insertAt(array, 0, element);

        assertEq(result.length, 4);
        assertEq(result[0], element);
        assertEq(result[1], keccak256("a"));
        assertEq(result[2], keccak256("b"));
        assertEq(result[3], keccak256("c"));
    }

    function test_insertAt_MiddleOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32[] memory result = helper.insertAt(array, 2, element);

        assertEq(result.length, 4);
        assertEq(result[0], keccak256("a"));
        assertEq(result[1], keccak256("b"));
        assertEq(result[2], element);
        assertEq(result[3], keccak256("c"));
    }

    function test_insertAt_EndOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32[] memory result = helper.insertAt(array, 3, element);

        assertEq(result.length, 4);
        assertEq(result[0], keccak256("a"));
        assertEq(result[1], keccak256("b"));
        assertEq(result[2], keccak256("c"));
        assertEq(result[3], element);
    }

    function test_insertAt_IndexOutOfBounds() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        vm.expectRevert(Bytes32ArrayLib.Bytes32ArrayLib_IndexOutOutOfBounds.selector);
        helper.insertAt(array, 5, element);
    }

    function test_insertAtAndHash_EmptyArray() public {
        bytes32[] memory emptyArray = new bytes32[](0);
        bytes32 element = keccak256("test");

        bytes32 result = helper.insertAtAndHash(emptyArray, 0, element);

        // Create expected array and hash it
        bytes32[] memory expected = new bytes32[](1);
        expected[0] = element;
        bytes32 expectedHash = expected.hash();

        assertEq(result, expectedHash);
    }

    function test_insertAtAndHash_BeginningOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32 result = helper.insertAtAndHash(array, 0, element);

        // Create expected array and hash it
        bytes32[] memory expected = new bytes32[](4);
        expected[0] = element;
        expected[1] = keccak256("a");
        expected[2] = keccak256("b");
        expected[3] = keccak256("c");
        bytes32 expectedHash = expected.hash();

        assertEq(result, expectedHash);
    }

    function test_insertAtAndHash_MiddleOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32 result = helper.insertAtAndHash(array, 1, element);

        // Create expected array and hash it
        bytes32[] memory expected = new bytes32[](4);
        expected[0] = keccak256("a");
        expected[1] = element;
        expected[2] = keccak256("b");
        expected[3] = keccak256("c");
        bytes32 expectedHash = expected.hash();

        assertEq(result, expectedHash);
    }

    function test_insertAtAndHash_EndOfArray() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        bytes32 result = helper.insertAtAndHash(array, 3, element);

        // Create expected array and hash it
        bytes32[] memory expected = new bytes32[](4);
        expected[0] = keccak256("a");
        expected[1] = keccak256("b");
        expected[2] = keccak256("c");
        expected[3] = element;
        bytes32 expectedHash = expected.hash();

        assertEq(result, expectedHash);
    }

    function test_insertAtAndHash_IndexOutOfBounds() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");

        vm.expectRevert(Bytes32ArrayLib.Bytes32ArrayLib_IndexOutOutOfBounds.selector);
        helper.insertAtAndHash(array, 5, element);
    }

    function test_insertAtAndHash_ConsistentWithInsertAt() public {
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("a");
        array[1] = keccak256("b");
        array[2] = keccak256("c");

        bytes32 element = keccak256("inserted");
        uint256 index = 1;

        bytes32[] memory insertedArray = helper.insertAt(array, index, element);
        bytes32 hashResult = helper.insertAtAndHash(array, index, element);

        assertEq(hashResult, insertedArray.hash());
    }

    function testFuzz_insertAt_ValidIndices(bytes32[] calldata array, uint256 index, bytes32 element) public {
        vm.assume(array.length < 100); // Reasonable bounds for testing
        index = bound(index, 0, array.length);

        bytes32[] memory result = helper.insertAt(array, index, element);

        assertEq(result.length, array.length + 1);
        assertEq(result[index], element);

        // Verify elements before insertion point
        for (uint256 i = 0; i < index; i++) {
            assertEq(result[i], array[i]);
        }

        // Verify elements after insertion point
        for (uint256 i = index + 1; i < result.length; i++) {
            assertEq(result[i], array[i - 1]);
        }
    }

    function testFuzz_insertAtAndHash_ValidIndices(bytes32[] calldata array, uint256 index, bytes32 element) public {
        vm.assume(array.length < 100); // Reasonable bounds for testing
        index = bound(index, 0, array.length);

        bytes32 hashResult = helper.insertAtAndHash(array, index, element);
        bytes32[] memory insertedArray = helper.insertAt(array, index, element);

        assertEq(hashResult, insertedArray.hash());
    }

    function testFuzz_insertAt_InvalidIndices(bytes32[] calldata array, uint256 index, bytes32 element) public {
        vm.assume(array.length < 100); // Reasonable bounds for testing
        vm.assume(index > array.length);

        vm.expectRevert(Bytes32ArrayLib.Bytes32ArrayLib_IndexOutOutOfBounds.selector);
        helper.insertAt(array, index, element);
    }

    function testFuzz_insertAtAndHash_InvalidIndices(bytes32[] calldata array, uint256 index, bytes32 element) public {
        vm.assume(array.length < 100); // Reasonable bounds for testing
        vm.assume(index > array.length);

        vm.expectRevert(Bytes32ArrayLib.Bytes32ArrayLib_IndexOutOutOfBounds.selector);
        helper.insertAtAndHash(array, index, element);
    }

    function test_insertAt_SingleElementArray() public {
        bytes32[] memory array = new bytes32[](1);
        array[0] = keccak256("existing");

        bytes32 element = keccak256("new");

        // Insert at beginning
        bytes32[] memory result1 = helper.insertAt(array, 0, element);
        assertEq(result1.length, 2);
        assertEq(result1[0], element);
        assertEq(result1[1], keccak256("existing"));

        // Insert at end
        bytes32[] memory result2 = helper.insertAt(array, 1, element);
        assertEq(result2.length, 2);
        assertEq(result2[0], keccak256("existing"));
        assertEq(result2[1], element);
    }

    function test_insertAtAndHash_SingleElementArray() public {
        bytes32[] memory array = new bytes32[](1);
        array[0] = keccak256("existing");

        bytes32 element = keccak256("new");

        // Insert at beginning
        bytes32 result1 = helper.insertAtAndHash(array, 0, element);
        bytes32[] memory expected1 = new bytes32[](2);
        expected1[0] = element;
        expected1[1] = keccak256("existing");
        assertEq(result1, expected1.hash());

        // Insert at end
        bytes32 result2 = helper.insertAtAndHash(array, 1, element);
        bytes32[] memory expected2 = new bytes32[](2);
        expected2[0] = keccak256("existing");
        expected2[1] = element;
        assertEq(result2, expected2.hash());
    }

    // Additional tests to explicitly verify insertion logic
    function test_insertAt_LogicVerification() public {
        // Test with a clearly ordered array to verify exact positioning
        bytes32[] memory array = new bytes32[](4);
        array[0] = bytes32(uint256(1)); // "1"
        array[1] = bytes32(uint256(2)); // "2"
        array[2] = bytes32(uint256(3)); // "3"
        array[3] = bytes32(uint256(4)); // "4"

        bytes32 newElement = bytes32(uint256(99)); // "99"

        // Insert at index 0 (beginning): should be [99, 1, 2, 3, 4]
        bytes32[] memory result0 = helper.insertAt(array, 0, newElement);
        assertEq(result0.length, 5);
        assertEq(result0[0], bytes32(uint256(99)));
        assertEq(result0[1], bytes32(uint256(1)));
        assertEq(result0[2], bytes32(uint256(2)));
        assertEq(result0[3], bytes32(uint256(3)));
        assertEq(result0[4], bytes32(uint256(4)));

        // Insert at index 2 (middle): should be [1, 2, 99, 3, 4]
        bytes32[] memory result2 = helper.insertAt(array, 2, newElement);
        assertEq(result2.length, 5);
        assertEq(result2[0], bytes32(uint256(1)));
        assertEq(result2[1], bytes32(uint256(2)));
        assertEq(result2[2], bytes32(uint256(99)));
        assertEq(result2[3], bytes32(uint256(3)));
        assertEq(result2[4], bytes32(uint256(4)));

        // Insert at index 4 (end): should be [1, 2, 3, 4, 99]
        bytes32[] memory result4 = helper.insertAt(array, 4, newElement);
        assertEq(result4.length, 5);
        assertEq(result4[0], bytes32(uint256(1)));
        assertEq(result4[1], bytes32(uint256(2)));
        assertEq(result4[2], bytes32(uint256(3)));
        assertEq(result4[3], bytes32(uint256(4)));
        assertEq(result4[4], bytes32(uint256(99)));
    }

    function test_insertAt_SequentialInsertions() public {
        // Start with empty array and build up through insertions
        bytes32[] memory array = new bytes32[](0);

        // Insert first element at index 0
        bytes32[] memory result1 = helper.insertAt(array, 0, bytes32(uint256(1)));
        assertEq(result1.length, 1);
        assertEq(result1[0], bytes32(uint256(1)));

        // Insert second element at index 0 (should shift first element)
        bytes32[] memory result2 = helper.insertAt(result1, 0, bytes32(uint256(2)));
        assertEq(result2.length, 2);
        assertEq(result2[0], bytes32(uint256(2))); // New element
        assertEq(result2[1], bytes32(uint256(1))); // Shifted element

        // Insert third element at index 1 (between the two)
        bytes32[] memory result3 = helper.insertAt(result2, 1, bytes32(uint256(3)));
        assertEq(result3.length, 3);
        assertEq(result3[0], bytes32(uint256(2))); // Unchanged
        assertEq(result3[1], bytes32(uint256(3))); // New element
        assertEq(result3[2], bytes32(uint256(1))); // Shifted element
    }

    function test_insertAtAndHash_LogicVerification() public {
        // Test with a clearly ordered array to verify exact positioning
        bytes32[] memory array = new bytes32[](3);
        array[0] = bytes32(uint256(10));
        array[1] = bytes32(uint256(20));
        array[2] = bytes32(uint256(30));

        bytes32 newElement = bytes32(uint256(15));

        // Insert at index 1: should be [10, 15, 20, 30]
        bytes32 result = helper.insertAtAndHash(array, 1, newElement);

        // Create expected array manually and hash it
        bytes32[] memory expected = new bytes32[](4);
        expected[0] = bytes32(uint256(10));
        expected[1] = bytes32(uint256(15)); // New element
        expected[2] = bytes32(uint256(20)); // Shifted
        expected[3] = bytes32(uint256(30)); // Shifted

        assertEq(result, expected.hash());

        // Also verify consistency with insertAt
        bytes32[] memory insertAtResult = helper.insertAt(array, 1, newElement);
        assertEq(result, insertAtResult.hash());
    }

    function test_insertAt_AllValidIndices() public {
        // Test insertion at every valid index position
        bytes32[] memory array = new bytes32[](3);
        array[0] = keccak256("first");
        array[1] = keccak256("second");
        array[2] = keccak256("third");

        bytes32 element = keccak256("inserted");

        // Test each valid index (0 through array.length)
        for (uint256 i = 0; i <= array.length; i++) {
            bytes32[] memory result = helper.insertAt(array, i, element);
            assertEq(result.length, array.length + 1);
            assertEq(result[i], element, "Element not inserted at correct index");

            // Verify elements before insertion point are unchanged
            for (uint256 j = 0; j < i; j++) {
                assertEq(result[j], array[j], "Element before insertion point changed");
            }

            // Verify elements after insertion point are shifted correctly
            for (uint256 j = i + 1; j < result.length; j++) {
                assertEq(result[j], array[j - 1], "Element after insertion point not shifted correctly");
            }
        }
    }
}
