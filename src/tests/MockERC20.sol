// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { MockERC20 as ERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) { }

    function increaseAllowance(address spender, uint256 addedValue) public {
        allowance[msg.sender][spender] += addedValue;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public {
        allowance[msg.sender][spender] -= subtractedValue;
    }
}
