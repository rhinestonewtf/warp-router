// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { FeeCollector } from "src/router/utils/FeeCollector.sol";
import { MockERC20 } from "src/tests/MockERC20.sol";

// Mocks
import { MockFeeCollector } from "test/utils/mocks/MockFeeCollector.sol";

contract FeeCollector_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockFeeCollector internal feeCollector;

    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    address internal relayer;
    address internal feeRecipient1;
    address internal feeRecipient2;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        feeCollector = new MockFeeCollector();

        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);

        relayer = makeAddr("relayer");
        feeRecipient1 = makeAddr("feeRecipient1");
        feeRecipient2 = makeAddr("feeRecipient2");

        vm.label(address(feeCollector), "FeeCollector");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(token3), "Token3");

        // Fund relayer
        token1.mint(relayer, 1000 ether);
        token2.mint(relayer, 1000 ether);
        token3.mint(relayer, 1000 ether);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createSingleTokenFee(address token, uint256 amount) internal view returns (FeeCollector.Fee memory) {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(token)), amount];

        return FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts });
    }

    function _createMultipleTokenFee() internal view returns (FeeCollector.Fee memory) {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), 15 ether];

        return FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts });
    }
}
