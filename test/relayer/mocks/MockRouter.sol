// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockRouter {
    uint256 public lastSwapAmount;
    uint256 public lastReceivedValue;

    function swap(address, address, uint256 amount) external returns (uint256) {
        lastSwapAmount = amount;
        return amount;
    }

    function failWithReason(string memory reason) external pure {
        revert(reason);
    }

    function payableFunction() external payable {
        lastReceivedValue = msg.value;
    }

    function efficientFunction() external pure returns (bool) {
        return true;
    }
}
