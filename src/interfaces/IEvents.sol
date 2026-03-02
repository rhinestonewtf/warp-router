// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IIndexedEvents {
    /// @notice Emitted when DirectRoute fill event is used
    event RouterFilled(address recipient, uint256 nonce);

    event RouterClaimed_Permit2(address sponsor, uint256 nonce);
    event RouterClaimed_Compact(address sponsor, uint256 nonce);
}

