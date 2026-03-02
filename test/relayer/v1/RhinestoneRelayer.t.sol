// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV1, TokenAmount } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";
import { MockRouter } from "../mocks/MockRouter.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { BaseTest } from "./Base.t.sol";

contract RhinestoneRelayer_Test is BaseTest {
    RhinestoneRelayerV1 public relayer;
    MockRouter public router;
    MockERC20 public token;

    address public owner = address(0x1);
    address public relayerEOA = address(0x2);
    address public user = address(0x3);

    function setUp() public virtual override {
        // Deploy mocks
        router = new MockRouter();
        token = new MockERC20("Test Token", "TEST");

        // Setup initial approvals
        TokenAmount[] memory approvals = new TokenAmount[](1);
        approvals[0] = TokenAmount({ token: address(token), amount: 1000e18 });

        // Deploy relayer
        relayer = new RhinestoneRelayerV1(address(router), address(this));

        // Set approvals
        relayer.setApprovals(approvals);

        // Set authorized relayer
        relayer.setRelayer(relayerEOA, true);

        // Set owner
        relayer.transferOwnership(owner);

        // Fund relayer with tokens
        token.mint(address(relayer), 1000e18);
    }
}
