// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { RouterManager } from "../../src/router/core/RouterManager.sol";
import { IRouterManager } from "../../src/interfaces/IRouterManager.sol";
import { AdapterBase, SemVer } from "../../src/base/adapter/AdapterBase.sol";
import { Version } from "../../src/Version.sol";
import { IArbiter } from "../../src/interfaces/IArbiter.sol";
import { IAdapter } from "../../src/interfaces/IAdapter.sol";

// Mock arbiter for testing
contract MockArbiter {
    function isArbiter() external pure returns (bytes4) {
        return this.isArbiter.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IArbiter).interfaceId;
    }
}

// Mock adapters with different semantic versions for testing
// Note: SemVer constructor takes (minor, patch) - major is always 1
contract MockAdapterV1_0_0 is AdapterBase {
    constructor(address router, address arbiter) AdapterBase(router, address(0)) SemVer(0, 0) { }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function mockClaim() external payable onlyViaRouter returns (bytes4) {
        return this.mockClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || super.supportsInterface(interfaceId)
            || interfaceId == type(IAdapter).interfaceId;
    }
}

contract MockAdapterV1_0_1 is AdapterBase {
    constructor(address router, address arbiter) AdapterBase(router, address(0)) SemVer(0, 1) { }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function mockClaim() external payable onlyViaRouter returns (bytes4) {
        return this.mockClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || super.supportsInterface(interfaceId)
            || interfaceId == type(IAdapter).interfaceId;
    }
}

contract MockAdapterV1_1_0 is AdapterBase {
    constructor(address router, address arbiter) AdapterBase(router, address(0)) SemVer(1, 0) { }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function mockClaim() external payable onlyViaRouter returns (bytes4) {
        return this.mockClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || super.supportsInterface(interfaceId)
            || interfaceId == type(IAdapter).interfaceId;
    }
}

// For V2, we create a simple contract that implements the semVer interface
// without inheriting from AdapterBase (which forces major version 1)
contract MockAdapterV2_0_0 {
    address immutable ROUTER;

    modifier onlyViaRouter() {
        require(msg.sender == ROUTER, "Only router");
        _;
    }

    constructor(address router) {
        ROUTER = router;
    }

    // Return version 2.0.0
    function semVer() external pure returns (bytes6) {
        // Pack version 2.0.0
        return bytes6(bytes.concat(bytes2(uint16(2)), bytes2(uint16(0)), bytes2(uint16(0))));
    }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function mockClaim() external payable onlyViaRouter returns (bytes4) {
        return this.mockClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == type(IAdapter).interfaceId;
    }

    function isAdapter() external pure returns (bytes4) {
        return this.isAdapter.selector;
    }

    function ARBITER() external pure returns (address) {
        return address(0x69);
    }
}

contract RouterManagerSemVerTest is Test {
    RouterManager public routerManager;
    MockArbiter public mockArbiter;

    MockAdapterV1_0_0 public adapterV1_0_0;
    MockAdapterV1_0_1 public adapterV1_0_1;
    MockAdapterV1_1_0 public adapterV1_1_0;
    MockAdapterV2_0_0 public adapterV2_0_0;

    address public admin = makeAddr("admin");
    address public rmAdmin = makeAddr("rmAdmin");

    bytes4 public constant FILL_SELECTOR = MockAdapterV1_0_0.mockFill.selector;
    bytes4 public constant CLAIM_SELECTOR = MockAdapterV1_0_0.mockClaim.selector;

    function setUp() public {
        // Deploy RouterManager
        routerManager = new RouterManager(admin, rmAdmin);

        // Deploy mock arbiter
        mockArbiter = new MockArbiter();

        // Deploy mock adapters with different versions
        adapterV1_0_0 = new MockAdapterV1_0_0(address(routerManager), address(mockArbiter));
        adapterV1_0_1 = new MockAdapterV1_0_1(address(routerManager), address(mockArbiter));
        adapterV1_1_0 = new MockAdapterV1_1_0(address(routerManager), address(mockArbiter));
        adapterV2_0_0 = new MockAdapterV2_0_0(address(routerManager));
    }

    // ============ installFillAdapter Tests ============

    function test_installFillAdapter_Success_MatchingMajorVersion() public {
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_0_0));
    }

    function test_installFillAdapter_Revert_MismatchedMajorVersion() public {
        // Try to install V2 adapter with V1 version parameter
        vm.expectRevert(IRouterManager.AdapterMajorVersionMismatch.selector);
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV2_0_0));
    }

    function test_installFillAdapter_Success_DifferentMinorPatch() public {
        // V1.1.0 adapter should work with V1 version parameter (same major)
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_1_0));

        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_1_0));
    }

    // ============ installClaimAdapter Tests ============

    function test_installClaimAdapter_Success_MatchingMajorVersion() public {
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        (address adapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_0_0));
    }

    function test_installClaimAdapter_Revert_MismatchedMajorVersion() public {
        // Try to install V2 adapter with V1 version parameter
        vm.expectRevert(IRouterManager.AdapterMajorVersionMismatch.selector);
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV2_0_0));
    }

    function test_installClaimAdapter_Success_DifferentMinorPatch() public {
        // V1.0.1 adapter should work with V1 version parameter (same major)
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_1));

        (address adapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_0_1));
    }

    // ============ hotfixFillAdapter Tests ============

    function test_hotfixFillAdapter_Success_OnlyPatchUpgrade() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Hotfix to V1.0.1 (patch upgrade only)
        vm.prank(admin);
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_1));

        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_0_1));
    }

    function test_hotfixFillAdapter_Revert_MinorVersionChange() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Try to hotfix to V1.1.0 (minor version change not allowed)
        vm.expectRevert(IRouterManager.OnlyPatchAllowed.selector);
        vm.prank(admin);
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_1_0));
    }

    function test_hotfixFillAdapter_Revert_MajorVersionChange() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Try to hotfix to V2.0.0 (major version change not allowed)
        vm.expectRevert();
        vm.prank(admin);
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV2_0_0));
    }

    function test_hotfixFillAdapter_Revert_NoAdapterInstalled() public {
        // Try to hotfix without installing first
        vm.expectRevert(IRouterManager.AdapterNotInstalled.selector);
        vm.prank(admin);
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_1));
    }

    // ============ hotfixClaimAdapter Tests ============

    function test_hotfixClaimAdapter_Success_OnlyPatchUpgrade() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Hotfix to V1.0.1 (patch upgrade only)
        vm.prank(admin);
        routerManager.hotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_1));

        (address adapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_0_1));
    }

    function test_hotfixClaimAdapter_Revert_MinorVersionChange() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Try to hotfix to V1.1.0 (minor version change not allowed)
        vm.expectRevert();
        vm.prank(admin);
        routerManager.hotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_1_0));
    }

    function test_hotfixClaimAdapter_Revert_MajorVersionChange() public {
        // First install V1.0.0
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Try to hotfix to V2.0.0 (major version change not allowed)
        vm.expectRevert();
        vm.prank(admin);
        routerManager.hotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV2_0_0));
    }

    function test_hotfixClaimAdapter_Revert_NoAdapterInstalled() public {
        // Try to hotfix without installing first
        vm.expectRevert(IRouterManager.AdapterNotInstalled.selector);
        vm.prank(admin);
        routerManager.hotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_1));
    }

    // ============ Cross-version Tests ============

    function test_installMultipleVersions_DifferentSelectors() public {
        // Should be able to install different versions for different selectors
        vm.startPrank(admin);

        // Install V1.0.0 for fill
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Install V1.1.0 for claim (same major version)
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_1_0));

        vm.stopPrank();

        (address fillAdapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        (address claimAdapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);

        assertEq(fillAdapter, address(adapterV1_0_0));
        assertEq(claimAdapter, address(adapterV1_1_0));
    }

    function test_hotfixSequence_MultiplePatchUpgrades() public {
        // Test that we can do multiple patch upgrades in sequence
        vm.startPrank(admin);

        // Install V1.0.0
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Hotfix to V1.0.1
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_1));

        // Create another patch version for testing
        MockAdapterV1_0_2 adapterV1_0_2 = new MockAdapterV1_0_2(address(routerManager), address(mockArbiter));

        // Hotfix to V1.0.2
        routerManager.hotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_2));

        vm.stopPrank();

        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_0_2));
    }

    // ============ retireFillAdapter Tests ============

    function test_retireFillAdapter_Success() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Verify adapter is installed
        (address adapter, bytes12 tag) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_0_0));

        // Retire the adapter (requires RM_ROLE)
        vm.prank(rmAdmin);
        routerManager.retireFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);

        // Verify adapter is retired (returns address(0))
        (address retiredAdapter, bytes12 retiredTag) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(retiredAdapter, address(0));
        assertEq(retiredTag, bytes12(0));
    }

    function test_retireFillAdapter_EmitsEvent() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Expect the FillAdapter event with address(0) to indicate retirement
        vm.expectEmit(true, true, true, true);
        emit IRouterManager.FillAdapter(Version.PROTOCOL_V1, address(0), FILL_SELECTOR, bytes12(0));

        // Retire the adapter
        vm.prank(rmAdmin);
        routerManager.retireFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
    }

    function test_retireFillAdapter_Revert_NoAdapter() public {
        // Try to retire a non-existent adapter
        vm.expectRevert(IRouterManager.AdapterNotInstalled.selector);
        vm.prank(rmAdmin);
        routerManager.retireFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
    }

    function test_retireFillAdapter_Revert_Unauthorized() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Try to retire without RM_ROLE
        vm.expectRevert();
        vm.prank(admin); // admin has ADD_ROLE, not RM_ROLE
        routerManager.retireFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
    }

    function test_retireFillAdapter_CanReinstallAfterRetire() public {
        // Install an adapter
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // Retire it
        vm.prank(rmAdmin);
        routerManager.retireFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);

        // Should be able to install a new adapter after retirement
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_1_0));

        // Verify new adapter is installed
        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_1_0));
    }

    // ============ retireClaimAdapter Tests ============

    function test_retireClaimAdapter_Success() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Verify adapter is installed
        (address adapter, bytes12 tag) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_0_0));

        // Retire the adapter (requires RM_ROLE)
        vm.prank(rmAdmin);
        routerManager.retireClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);

        // Verify adapter is retired (returns address(0))
        (address retiredAdapter, bytes12 retiredTag) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(retiredAdapter, address(0));
        assertEq(retiredTag, bytes12(0));
    }

    function test_retireClaimAdapter_EmitsEvent() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Expect the ClaimAdapter event with address(0) to indicate retirement
        vm.expectEmit(true, true, true, true);
        emit IRouterManager.ClaimAdapter(Version.PROTOCOL_V1, address(0), CLAIM_SELECTOR, bytes12(0));

        // Retire the adapter
        vm.prank(rmAdmin);
        routerManager.retireClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
    }

    function test_retireClaimAdapter_Revert_NoAdapter() public {
        // Try to retire a non-existent adapter
        vm.expectRevert(IRouterManager.AdapterNotInstalled.selector);
        vm.prank(rmAdmin);
        routerManager.retireClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
    }

    function test_retireClaimAdapter_Revert_Unauthorized() public {
        // First install an adapter
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Try to retire without RM_ROLE
        vm.expectRevert();
        vm.prank(admin); // admin has ADD_ROLE, not RM_ROLE
        routerManager.retireClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
    }

    function test_retireClaimAdapter_CanReinstallAfterRetire() public {
        // Install an adapter
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // Retire it
        vm.prank(rmAdmin);
        routerManager.retireClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);

        // Should be able to install a new adapter after retirement
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_1_0));

        // Verify new adapter is installed
        (address adapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_1_0));
    }

    // ============ Install Event Tests ============

    function test_installFillAdapter_EmitsEvent() public {
        // Expect the FillAdapter event
        vm.expectEmit(true, true, true, true);
        emit IRouterManager.FillAdapter(Version.PROTOCOL_V1, address(adapterV1_0_0), FILL_SELECTOR, bytes12(0));

        // Install the adapter
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));
    }

    function test_installClaimAdapter_EmitsEvent() public {
        // Expect the ClaimAdapter event
        vm.expectEmit(true, true, true, true);
        emit IRouterManager.ClaimAdapter(Version.PROTOCOL_V1, address(adapterV1_0_0), CLAIM_SELECTOR, bytes12(0));

        // Install the adapter
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));
    }
}

// Additional mock adapter for testing multiple patch versions
contract MockAdapterV1_0_2 is AdapterBase {
    constructor(address router, address arbiter) AdapterBase(router, address(0)) SemVer(0, 2) { }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function mockClaim() external payable onlyViaRouter returns (bytes4) {
        return this.mockClaim.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || super.supportsInterface(interfaceId);
    }
}

/// @notice Adapter that returns a non-zero settlementLayerSpender for setTokenApproval tests
contract MockAdapterWithSpender is AdapterBase {
    address public immutable spender;

    constructor(address router, address _spender) AdapterBase(router, address(0)) SemVer(0, 0) {
        spender = _spender;
    }

    function mockFill() external payable onlyViaRouter returns (bytes4) {
        return this.mockFill.selector;
    }

    function settlementLayerSpender() external view override returns (address) {
        return spender;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || super.supportsInterface(interfaceId);
    }
}

/// @notice Standalone adapter-like contract with ARBITER() returning address(0)
/// @dev Can't inherit AdapterBase since its ARBITER immutable defaults to address(this) when 0 is passed
contract MockAdapterZeroArbiter {
    function mockFill() external payable returns (bytes4) {
        return this.mockFill.selector;
    }

    function ARBITER() external pure returns (address) {
        return address(0);
    }

    function ADAPTER_TAG() external pure returns (bytes12) {
        return bytes12(0);
    }

    function semVer() external pure returns (bytes6) {
        return bytes6(bytes.concat(bytes2(uint16(1)), bytes2(uint16(0)), bytes2(uint16(0))));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == MockAdapterZeroArbiter.mockFill.selector
            || interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == type(IAdapter).interfaceId;
    }
}

/// @notice Contract that doesn't implement ERC165 properly (for InvalidAdapter test)
contract NotAnAdapter {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }

    function ADAPTER_TAG() external pure returns (bytes12) {
        return bytes12(0);
    }

    function ARBITER() external pure returns (address) {
        return address(0x69);
    }

    function semVer() external pure returns (bytes6) {
        return bytes6(bytes.concat(bytes2(uint16(1)), bytes2(uint16(0)), bytes2(uint16(0))));
    }
}

contract RouterManagerExtended_Unit_Test is Test {
    RouterManager public routerManager;
    MockArbiter public mockArbiter;

    MockAdapterV1_0_0 public adapterV1_0_0;
    MockAdapterV1_0_1 public adapterV1_0_1;
    MockAdapterV1_1_0 public adapterV1_1_0;

    address public admin = makeAddr("admin");
    address public rmAdmin = makeAddr("rmAdmin");
    address public unauthorized = makeAddr("unauthorized");

    bytes4 public constant FILL_SELECTOR = MockAdapterV1_0_0.mockFill.selector;
    bytes4 public constant CLAIM_SELECTOR = MockAdapterV1_0_0.mockClaim.selector;

    function setUp() public {
        routerManager = new RouterManager(admin, rmAdmin);
        mockArbiter = new MockArbiter();
        adapterV1_0_0 = new MockAdapterV1_0_0(address(routerManager), address(mockArbiter));
        adapterV1_0_1 = new MockAdapterV1_0_1(address(routerManager), address(mockArbiter));
        adapterV1_1_0 = new MockAdapterV1_1_0(address(routerManager), address(mockArbiter));
    }

    // ============ setTokenApproval Tests ============

    function test_setTokenApproval_Succeeds() public {
        address spenderAddr = makeAddr("spender");
        MockAdapterWithSpender adapter = new MockAdapterWithSpender(address(routerManager), spenderAddr);
        address token = address(new MockToken());

        vm.expectEmit(true, true, false, false);
        emit IRouterManager.SetApproval(spenderAddr, token);

        vm.prank(admin);
        routerManager.setTokenApproval(address(adapter), token, 1000 ether);
    }

    function test_setTokenApproval_RevertsWhen_SpenderIsZero() public {
        // Default AdapterBase returns address(0) for settlementLayerSpender
        vm.expectRevert(abi.encodeWithSelector(IRouterManager.SettingApprovalsNotSupported.selector, IAdapter(address(adapterV1_0_0))));
        vm.prank(admin);
        routerManager.setTokenApproval(address(adapterV1_0_0), address(1), 1000 ether);
    }

    function test_setTokenApproval_RevertsWhen_TokenIsZero() public {
        address spenderAddr = makeAddr("spender");
        MockAdapterWithSpender adapter = new MockAdapterWithSpender(address(routerManager), spenderAddr);

        vm.expectRevert(abi.encodeWithSelector(IRouterManager.SettingApprovalsNotSupported.selector, IAdapter(address(adapter))));
        vm.prank(admin);
        routerManager.setTokenApproval(address(adapter), address(0), 1000 ether);
    }

    function test_setTokenApproval_RevertsWhen_Unauthorized() public {
        address spenderAddr = makeAddr("spender");
        MockAdapterWithSpender adapter = new MockAdapterWithSpender(address(routerManager), spenderAddr);
        address token = address(new MockToken());

        vm.expectRevert();
        vm.prank(unauthorized);
        routerManager.setTokenApproval(address(adapter), token, 1000 ether);
    }

    // ============ _requireAdapter Validation Tests ============

    function test_installFillAdapter_RevertsWhen_InvalidAdapter_NoERC165() public {
        NotAnAdapter notAdapter = new NotAnAdapter();

        vm.expectRevert(IRouterManager.InvalidAdapter.selector);
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(notAdapter));
    }

    function test_installFillAdapter_RevertsWhen_InvalidArbiter() public {
        MockAdapterZeroArbiter zeroArbiterAdapter = new MockAdapterZeroArbiter();

        vm.expectRevert(IRouterManager.InvalidArbiter.selector);
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, MockAdapterZeroArbiter.mockFill.selector, address(zeroArbiterAdapter));
    }

    function test_installClaimAdapter_RevertsWhen_InvalidArbiter() public {
        MockAdapterZeroArbiter zeroArbiterAdapter = new MockAdapterZeroArbiter();

        vm.expectRevert(IRouterManager.InvalidArbiter.selector);
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, MockAdapterZeroArbiter.mockFill.selector, address(zeroArbiterAdapter));
    }

    // ============ forceHotfix Tests ============

    function test_forceHotfixFillAdapter_Succeeds_WithMinorVersionChange() public {
        // Install V1.0.0
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        // forceHotfix to V1.1.0 — would fail with regular hotfix (minor version change)
        vm.prank(admin);
        routerManager.forceHotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_1_0));

        (address adapter,) = routerManager.getFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR);
        assertEq(adapter, address(adapterV1_1_0));
    }

    function test_forceHotfixFillAdapter_RevertsWhen_Unauthorized() public {
        vm.prank(admin);
        routerManager.installFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_0));

        vm.expectRevert();
        vm.prank(unauthorized);
        routerManager.forceHotfixFillAdapter(Version.PROTOCOL_V1, FILL_SELECTOR, address(adapterV1_0_1));
    }

    function test_forceHotfixClaimAdapter_Succeeds_WithMinorVersionChange() public {
        // Install V1.0.0
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        // forceHotfix to V1.1.0
        vm.prank(admin);
        routerManager.forceHotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_1_0));

        (address adapter,) = routerManager.getClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR);
        assertEq(adapter, address(adapterV1_1_0));
    }

    function test_forceHotfixClaimAdapter_RevertsWhen_Unauthorized() public {
        vm.prank(admin);
        routerManager.installClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_0));

        vm.expectRevert();
        vm.prank(unauthorized);
        routerManager.forceHotfixClaimAdapter(Version.PROTOCOL_V1, CLAIM_SELECTOR, address(adapterV1_0_1));
    }

    // ============ setAtomicFillSigner Tests ============

    function test_setAtomicFillSigner_Succeeds() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, false, false, false);
        emit IRouterManager.FillSignerSet(newSigner);

        vm.prank(admin);
        routerManager.setAtomicFillSigner(newSigner);

        assertEq(routerManager.$atomicFillSigner(), newSigner);
    }

    function test_setAtomicFillSigner_RevertsWhen_Unauthorized() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        routerManager.setAtomicFillSigner(makeAddr("newSigner"));
    }

    // ============ pauseRouter Tests ============

    function test_pauseRouter_Succeeds() public {
        // Set a signer first
        vm.prank(admin);
        routerManager.setAtomicFillSigner(makeAddr("signer"));

        vm.expectEmit(true, false, false, false);
        emit IRouterManager.FillSignerSet(address(0));

        vm.prank(admin);
        routerManager.pauseRouter();

        assertEq(routerManager.$atomicFillSigner(), address(0));
    }

    function test_pauseRouter_RevertsWhen_Unauthorized() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        routerManager.pauseRouter();
    }

    // ============ constructor Tests ============

    function test_constructor_SetsInitialized() public view {
        assertTrue(routerManager.initialized());
    }

    function test_constructor_GrantsRoles() public view {
        assertTrue(routerManager.hasRole(bytes32(uint256(0x1001)), admin));
        assertTrue(routerManager.hasRole(bytes32(uint256(0x1002)), rmAdmin));
    }
}

/// @notice Minimal ERC20 for setTokenApproval tests
contract MockToken {
    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}
