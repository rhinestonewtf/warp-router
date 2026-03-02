// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IAdapter } from "../../interfaces/IAdapter.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IRouterManager } from "../../interfaces/IRouterManager.sol";
import { InitializableWithProxyOwner } from "./InitializableWithProxyOwner.sol";
import { RouterManagerStorageLib, AdapterConfig } from "../lib/RouterStorageLib.sol";
import { SemVerCmp } from "@rhinestone/compact-utils/src/common/semver/SemVerCmp.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title RouterManager
 * @notice Advanced router management contract with semantic versioning support
 * @dev This contract manages adapter installations, upgrades, and access control for a routing system.
 *      It supports both fill and claim adapters with semantic version validation for safe upgrades.
 *
 *      Key features:
 *      - Role-based access control for adapter management
 *      - Semantic version validation for adapter upgrades
 *      - Separate storage for fill and claim adapters
 *      - Hotfix support with patch-only upgrade validation
 *      - Atomic fill signer management with pause functionality
 */
contract RouterManager is AccessControl, IRouterManager, InitializableWithProxyOwner {
    using SemVerCmp for bytes6;
    using SemVerCmp for bytes2;
    using SemVerCmp for address;
    using SafeTransferLib for address;
    using RouterManagerStorageLib for bytes4;
    using RouterManagerStorageLib for AdapterConfig;
    /// @notice Role for adding new routes and setting the atomic fill signer.
    /// @dev Holders of this role can install new adapters, perform hotfixes, and pause the router

    bytes32 internal constant ADD_ROLE = bytes32(uint256(0x1001));

    /// @notice Role for retiring existing routes.
    /// @dev Currently defined but not actively used in this contract version
    bytes32 internal constant RM_ROLE = bytes32(uint256(0x1002));

    /// @notice The address of the signer authorized for atomic fills.
    /// @dev When set to address(0), atomic fills are effectively paused
    address public $atomicFillSigner;

    /// @notice Flag indicating whether the contract has been initialized (for proxy pattern)
    bool public initialized;

    /**
     * @notice Sets up the initial roles for the contract.
     * @param addAdmin The address to be granted the ADD_ROLE.
     * @param rmAdmin The address to be granted the RM_ROLE.
     */
    constructor(address addAdmin, address rmAdmin) {
        _grantRole(ADD_ROLE, addAdmin);
        _grantRole(RM_ROLE, rmAdmin);
        initialized = true;
    }

    /**
     * @notice Initializes the contract when used with a proxy.
     * @dev This function can only be called once.
     * @param atomicSigner The address to set as the atomic fill signer.
     * @param addAdmin The address to be granted the ADD_ROLE.
     * @param rmAdmin The address to be granted the RM_ROLE.
     */
    function initialize(address atomicSigner, address addAdmin, address rmAdmin) external onlyProxyOwner {
        if (initialized) return;
        $atomicFillSigner = atomicSigner;
        _grantRole(ADD_ROLE, addAdmin);
        _grantRole(RM_ROLE, rmAdmin);
        initialized = true;
    }

    /**
     * @notice Pauses atomic fills by setting the atomic fill signer to the zero address.
     * @dev Only callable by an address with the ADD_ROLE.
     */
    function pauseRouter() external onlyRole(ADD_ROLE) {
        $atomicFillSigner = address(0);
        emit FillSignerSet(address(0));
    }

    /**
     * @notice Sets a new atomic fill signer address.
     * @dev Only callable by an address with the ADD_ROLE.
     */
    function setAtomicFillSigner(address newSigner) external onlyRole(ADD_ROLE) {
        $atomicFillSigner = newSigner;
        emit FillSignerSet(newSigner);
    }

    /**
     * @notice Installs a new fill adapter for a specific version and selector
     * @dev Validates that no adapter is currently installed for this version/selector combination.
     *      Performs adapter validation to ensure it implements the required interface.
     * @param protocolVersion The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the adapter contract to install
     * Requirements:
     * - Caller must have ADD_ROLE
     * - No adapter must be currently installed for this version/selector
     * - Adapter must have the same major version as the specified version parameter
     * - Adapter must implement the required interface and pass validation
     */
    function installFillAdapter(bytes2 protocolVersion, bytes4 selector, address adapter) external onlyRole(ADD_ROLE) {
        // Validate that the adapter has the same major version as the specified version
        require(protocolVersion.isProtocolVersionCompatible(adapter), AdapterMajorVersionMismatch());

        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();

        // Use internal function to install adapter and get current one
        address currentAdapter = _installFillAdapter(protocolVersion, selector, adapter, adapterTag);

        // Ensure no adapter is already installed for this version/selector combination
        require(currentAdapter == address(0), AdapterAlreadyInstalled());
    }

    /**
     * @notice Applies a hotfix to an existing fill adapter
     * @dev Validates that an adapter exists and that the new version is only a patch upgrade.
     *      This function enforces semantic versioning rules to ensure safe upgrades.
     * @param version The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract for the hotfix
     * Requirements:
     * - Caller must have ADD_ROLE
     * - An adapter must already be installed for this version/selector
     * - New adapter version must be only a patch upgrade (no major/minor changes)
     * - New adapter must implement the required interface and pass validation
     */
    function hotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE) {
        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();
        // Use internal function to install adapter and get current one
        address currentAdapter = _installFillAdapter(version, selector, adapter, adapterTag);

        // Ensure adapter exists
        require(currentAdapter != address(0), AdapterNotInstalled());

        // CRITICAL SEMVER VALIDATION: Ensure new adapter is only a patch upgrade
        require(adapter.getSemVer().isOnlyPatch(currentAdapter), OnlyPatchAllowed());
    }

    /**
     * @notice Forces a hotfix to an existing fill adapter without semantic versioning restrictions
     * @dev Similar to hotfixFillAdapter but bypasses the isOnlyPatch check, allowing major/minor version changes.
     *      This function should be used with extreme caution as it can introduce breaking changes.
     * @param version The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract for the hotfix
     * Requirements:
     * - Caller must have ADD_ROLE
     * - An adapter must already be installed for this version/selector
     * - New adapter must implement the required interface and pass validation
     * @dev WARNING: This function bypasses semantic versioning validation and can introduce breaking changes
     */
    function forceHotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE) {
        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();
        // Use internal function to install adapter and get current one
        _installFillAdapter(version, selector, adapter, adapterTag);
    }

    /**
     * @notice Installs a new claim adapter for a specific version and selector
     * @dev Validates that no adapter is currently installed for this version/selector combination.
     *      Performs adapter validation to ensure it implements the required interface.
     * @param version The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the adapter contract to install
     * Requirements:
     * - Caller must have ADD_ROLE
     * - No adapter must be currently installed for this version/selector
     * - Adapter must have the same major version as the specified version parameter
     * - Adapter must implement the required interface and pass validation
     */
    function installClaimAdapter(bytes2 version, bytes4 selector, address adapter) public onlyRole(ADD_ROLE) {
        // Validate that the adapter has the same major version as the specified version
        require(version.isProtocolVersionCompatible(adapter), AdapterMajorVersionMismatch());

        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();
        // Use internal function to install adapter and get current one
        address currentAdapter = _installClaimAdapter(version, selector, adapter, adapterTag);

        // Ensure no adapter is already installed for this version/selector combination
        require(currentAdapter == address(0), AdapterAlreadyInstalled());
    }

    /**
     * @notice Applies a hotfix to an existing claim adapter
     * @dev Validates that an adapter exists and that the new version is only a patch upgrade.
     *      This function enforces semantic versioning rules to ensure safe upgrades.
     * @param version The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract for the hotfix
     * Requirements:
     * - Caller must have ADD_ROLE
     * - An adapter must already be installed for this version/selector
     * - New adapter version must be only a patch upgrade (no major/minor changes)
     * - New adapter must implement the required interface and pass validation
     */
    function hotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE) {
        // Use internal function to install adapter and get current one
        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();
        address currentAdapter = _installClaimAdapter(version, selector, adapter, adapterTag);

        // Ensure adapter exists
        require(currentAdapter != address(0), AdapterNotInstalled());

        // CRITICAL SEMVER VALIDATION: Ensure new adapter is only a patch upgrade
        require(adapter.getSemVer().isOnlyPatch(currentAdapter), OnlyPatchAllowed());
    }

    /**
     * @notice Forces a hotfix to an existing claim adapter without semantic versioning restrictions
     * @dev Similar to hotfixClaimAdapter but bypasses the isOnlyPatch check, allowing major/minor version changes.
     *      This function should be used with extreme caution as it can introduce breaking changes.
     * @param version The semantic version of the adapter (6 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract for the hotfix
     * Requirements:
     * - Caller must have ADD_ROLE
     * - An adapter must already be installed for this version/selector
     * - New adapter must implement the required interface and pass validation
     * @dev WARNING: This function bypasses semantic versioning validation and can introduce breaking changes
     */
    function forceHotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external onlyRole(ADD_ROLE) {
        bytes12 adapterTag = IAdapter(adapter).ADAPTER_TAG();
        // Use internal function to install adapter and get current one
        _installClaimAdapter(version, selector, adapter, adapterTag);
    }

    /**
     * @notice Retrieves the fill adapter configuration for a specific version and selector
     * @param version The semantic version of the adapter (2 bytes)
     * @param selector The function selector that the adapter implements
     * @return adapter The address of the installed fill adapter (address(0) if none)
     * @return adapterTag The metadata tag associated with the adapter
     */
    function getFillAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag) {
        AdapterConfig storage $ = selector.withFillAdapter(version);
        adapter = $.adapter;
        adapterTag = $.adapterTag;
    }

    /**
     * @notice Retrieves the claim adapter configuration for a specific version and selector
     * @param version The semantic version of the adapter (2 bytes)
     * @param selector The function selector that the adapter implements
     * @return adapter The address of the installed claim adapter (address(0) if none)
     * @return adapterTag The metadata tag associated with the adapter
     */
    function getClaimAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag) {
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        adapter = $.adapter;
        adapterTag = $.adapterTag;
    }

    /**
     * @notice Retires (removes) an existing fill adapter
     * @dev Removes a previously installed fill adapter, making it unavailable for routing.
     *      This action is irreversible for the specific version/selector combination.
     * @param version The semantic version of the adapter to retire (2 bytes)
     * @param selector The function selector of the adapter to retire
     * Requirements:
     * - Caller must have RM_ROLE
     * - An adapter must be installed for this version/selector combination
     */
    function retireFillAdapter(bytes2 version, bytes4 selector) external onlyRole(RM_ROLE) {
        // Get storage reference for this specific fill adapter version/selector
        AdapterConfig storage $ = selector.withFillAdapter(version);
        address currentAdapter = $.adapter;

        // Ensure adapter exists before attempting to retire
        require(currentAdapter != address(0), AdapterNotInstalled());

        // Clear the adapter configuration
        $.adapter = address(0);
        $.adapterTag = bytes12(0);

        // Emit retirement event
        emit FillAdapter(version, address(0), selector, bytes12(0));
    }

    /**
     * @notice Retires (removes) an existing claim adapter
     * @dev Removes a previously installed claim adapter, making it unavailable for routing.
     *      This action is irreversible for the specific version/selector combination.
     * @param version The semantic version of the adapter to retire (2 bytes)
     * @param selector The function selector of the adapter to retire
     * Requirements:
     * - Caller must have RM_ROLE
     * - An adapter must be installed for this version/selector combination
     */
    function retireClaimAdapter(bytes2 version, bytes4 selector) external onlyRole(RM_ROLE) {
        // Get storage reference for this specific claim adapter version/selector
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        address currentAdapter = $.adapter;

        // Ensure adapter exists before attempting to retire
        require(currentAdapter != address(0), AdapterNotInstalled());

        // Clear the adapter configuration
        $.adapter = address(0);
        $.adapterTag = bytes12(0);

        // Emit retirement event
        emit ClaimAdapter(version, address(0), selector, bytes12(0));
    }

    /**
     * @notice Internal function to install or update a fill adapter and return the previous adapter
     * @dev Core implementation for all fill adapter operations (install, hotfix, forceHotfix)
     * @param version The semantic version of the adapter (2 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract
     * @param adapterTag Arbitrary metadata tag for the adapter (12 bytes)
     * @return currentAdapter The address of the previously installed adapter (address(0) if none)
     */
    function _installFillAdapter(
        bytes2 version,
        bytes4 selector,
        address adapter,
        bytes12 adapterTag
    )
        internal
        returns (address currentAdapter)
    {
        // Get storage reference for this specific fill adapter version/selector
        AdapterConfig storage $ = selector.withFillAdapter(version);
        currentAdapter = $.adapter; // Get currently installed adapter

        _requireAdapter(selector, adapter); // Validate new adapter implements required interface

        // Store the new adapter, replacing any previous version
        $.store(adapter, adapterTag);
        emit FillAdapter(version, adapter, selector, adapterTag);
    }

    /**
     * @notice Internal function to install or update a claim adapter and return the previous adapter
     * @dev Core implementation for all claim adapter operations (install, hotfix, forceHotfix)
     * @param version The semantic version of the adapter (2 bytes)
     * @param selector The function selector that the adapter implements
     * @param adapter The address of the new adapter contract
     * @param adapterTag Arbitrary metadata tag for the adapter (12 bytes)
     * @return currentAdapter The address of the previously installed adapter (address(0) if none)
     */
    function _installClaimAdapter(
        bytes2 version,
        bytes4 selector,
        address adapter,
        bytes12 adapterTag
    )
        internal
        returns (address currentAdapter)
    {
        // Get storage reference for this specific claim adapter version/selector
        AdapterConfig storage $ = selector.withClaimAdapter(version);
        currentAdapter = $.adapter; // Get currently installed adapter

        _requireAdapter(selector, adapter); // Validate new adapter implements required interface

        // Store the new adapter, replacing any previous version
        $.store(adapter, adapterTag);
        emit ClaimAdapter(version, adapter, selector, adapterTag);
    }

    /**
     * @notice Internal function to validate that an adapter implements required interfaces
     * @dev Performs two critical validations:
     *      1. ERC165 interface support check for the given selector
     *      2. Adapter contract validation via delegatecall to isAdapter()
     * @param selector The function selector that the adapter must support
     * @param adapter The address of the adapter contract to validate
     * Requirements:
     * - Adapter must support ERC165 interface for the given selector
     * - Adapter must successfully respond to isAdapter() delegatecall
     * - isAdapter() must return the correct function selector
     */
    function _requireAdapter(bytes4 selector, address adapter) internal view {
        // Validate that adapter supports the required interface via ERC165
        require(IERC165(adapter).supportsInterface(type(IAdapter).interfaceId), InvalidAdapter());
        require(IERC165(adapter).supportsInterface(selector), InvalidAdapter());
        require(IAdapter(adapter).ARBITER() != address(0), InvalidArbiter());
    }

    function setTokenApproval(address adapter, address token, uint256 amount) external onlyRole(ADD_ROLE) {
        address spender = IAdapter(adapter).settlementLayerSpender();
        require(spender != address(0), SettingApprovalsNotSupported(IAdapter(adapter)));
        require(token != address(0), SettingApprovalsNotSupported(IAdapter(adapter)));
        token.safeApprove(spender, amount);
        emit SetApproval(spender, token);
    }
}
