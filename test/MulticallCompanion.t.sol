// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { CompactEnvironment } from "../src/tests/Environment.sol";
import { MulticallCompanion } from "../src/common/MulticallCompanion.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Constants } from "../src/types/Constants.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { console2 } from "forge-std/console2.sol";

// Mock implementation of MulticallCompanion for testing
contract MockCompanion is MulticallCompanion {
    address public authorizedCaller;
    address public wethAddress;

    constructor(address _authorizedCaller, address _weth) {
        authorizedCaller = _authorizedCaller;
        wethAddress = _weth;
    }

    function _weth() internal view override returns (address) {
        return wethAddress;
    }

    // Expose _multiCall for testing
    function testMultiCall(Execution[] calldata executions) external nonReentrant {
        _multiCall(executions);
    }

    // Expose _singleCall for testing
    function testSingleCall(address target, uint256 value, bytes calldata callData) external {
        _singleCall(target, value, callData);
    }

    // Expose internal drain functions for testing
    function testDrainRemainingToken(address token, address destination) external {
        _drainRemainingToken(token, destination);
    }

    function testDrainLeftoverTokens(address[] calldata tokens, address destination) external {
        _drainLeftoverTokens(tokens, destination);
    }
}

contract MulticallCompanionTest is CompactEnvironment {
    MockCompanion public companion;
    address public recipient;

    event DrainedTokens(address indexed recipient, address indexed token, uint256 indexed amount);
    event ExecutionFailed();

    function setUp() public {
        _deployCompact();
        _deploySmartAccount(true);

        // Deploy mock companion with this contract as authorized caller and env.weth as WETH
        companion = new MockCompanion(address(this), address(env.weth));
        recipient = makeAddr("recipient");

        // Fund the companion with some ETH and tokens
        vm.deal(address(companion), 10 ether);
        env.token1.mint(address(companion), 1000e18);
        env.token2.mint(address(companion), 2000e18);

        // Mint some WETH to the companion
        vm.deal(address(this), 100 ether);
        env.weth.deposit{ value: 50 ether }();
        env.weth.transfer(address(companion), 10 ether);
    }

    // Test onlySelf modifier
    function test_OnlySelf_Revert() public {
        // Direct call should revert
        vm.expectRevert(MulticallCompanion.NotSelf.selector);
        companion.drainLeftoverToken(address(env.token1), recipient);
    }

    // Test draining ERC20 tokens
    function test_DrainERC20Token() public {
        uint256 initialBalance = env.token1.balanceOf(address(companion));
        assertEq(initialBalance, 1000e18);

        // Drain token1 to recipient
        vm.expectEmit(true, true, true, true);
        emit DrainedTokens(recipient, address(env.token1), initialBalance);

        companion.testDrainRemainingToken(address(env.token1), recipient);

        assertEq(env.token1.balanceOf(address(companion)), 0);
        assertEq(env.token1.balanceOf(recipient), initialBalance);
    }

    // Test draining native ETH
    function test_DrainNativeToken() public {
        uint256 initialBalance = address(companion).balance;
        assertEq(initialBalance, 10 ether);

        companion.testDrainRemainingToken(Constants.NATIVE_TOKEN, recipient);

        assertEq(address(companion).balance, 0);
        assertEq(recipient.balance, initialBalance);
    }

    // Test draining multiple tokens
    function test_DrainMultipleTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(env.token1);
        tokens[1] = address(env.token2);
        tokens[2] = Constants.NATIVE_TOKEN;

        uint256 token1Balance = env.token1.balanceOf(address(companion));
        uint256 token2Balance = env.token2.balanceOf(address(companion));
        uint256 ethBalance = address(companion).balance;

        companion.testDrainLeftoverTokens(tokens, recipient);

        assertEq(env.token1.balanceOf(recipient), token1Balance);
        assertEq(env.token2.balanceOf(recipient), token2Balance);
        assertEq(recipient.balance, ethBalance);

        assertEq(env.token1.balanceOf(address(companion)), 0);
        assertEq(env.token2.balanceOf(address(companion)), 0);
        assertEq(address(companion).balance, 0);
    }

    // Test withdrawing WETH
    function test_WithdrawWETH() public {
        uint256 wethBalance = env.weth.balanceOf(address(companion));
        assertEq(wethBalance, 10 ether);

        uint256 recipientInitialBalance = recipient.balance;

        // Create execution to withdraw WETH through multicall
        Execution[] memory executions = new Execution[](1);
        executions[0] =
            Execution({ target: address(companion), value: 0, callData: abi.encodeCall(companion.withdrawWETH, (recipient, 5 ether)) });

        companion.testMultiCall(executions);

        assertEq(env.weth.balanceOf(address(companion)), 5 ether);
        assertEq(recipient.balance, recipientInitialBalance + 5 ether);
    }

    // Test withdrawing all WETH
    function test_WithdrawAllWETH() public {
        uint256 wethBalance = env.weth.balanceOf(address(companion));
        uint256 recipientInitialBalance = recipient.balance;

        // Create execution to withdraw all WETH through multicall
        Execution[] memory executions = new Execution[](1);
        executions[0] =
            Execution({ target: address(companion), value: 0, callData: abi.encodeCall(companion.withdrawAllWETH, (recipient)) });

        companion.testMultiCall(executions);

        assertEq(env.weth.balanceOf(address(companion)), 0);
        assertEq(recipient.balance, recipientInitialBalance + wethBalance);
    }

    // Test multicall with multiple executions
    function test_MultiCall_Success() public {
        // Deploy a simple target contract for testing
        MockTarget target = new MockTarget();

        // Create multiple executions
        Execution[] memory executions = new Execution[](3);

        // Execution 1: Transfer token1
        executions[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (recipient, 100e18)) });

        // Execution 2: Transfer ETH
        executions[1] = Execution({ target: recipient, value: 1 ether, callData: "" });

        // Execution 3: Call target function
        executions[2] = Execution({ target: address(target), value: 0, callData: abi.encodeCall(target.setValue, (42)) });

        uint256 initialToken1Balance = env.token1.balanceOf(recipient);
        uint256 initialEthBalance = recipient.balance;

        companion.testMultiCall(executions);

        // Verify all executions succeeded
        assertEq(env.token1.balanceOf(recipient), initialToken1Balance + 100e18);
        assertEq(recipient.balance, initialEthBalance + 1 ether);
        assertEq(target.value(), 42);
    }

    // Test multicall with failing execution
    function test_MultiCall_ExecutionFailed() public {
        // Create execution that will fail (call non-existent function)
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(env.token1), value: 0, callData: abi.encodeWithSignature("nonExistentFunction()") });

        // The call will revert but won't reach our custom error handler
        vm.expectRevert();
        companion.testMultiCall(executions);
    }

    // Test single call success
    function test_SingleCall_Success() public {
        uint256 initialBalance = env.token1.balanceOf(recipient);

        bytes memory callData = abi.encodeCall(IERC20.transfer, (recipient, 100e18));
        companion.testSingleCall(address(env.token1), 0, callData);

        assertEq(env.token1.balanceOf(recipient), initialBalance + 100e18);
    }

    // Test single call with value transfer
    function test_SingleCall_WithValue() public {
        uint256 initialBalance = recipient.balance;

        companion.testSingleCall(recipient, 1 ether, "");

        assertEq(recipient.balance, initialBalance + 1 ether);
    }

    // Test single call failure
    function test_SingleCall_ExecutionFailed() public {
        bytes memory callData = abi.encodeWithSignature("nonExistentFunction()");

        // The call will revert but won't reach our custom error handler
        vm.expectRevert();
        companion.testSingleCall(address(env.token1), 0, callData);
    }

    // Test receive function
    function test_ReceiveEther() public {
        uint256 initialBalance = address(companion).balance;

        // Send ETH to companion
        (bool success,) = address(companion).call{ value: 1 ether }("");
        assertTrue(success);

        assertEq(address(companion).balance, initialBalance + 1 ether);
    }

    // Test reentrancy protection
    function test_ReentrancyProtection() public {
        ReentrantAttacker attacker = new ReentrantAttacker(companion);

        // Fund attacker
        vm.deal(address(attacker), 1 ether);
        env.token1.mint(address(attacker), 100e18);

        // Attempt reentrancy attack
        vm.expectRevert(); // ReentrancyGuard will revert
        attacker.attack();
    }

    // Test draining token with zero balance
    function test_DrainToken_ZeroBalance() public {
        // Create a new token that companion has no balance of
        MockERC20 newToken = new MockERC20("New", "NEW", 18);

        // Should not revert, just do nothing
        companion.testDrainRemainingToken(address(newToken), recipient);

        assertEq(newToken.balanceOf(recipient), 0);
    }

    // Test multicall with empty executions array
    function test_MultiCall_EmptyArray() public {
        Execution[] memory executions = new Execution[](0);

        // Should not revert, just do nothing
        companion.testMultiCall(executions);
    }
}

// Helper contracts for testing
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }
}

contract ReentrantAttacker {
    MockCompanion public companion;
    bool public attacking;

    constructor(MockCompanion _companion) {
        companion = _companion;
    }

    function attack() external {
        attacking = true;

        // Try to call multicall which should trigger reentrancy guard
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(this), value: 0, callData: abi.encodeCall(this.reenter, ()) });

        companion.testMultiCall(executions);
    }

    function reenter() external {
        if (attacking) {
            attacking = false;

            // Try to reenter multicall
            Execution[] memory executions = new Execution[](1);
            executions[0] = Execution({ target: address(this), value: 0, callData: "" });

            companion.testMultiCall(executions);
        }
    }
}
