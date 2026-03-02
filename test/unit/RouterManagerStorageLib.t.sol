// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { RouterManagerStorageLib, AdapterConfig } from "src/router/lib/RouterStorageLib.sol";

/// @notice Wrapper to expose the internal library functions for direct testing
contract StorageLibHarness {
    using RouterManagerStorageLib for bytes4;
    using RouterManagerStorageLib for AdapterConfig;

    function storeFill(bytes2 version, bytes4 selector, address adapter, bytes12 tag) external {
        AdapterConfig storage $ = selector.withFillAdapter(version);
        $.store(adapter, tag);
    }

    function storeClaim(bytes2 version, bytes4 selector, address adapter, bytes12 tag) external {
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        $.store(adapter, tag);
    }

    function getFillAdapter(bytes2 version, bytes4 selector) external view returns (address) {
        AdapterConfig storage $ = selector.withFillAdapter(version);
        return $.adapterAddress();
    }

    function getClaimAdapter(bytes2 version, bytes4 selector) external view returns (address) {
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        return $.adapterAddress();
    }

    function getFillAdapterAndTag(bytes2 version, bytes4 selector) external view returns (address, bytes12) {
        AdapterConfig storage $ = selector.withFillAdapter(version);
        return $.adapterAddressAndTag();
    }

    function getClaimAdapterAndTag(bytes2 version, bytes4 selector) external view returns (address, bytes12) {
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        return $.adapterAddressAndTag();
    }

    function rawFillSlot(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 tag) {
        AdapterConfig storage $ = selector.withFillAdapter(version);
        adapter = $.adapter;
        tag = $.adapterTag;
    }

    function rawClaimSlot(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 tag) {
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        adapter = $.adapter;
        tag = $.adapterTag;
    }
}

contract RouterManagerStorageLibTest is Test {
    StorageLibHarness harness;

    bytes2 constant V1 = bytes2(0x0001);
    bytes2 constant V2 = bytes2(0x0002);
    bytes4 constant SEL_A = bytes4(0x12345678);
    bytes4 constant SEL_B = bytes4(0xdeadbeef);

    address constant ADAPTER_1 = address(0x1111);
    address constant ADAPTER_2 = address(0x2222);
    bytes12 constant TAG_1 = bytes12(uint96(1));
    bytes12 constant TAG_2 = bytes12(uint96(2));

    function setUp() public {
        harness = new StorageLibHarness();
    }

    // ============ store + adapterAddress ============

    function test_store_and_retrieve_fillAdapter() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);

        address adapter = harness.getFillAdapter(V1, SEL_A);
        assertEq(adapter, ADAPTER_1);
    }

    function test_store_and_retrieve_claimAdapter() public {
        harness.storeClaim(V1, SEL_A, ADAPTER_1, TAG_1);

        address adapter = harness.getClaimAdapter(V1, SEL_A);
        assertEq(adapter, ADAPTER_1);
    }

    function test_store_and_retrieve_adapterAndTag() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);

        (address adapter, bytes12 tag) = harness.getFillAdapterAndTag(V1, SEL_A);
        assertEq(adapter, ADAPTER_1);
        assertEq(tag, TAG_1);
    }

    function test_store_overwrites_previous() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);
        harness.storeFill(V1, SEL_A, ADAPTER_2, TAG_2);

        (address adapter, bytes12 tag) = harness.getFillAdapterAndTag(V1, SEL_A);
        assertEq(adapter, ADAPTER_2);
        assertEq(tag, TAG_2);
    }

    // ============ adapterAddress reverts when not found ============

    function test_adapterAddress_RevertsWhen_NotStored() public {
        vm.expectRevert(RouterManagerStorageLib.AdapterNotFound.selector);
        harness.getFillAdapter(V1, SEL_A);
    }

    function test_adapterAddressAndTag_RevertsWhen_NotStored() public {
        vm.expectRevert(RouterManagerStorageLib.AdapterNotFound.selector);
        harness.getFillAdapterAndTag(V1, SEL_A);
    }

    // ============ Slot isolation: fill vs claim ============

    function test_fill_and_claim_slots_are_isolated() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);
        harness.storeClaim(V1, SEL_A, ADAPTER_2, TAG_2);

        (address fillAdapter, bytes12 fillTag) = harness.getFillAdapterAndTag(V1, SEL_A);
        (address claimAdapter, bytes12 claimTag) = harness.getClaimAdapterAndTag(V1, SEL_A);

        assertEq(fillAdapter, ADAPTER_1);
        assertEq(fillTag, TAG_1);
        assertEq(claimAdapter, ADAPTER_2);
        assertEq(claimTag, TAG_2);
    }

    // ============ Slot isolation: different versions ============

    function test_different_versions_are_isolated() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);
        harness.storeFill(V2, SEL_A, ADAPTER_2, TAG_2);

        assertEq(harness.getFillAdapter(V1, SEL_A), ADAPTER_1);
        assertEq(harness.getFillAdapter(V2, SEL_A), ADAPTER_2);
    }

    // ============ Slot isolation: different selectors ============

    function test_different_selectors_are_isolated() public {
        harness.storeFill(V1, SEL_A, ADAPTER_1, TAG_1);
        harness.storeFill(V1, SEL_B, ADAPTER_2, TAG_2);

        assertEq(harness.getFillAdapter(V1, SEL_A), ADAPTER_1);
        assertEq(harness.getFillAdapter(V1, SEL_B), ADAPTER_2);
    }

    // ============ Empty slot reads ============

    function test_empty_slot_returns_zero() public view {
        (address adapter, bytes12 tag) = harness.rawFillSlot(V1, SEL_A);
        assertEq(adapter, address(0));
        assertEq(tag, bytes12(0));
    }

    // ============ Fuzz tests ============

    function testFuzz_slot_uniqueness(bytes2 versionA, bytes2 versionB, bytes4 selectorA, bytes4 selectorB) public {
        vm.assume(versionA != versionB || selectorA != selectorB);

        harness.storeFill(versionA, selectorA, ADAPTER_1, TAG_1);
        harness.storeFill(versionB, selectorB, ADAPTER_2, TAG_2);

        // If same slot, ADAPTER_2 would overwrite ADAPTER_1
        if (versionA == versionB && selectorA == selectorB) return;

        assertEq(harness.getFillAdapter(versionA, selectorA), ADAPTER_1);
        assertEq(harness.getFillAdapter(versionB, selectorB), ADAPTER_2);
    }

    function testFuzz_store_and_retrieve(bytes2 version, bytes4 selector, address adapter, bytes12 tag) public {
        vm.assume(adapter != address(0));

        harness.storeFill(version, selector, adapter, tag);

        (address gotAdapter, bytes12 gotTag) = harness.getFillAdapterAndTag(version, selector);
        assertEq(gotAdapter, adapter);
        assertEq(gotTag, tag);
    }
}
