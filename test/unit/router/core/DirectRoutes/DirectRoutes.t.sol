// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { MockDirectRoutes } from "test/utils/mocks/MockDirectRoutes.sol";
import { MockERC20 } from "src/tests/MockERC20.sol";

// Utils
import { FeeCollector } from "src/router/utils/FeeCollector.sol";

contract DirectRoutes_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockDirectRoutes internal directRoutes;

    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    address internal relayer;
    address internal feeRecipient;
    address internal recipient;
    address internal user;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        directRoutes = new MockDirectRoutes();

        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);

        relayer = makeAddr("relayer");
        feeRecipient = makeAddr("feeRecipient");
        recipient = makeAddr("recipient");
        user = makeAddr("user");

        vm.label(address(directRoutes), "DirectRoutes");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(token3), "Token3");

        // Fund accounts
        token1.mint(relayer, 1000 ether);
        token2.mint(relayer, 1000 ether);
        token3.mint(relayer, 1000 ether);

        token1.mint(address(directRoutes), 1000 ether);
        token2.mint(address(directRoutes), 1000 ether);
        token3.mint(address(directRoutes), 1000 ether);

        vm.deal(relayer, 10 ether);
        vm.deal(address(directRoutes), 10 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createSingleFee() internal view returns (FeeCollector.Fee memory) {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        return FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });
    }

    function _createMultipleFees() internal view returns (FeeCollector.Fee memory) {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), 15 ether];

        return FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });
    }
}
