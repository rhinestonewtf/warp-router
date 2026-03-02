// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AddressBookLib } from "../common/AddressBook/IAddressBook.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

/**
 * @title Constants
 * @notice Protocol-wide constants for the Compact cross-chain intent system
 * @dev Contains immutable addresses, hash constants, and address book identifiers
 *      used throughout the protocol for consistency and gas optimization
 */
library Constants {
    /// @notice Uniswap's Permit2 contract address (same on all chains)
    ISignatureTransfer internal constant PERMIT2 = ISignatureTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

    /**
     * @notice Hash representing empty execution data
     * @dev keccak256 of empty bytes - used when there are no operations to execute.
     *      This is the hash of an empty Ops[] array in the EIP-712 structure.
     */
    bytes32 internal constant NO_EXEC = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /**
     * @notice Hash representing an empty Op wrapper struct
     * @dev This is the EIP-712 hash of Op(bytes32(0), []) - an empty operation wrapper.
     *      Used when originOps or destOps in a Mandate is empty.
     *      Computed as: keccak256(abi.encode(TYPEHASH_OP, bytes32(0), NO_EXEC))
     *      Different from NO_EXEC because it includes the Op wrapper typehash.
     */
    bytes32 internal constant NO_OPS = 0x0c7bea50822ae8a3846eccbda4961a80e1e08aa92f2bf046be0011514ad2ddf1;

    /// @notice Sentinel address representing native token (ETH/MATIC/etc.)
    address internal constant NATIVE_TOKEN = address(0);

    /// @notice Default adapter tag when no specific tag is required
    bytes12 internal constant DEFAULT_ADAPTER_TAG = bytes12(0);

    /**
     * @notice EIP-712 hash for empty token input arrays
     * @dev Matches keccak256(abi.encodePacked(new bytes32[](0)))
     *      Same value as NO_EXEC since both represent empty arrays
     */
    bytes32 internal constant EMPTY_TOKEN_IN_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /**
     * @notice EIP-712 hash for empty token output arrays
     * @dev Matches keccak256(abi.encodePacked(new bytes32[](0)))
     *      Same value as NO_EXEC since both represent empty arrays
     */
    bytes32 internal constant EMPTY_TOKEN_OUT_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /// @notice Address book identifier for the IntentExecutor contract
    AddressBookLib.ID internal constant INTENT_EXECUTOR_ID = AddressBookLib.ID.wrap(keccak256("IntentExecutor"));

    /// @notice Address book identifier for the SameChainArbiter contract
    AddressBookLib.ID internal constant SAMECHAIN_ARBITER_ID = AddressBookLib.ID.wrap(keccak256("SameChainArbiter"));

    /**
     * @notice Address book identifier for the Paymaster contract
     * @dev The Paymaster handles gas refund settlements in standalone intents
     */
    AddressBookLib.ID internal constant PAYMASTER_ID = AddressBookLib.ID.wrap(keccak256("Paymaster"));

    /// @notice Address book identifier for the WETH contract
    AddressBookLib.ID internal constant WETH_ID = AddressBookLib.ID.wrap(keccak256("WETH"));
}
