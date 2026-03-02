// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockReceiver {
    uint256 public lastValue;

    function receiveWithData(uint256 value) external payable {
        lastValue = value;
    }

    receive() external payable { }
}
