// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// Libraries
import { IdLib } from "the-compact/lib/IdLib.sol";
import { EfficiencyLib } from "the-compact/lib/EfficiencyLib.sol";
import { Component, BatchClaimComponent } from "the-compact/types/Components.sol";

/**
 * @title TokenIdLib
 * @notice Library for unpacking token ids and amounts
 */
library TokenIdLib {
    /* //////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using IdLib for uint256;
    using EfficiencyLib for *;

    error InvalidToAddress();

    /* //////////////////////////////////////////////////////////////
                                 UNPACK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Unpacks a token id and amount from a given index in an array of token ids and amounts
     * @param idsAndAmounts Array of token ids and amounts
     * @param index Index of the token id and amount to unpack
     * @return id Token id
     * @return amount Amount
     */
    function unpackInt(uint256[2][] calldata idsAndAmounts, uint256 index) internal pure returns (uint256 id, uint256 amount) {
        id = idsAndAmounts[index][0];
        amount = idsAndAmounts[index][1];
    }

    /**
     * @notice Unpacks a token address and amount from a given index in an array of token ids and
     * amounts
     * @param idsAndAmounts Array of token ids and amounts
     * @param index Index of the token id and amount to unpack
     * @return token Token address
     * @return amount Amount
     */
    function unpack(uint256[2][] calldata idsAndAmounts, uint256 index) internal pure returns (address token, uint256 amount) {
        token = idsAndAmounts[index][0].toAddress();
        amount = idsAndAmounts[index][1];
    }

    /**
     * @notice Unpacks a token address and amount from a given index in a memory array of token ids
     * and amounts
     * @param idsAndAmounts Array of token ids and amounts
     * @param index Index of the token id and amount to unpack
     * @return token Token address
     * @return amount Amount
     */
    function unpackM(uint256[2][] memory idsAndAmounts, uint256 index) internal pure returns (address token, uint256 amount) {
        token = idsAndAmounts[index][0].toAddress();
        amount = idsAndAmounts[index][1];
    }

    /**
     * @notice Unpacks the last token address and amount in an array of token ids and amounts
     * @param idsAndAmounts Array of token ids and amounts
     * @return token Token address
     * @return amount Amount
     */
    function unpackLast(uint256[2][] calldata idsAndAmounts) internal pure returns (address token, uint256 amount) {
        uint256 lastIndex = idsAndAmounts.length - 1;
        token = idsAndAmounts[lastIndex][0].toAddress();
        amount = idsAndAmounts[lastIndex][1];
    }

    /**
     * @notice Unpacks the last token address and amount in a memory array of token ids and amounts
     * @param idsAndAmounts Array of token ids and amounts
     * @return token Token address
     * @return amount Amount
     */
    function unpackLastM(uint256[2][] memory idsAndAmounts) internal pure returns (address token, uint256 amount) {
        uint256 lastIndex = idsAndAmounts.length - 1;
        token = idsAndAmounts[lastIndex][0].toAddress();
        amount = idsAndAmounts[lastIndex][1];
    }

    // function toAddress(uint256 encodedAddress) internal pure returns (address) {
    // if (encodedAddress >> 160 != 0) {
    // revert InvalidToAddress();
    //}
    // return address(uint160(uint256(encodedAddress)));
    //}

    function toClaimant(address claimant) internal pure returns (uint256 id) {
        assembly {
            id := and(claimant, 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    function toComponent(address claimant, uint256 amount) internal pure returns (Component memory component) {
        component = Component({ claimant: toClaimant(claimant), amount: amount });
    }

    function toComponentArray(Component memory component) internal pure returns (Component[] memory components) {
        components = new Component[](1);
        components[0] = component;
    }

    error TokenNotSorted();

    function requireSorted(uint256[2][] calldata token) internal pure {
        uint256 length = token.length;
        if (length < 2) {
            return; // No need to check if there's only one or no element
        }
        for (uint256 i = 1; i < length; i++) {
            if (token[i][0].toAddress() < token[i - 1][0].toAddress()) {
                revert TokenNotSorted();
            }
        }
    }

    function makeClaimFor(uint256[2][] calldata idsAndAmounts, address claimant)
        internal
        pure
        returns (BatchClaimComponent[] memory batch)
    {
        batch = new BatchClaimComponent[](idsAndAmounts.length);
        for (uint256 i; i < idsAndAmounts.length; i++) {
            uint256 amount = idsAndAmounts[i][1];
            batch[i] = BatchClaimComponent({
                id: idsAndAmounts[i][0], allocatedAmount: amount, portions: toComponentArray(toComponent(claimant, amount))
            });
        }
    }
}
