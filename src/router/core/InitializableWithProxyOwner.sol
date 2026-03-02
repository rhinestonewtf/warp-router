// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

abstract contract InitializableWithProxyOwner {
    error UnauthorizedInit();
    /**
     * @notice Modifier to restrict access to the proxy owner only
     * @dev Reads the owner address from the upgradeable beacon owner slot.
     *      This is used for proxy initialization to prevent unauthorized access.
     */

    modifier onlyProxyOwner() {
        // Calculate the storage slot for the upgradeable beacon owner
        // This is `uint72(bytes9(keccak256("_UPGRADEABLE_BEACON_OWNER_SLOT")))`
        uint256 _UPGRADEABLE_BEACON_OWNER_SLOT = 0x4343a0dc92ed22dbfc;
        address owner;

        assembly ("memory-safe") {
            // Load the owner address from the calculated storage slot
            owner := sload(_UPGRADEABLE_BEACON_OWNER_SLOT)
        }
        require(msg.sender == owner, UnauthorizedInit()); // Only the proxy owner can call this function
        _;
    }
}
