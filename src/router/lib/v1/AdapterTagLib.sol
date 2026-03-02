// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title AdapterTag
 * @notice Library for parsing adapter tag flags from a bytes12 value
 * @dev Adapter tag layout (12 bytes = 96 bits):
 *
 *      Byte Index: 0 1 2 3 4 5 6 7 8 9 10 11
 *                  ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
 *                  │ │ │ │ │ │ │ │ │ │ │ │ │
 *                  └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
 *      Bit Range: 95 0
 *                   (MSB) (LSB)
 *                                                                             │
 *                                                                             └─ bit 0: skiprelayerContext flag
 *
 *      Bit 0 (LSB): skiprelayerContext flag
 *      Bits 1-95: Reserved for future use
 */
library AdapterTagLib {
    /**
     * @notice Checks if the solver context should be consumed
     * @param adapterTag The 12-byte adapter tag containing flags
     * @return True if the least significant bit (bit 0) is set, false otherwise
     */
    function isSkipRelayerContext(bytes12 adapterTag) internal pure returns (bool) {
        return (uint96(adapterTag) & 1) == 1;
    }

    /**
     * @notice Sets the skiprelayerContext flag by enabling bit 0
     * @param adapterTag The 12-byte adapter tag to modify
     * @return The modified adapter tag with bit 0 set to 1
     */
    function setSkipRelayerContext(bytes12 adapterTag) internal pure returns (bytes12) {
        return bytes12(uint96(adapterTag) | 1);
    }
}
