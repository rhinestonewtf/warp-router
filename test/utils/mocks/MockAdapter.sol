// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AdapterBase, SemVer } from "src/base/adapter/AdapterBase.sol";
import { AdapterBasePrefund } from "src/base/adapter/AdapterBasePrefund.sol";
import { IArbiter } from "src/interfaces/IArbiter.sol";
import { MockERC20 } from "src/tests/MockERC20.sol";

contract MockAdapterLogger {
    mapping(bytes32 => bool) public fillExecuted;
    mapping(bytes32 => bool) public claimExecuted;
    bytes public lastrelayerContext;
    uint256[2][] public lastTokenOut;
    address public lastPrefundFrom;
    address public lastPrefundTo;

    function logFillExecuted(bytes32 nonce) external {
        fillExecuted[nonce] = true;
    }

    function logClaimExecuted(bytes32 nonce) external {
        claimExecuted[nonce] = true;
    }

    function logrelayerContext(bytes calldata context) external {
        lastrelayerContext = context;
    }

    function logTokenOut(uint256[2][] calldata tokenOut) external {
        delete lastTokenOut;
        for (uint256 i = 0; i < tokenOut.length; i++) {
            lastTokenOut.push(tokenOut[i]);
        }
    }

    function logPrefund(address from, address to) external {
        lastPrefundFrom = from;
        lastPrefundTo = to;
    }

    function getLastTokenOut() external view returns (uint256[2][] memory) {
        return lastTokenOut;
    }

    function resetState() external {
        lastrelayerContext = "";
        delete lastTokenOut;
        lastPrefundFrom = address(0);
        lastPrefundTo = address(0);
    }
}

contract MockAdapter is AdapterBasePrefund {
    // Events for testing
    event MockFillCalled(bytes32 indexed nonce, address indexed recipient, uint256[2][] tokenOut);
    event MockClaimCalled(bytes32 indexed nonce, address indexed recipient, uint256[2][] tokenOut);
    event MockPrefundCalled(address indexed from, address indexed to, uint256[2][] tokenOut);
    event MockrelayerContextLoaded(bytes context);
    event Filled(uint256 indexed nonce);
    event Claimed(uint256 indexed nonce);

    // Logger contract for state tracking (since this contract is delegatecalled)
    MockAdapterLogger public immutable logger;

    // Mock arbiter for testing
    MockArbiter internal mockArbiter;

    constructor(address router, address arbiter) AdapterBasePrefund(router, address(0)) SemVer(0, 0) {
        logger = new MockAdapterLogger();
        if (arbiter == address(0)) {
            mockArbiter = MockArbiter(ARBITER);
        }
    }

    function getMockArbiter() external view returns (address) {
        return address(mockArbiter) != address(0) ? address(mockArbiter) : ARBITER;
    }

    function mockFill(bytes32 nonce, address recipient, uint256[2][] calldata tokenOut) external payable onlyViaRouter returns (bytes4) {
        require(!logger.fillExecuted(nonce), "Fill already executed");

        // Load solver context
        (, bytes calldata relayerContext) = _loadRelayerContext();
        logger.logrelayerContext(relayerContext);

        _prefundRecipient(msg.sender, recipient, tokenOut);

        // Store state for testing
        logger.logFillExecuted(nonce);
        logger.logTokenOut(tokenOut);

        // Emit events
        emit MockFillCalled(nonce, recipient, tokenOut);
        emit MockrelayerContextLoaded(relayerContext);
        emit Filled(uint256(nonce));

        return this.mockFill.selector;
    }

    function mockClaim(bytes32 nonce, address recipient, uint256[2][] calldata tokenOut) external payable onlyViaRouter returns (bytes4) {
        require(!logger.claimExecuted(nonce), "Claim already executed");

        // Load solver context
        (, bytes calldata relayerContext) = _loadRelayerContext();
        logger.logrelayerContext(relayerContext);

        _prefundRecipient(msg.sender, recipient, tokenOut);

        // Store state for testing
        logger.logClaimExecuted(nonce);
        logger.logTokenOut(tokenOut);

        // Emit events
        emit MockClaimCalled(nonce, recipient, tokenOut);
        emit MockrelayerContextLoaded(relayerContext);
        emit Claimed(uint256(nonce));

        return this.mockClaim.selector;
    }

    function mockPrefundRecipient(address from, address to, uint256[2][] calldata tokenOut) external returns (bytes4) {
        _prefundRecipient(from, to, tokenOut);

        // Store state for testing
        logger.logPrefund(from, to);
        logger.logTokenOut(tokenOut);

        emit MockPrefundCalled(from, to, tokenOut);
        return this.mockPrefundRecipient.selector;
    }

    function mockPrefundRecipientSingle(address from, address to, address tokenOut, uint256 amountOut) external payable returns (bytes4) {
        _prefundRecipient(from, to, tokenOut, amountOut);

        // Store state for testing
        logger.logPrefund(from, to);
        uint256[2][] memory tokenOutArray = new uint256[2][](1);
        tokenOutArray[0] = [uint256(uint160(tokenOut)), amountOut];
        logger.logTokenOut(tokenOutArray);

        emit MockPrefundCalled(from, to, tokenOutArray);
        return this.mockPrefundRecipientSingle.selector;
    }

    function mockLoadrelayerContext() external pure returns (bytes calldata) {
        (, bytes calldata relayerContext) = _loadRelayerContext();
        return relayerContext;
    }

    // Helper functions for testing
    function fillExecuted(bytes32 nonce) external view returns (bool) {
        return logger.fillExecuted(nonce);
    }

    function claimExecuted(bytes32 nonce) external view returns (bool) {
        return logger.claimExecuted(nonce);
    }

    function lastrelayerContext() external view returns (bytes memory) {
        return logger.lastrelayerContext();
    }

    function getLastTokenOut() external view returns (uint256[2][] memory) {
        return logger.getLastTokenOut();
    }

    function lastPrefundFrom() external view returns (address) {
        return logger.lastPrefundFrom();
    }

    function lastPrefundTo() external view returns (address) {
        return logger.lastPrefundTo();
    }

    function resetState() external {
        logger.resetState();
    }

    // Support ERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == this.mockFill.selector || interfaceId == this.mockClaim.selector || super.supportsInterface(interfaceId);
    }
}

contract MockArbiter is IArbiter {
    // Support ERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IArbiter).interfaceId;
    }
}
