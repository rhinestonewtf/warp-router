// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { RhinestoneRelayerV0 } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV0.sol";
import { TokenAmount } from "@rhinestone/compact-utils/src/relayerPot/RhinestoneRelayerV1.sol";
import { MockRouter } from "../mocks/MockRouter.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

// Test
import { BaseTest } from "./Base.t.sol";

contract RhinestoneRelayerV0_Test is BaseTest {
    RhinestoneRelayerV0 public relayer;
    MockRouter public routerV0;
    MockRouter public routerV1;
    MockERC20 public token;

    address public owner = address(0x1);
    address public relayerEOA = address(0x2);
    address public user = address(0x3);

    function setUp() public virtual override {
        // Deploy mocks
        routerV0 = new MockRouter();
        routerV1 = new MockRouter();
        token = new MockERC20("Test Token", "TEST");

        // Setup initial approvals for both routers
        TokenAmount[] memory approvalsV0 = new TokenAmount[](1);
        approvalsV0[0] = TokenAmount({ token: address(token), amount: 1000e18 });

        // Deploy relayer with both V0 and V1 routers
        relayer = new RhinestoneRelayerV0(address(routerV0), address(routerV1), address(this));

        // Set approvals for V1 router
        relayer.setApprovals(approvalsV0);

        // Manually approve V0 router (since setApprovals only works with V1 router)
        vm.prank(address(relayer));
        token.approve(address(routerV0), 1000e18);

        // Set authorized relayer
        relayer.setRelayer(relayerEOA, true);

        // Set owner
        relayer.transferOwnership(owner);

        // Fund relayer with tokens
        token.mint(address(relayer), 1000e18);
    }
}
