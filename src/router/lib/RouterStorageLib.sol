// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @notice Configuration struct for storing adapter information in the router
 * @dev This struct is used to store both the adapter address and its associated tag
 *      in a compact format for efficient storage and retrieval.
 *      Storage layout (packed in single slot):
 *      - bytes12 adapterTag: bits 160-255 (upper 96 bits)
 *      - address adapter: bits 0-159 (lower 160 bits)
 */
struct AdapterConfig {
    bytes12 adapterTag; // Arbitrary tag for adapter identification/metadata
    address adapter; // The deployed adapter contract address
}

/**
 * @title RouterManagerStorageLib
 * @notice Library for managing adapter storage using deterministic slot calculation
 * @dev This library provides storage slot calculation and management for fill and claim adapters.
 *      It uses a hash-based slot calculation system that combines base slots, version info,
 *      and function selectors to create unique storage locations for each adapter configuration.
 */
library RouterManagerStorageLib {
    /// @notice Base slot identifier for fill adapter storage
    // "RouterManagerStorage.Fill"
    uint256 internal constant FILL_SLOT = 0x11139132;
    /// @notice Base slot identifier for claim adapter storage
    // "RouterManagerStorage.Claim"
    uint256 internal constant CLAIM_SLOT = 0x53724b44;

    error AdapterNotFound();

    /**
     * @notice Internal function to calculate deterministic storage slot for adapter configs
     * @dev Creates a unique storage slot by hashing together baseSlot, version, and selector.
     *      This ensures each adapter version/selector combination has its own storage location.
     * @param baseSlot The base slot identifier (FILL_SLOT or CLAIM_SLOT)
     * @param protocolVersion The semantic version identifier (2 bytes)
     * @param selector The function selector (4 bytes) for the adapter
     * @return _config Storage reference to the AdapterConfig at the calculated slot
     */
    function __slot(uint256 baseSlot, bytes2 protocolVersion, bytes4 selector) private pure returns (AdapterConfig storage _config) {
        assembly ("memory-safe") {
            // Pack data into memory for hashing:
            // 0x00-0x04: baseSlot (4 bytes)
            // 0x04-0x06: version (2 bytes)
            // 0x06-0x0A: selector (4 bytes)
            mstore(0x00, shl(224, baseSlot)) // Shift left 28 bytes to put 4 bytes at start
            mstore(0x04, protocolVersion)
            mstore(0x06, selector)
            // Hash the packed data to get deterministic storage slot
            _config.slot := keccak256(0x00, 0x0A)
        }
    }

    /**
     * @notice Gets storage reference for a fill adapter configuration
     * @dev Uses the FILL_SLOT base to calculate storage location for fill adapters
     * @param selector The function selector that the adapter implements
     * @param protocolVersion The semantic version of the adapter (2 bytes)
     * @return $config Storage reference to the fill adapter configuration
     */
    function withFillAdapter(bytes4 selector, bytes2 protocolVersion) internal pure returns (AdapterConfig storage $config) {
        $config = __slot(FILL_SLOT, protocolVersion, selector);
    }

    /**
     * @notice Gets storage reference for a claim adapter configuration
     * @dev Uses the CLAIM_SLOT base to calculate storage location for claim adapters
     * @param selector The function selector that the adapter implements
     * @param protocolVersion The semantic version of the adapter (2 bytes)
     * @return $config Storage reference to the claim adapter configuration
     */
    function withClaimAdapter(bytes4 selector, bytes2 protocolVersion) internal pure returns (AdapterConfig storage $config) {
        $config = __slot(CLAIM_SLOT, protocolVersion, selector);
    }

    /**
     * @notice Retrieves the adapter address from storage
     * @param _in Storage reference to the adapter configuration
     * @return out The address of the stored adapter
     */
    function adapterAddress(AdapterConfig storage _in) internal view returns (address out) {
        // Let Solidity handle this naturally - it will optimize to single SLOAD
        out = _in.adapter;
        require(out != address(0), AdapterNotFound());
    }

    /**
     * @notice Stores an adapter address and tag in the configuration
     * @dev Updates both the adapter address and its associated tag in a single operation
     * @param _in Storage reference to the adapter configuration
     * @param adapter The adapter contract address to store
     * @param tag The 12-byte tag to associate with the adapter
     */
    function store(AdapterConfig storage _in, address adapter, bytes12 tag) internal {
        // Store both values - Solidity will pack them efficiently in a single SSTORE
        _in.adapter = adapter;
        _in.adapterTag = tag;
    }

    /**
     * @notice Retrieves both the adapter address and tag from storage
     * @param _in Storage reference to the adapter configuration
     * @return out The address of the stored adapter
     * @return adapterTag The metadata tag associated with the adapter
     */
    function adapterAddressAndTag(AdapterConfig storage _in) internal view returns (address out, bytes12 adapterTag) {
        // Access both values - Solidity's optimizer will combine into single SLOAD since they're packed
        out = _in.adapter;
        adapterTag = _in.adapterTag;
        require(out != address(0), AdapterNotFound());
    }
}
