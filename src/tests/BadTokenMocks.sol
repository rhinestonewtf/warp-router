// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BadTokenMocks
 * @notice Collection of mock ERC20 tokens that exhibit various problematic behaviors
 * @dev These mocks are used for testing edge cases and error handling in token interactions
 */

/**
 * @notice Mock ERC20 token that always returns false on transfer
 * @dev Useful for testing handling of tokens that don't revert but return false
 */
contract MockTokenReturnsFalse {
    mapping(address => uint256) public balanceOf;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false; // Always returns false
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false; // Always returns false
    }

    function approve(address, uint256) external pure returns (bool) {
        return false; // Always returns false
    }
}

/**
 * @notice Mock ERC20 token that always reverts on transfer
 * @dev Useful for testing handling of tokens that revert on transfer attempts
 */
contract MockTokenAlwaysReverts {
    mapping(address => uint256) public balanceOf;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address, uint256) external pure {
        revert("Token transfer always reverts");
    }

    function transferFrom(address, address, uint256) external pure {
        revert("Token transferFrom always reverts");
    }

    function approve(address, uint256) external pure {
        revert("Token approve always reverts");
    }
}

/**
 * @notice Mock ERC20 token that charges a fee on transfers
 * @dev Useful for testing handling of tokens with transfer fees (like USDT on some chains)
 */
contract MockTokenWithFees {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public constant FEE_BASIS_POINTS = 100; // 1% fee

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");

        uint256 fee = (amount * FEE_BASIS_POINTS) / 10_000;
        uint256 transferAmount = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += transferAmount;
        // Fee is "burned" (not sent anywhere)

        return true;
    }
}
