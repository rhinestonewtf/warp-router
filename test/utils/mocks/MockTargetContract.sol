// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockTargetContract {
    uint256 public value;
    address public lastCaller;
    bool public wasCalled;

    event FunctionCalled(address caller, uint256 value);

    function setValue(uint256 _value) external {
        value = _value;
        lastCaller = msg.sender;
        wasCalled = true;
        emit FunctionCalled(msg.sender, _value);
    }

    function setValuePayable(uint256 _value) external payable {
        value = _value;
        lastCaller = msg.sender;
        wasCalled = true;
    }

    function multiplyValue(uint256 multiplier) external {
        value = value * multiplier;
        lastCaller = msg.sender;
    }

    function revertAlways() external pure {
        revert("Always fails");
    }

    function revertWithMessage(string memory message) external pure {
        revert(message);
    }
}
