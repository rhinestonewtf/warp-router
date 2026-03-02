// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { FeeCollector_Unit_Test } from "../FeeCollector.t.sol";

// Contracts
import { FeeCollector } from "src/router/utils/FeeCollector.sol";

contract FeeCollector_CollectFee_Unit_Test is FeeCollector_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                    SINGLE FEE - STRUCT PARAM
    //////////////////////////////////////////////////////////////*/

    function test_collectFee_SingleToken_Succeeds() public {
        FeeCollector.Fee memory fee = _createSingleTokenFee(address(token1), 10 ether);

        vm.prank(relayer);
        token1.approve(address(feeCollector), 10 ether);

        uint256 recipientBalanceBefore = token1.balanceOf(feeRecipient1);
        uint256 relayerBalanceBefore = token1.balanceOf(relayer);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);

        assertEq(token1.balanceOf(feeRecipient1), recipientBalanceBefore + 10 ether);
        assertEq(token1.balanceOf(relayer), relayerBalanceBefore - 10 ether);
    }

    function test_collectFee_MultipleTokens_Succeeds() public {
        FeeCollector.Fee memory fee = _createMultipleTokenFee();

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), 5 ether);
        token2.approve(address(feeCollector), 15 ether);
        vm.stopPrank();

        uint256 recipient1BalanceBefore = token1.balanceOf(feeRecipient1);
        uint256 recipient2BalanceBefore = token2.balanceOf(feeRecipient1);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);

        assertEq(token1.balanceOf(feeRecipient1), recipient1BalanceBefore + 5 ether);
        assertEq(token2.balanceOf(feeRecipient1), recipient2BalanceBefore + 15 ether);
    }

    function test_collectFee_ZeroAmount_Succeeds() public {
        FeeCollector.Fee memory fee = _createSingleTokenFee(address(token1), 0);

        uint256 recipientBalanceBefore = token1.balanceOf(feeRecipient1);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);

        assertEq(token1.balanceOf(feeRecipient1), recipientBalanceBefore);
    }

    /* //////////////////////////////////////////////////////////////
                    SINGLE FEE - DIRECT PARAMETERS
    //////////////////////////////////////////////////////////////*/

    function test_collectFee_DirectParameters_SingleToken() public {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        vm.prank(relayer);
        token1.approve(address(feeCollector), 10 ether);

        uint256 recipientBalanceBefore = token1.balanceOf(feeRecipient1);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(feeRecipient1, tokenAndAmounts);

        assertEq(token1.balanceOf(feeRecipient1), recipientBalanceBefore + 10 ether);
    }

    function test_collectFee_DirectParameters_MultipleTokens() public {
        uint256[2][] memory tokenAndAmounts = new uint256[2][](3);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), 10 ether];
        tokenAndAmounts[2] = [uint256(uint160(address(token3))), 15 ether];

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), 5 ether);
        token2.approve(address(feeCollector), 10 ether);
        token3.approve(address(feeCollector), 15 ether);
        vm.stopPrank();

        vm.prank(relayer);
        feeCollector.exposed_collectFee(feeRecipient1, tokenAndAmounts);

        assertEq(token1.balanceOf(feeRecipient1), 5 ether);
        assertEq(token2.balanceOf(feeRecipient1), 10 ether);
        assertEq(token3.balanceOf(feeRecipient1), 15 ether);
    }

    /* //////////////////////////////////////////////////////////////
                    BATCH FEE COLLECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_collectFees_DifferentRecipients() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token2))), 20 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient2, tokenAndAmounts: tokenAndAmounts2 });

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), 10 ether);
        token2.approve(address(feeCollector), 20 ether);
        vm.stopPrank();

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);

        assertEq(token1.balanceOf(feeRecipient1), 10 ether);
        assertEq(token2.balanceOf(feeRecipient2), 20 ether);
    }

    function test_collectFees_SameRecipient() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token1))), 15 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts2 });

        vm.prank(relayer);
        token1.approve(address(feeCollector), 25 ether);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);

        assertEq(token1.balanceOf(feeRecipient1), 25 ether);
    }

    function test_collectFees_ComplexScenario() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](3);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](2);
        tokenAndAmounts2[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts2[1] = [uint256(uint160(address(token2))), 20 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient2, tokenAndAmounts: tokenAndAmounts2 });

        uint256[2][] memory tokenAndAmounts3 = new uint256[2][](2);
        tokenAndAmounts3[0] = [uint256(uint160(address(token2))), 15 ether];
        tokenAndAmounts3[1] = [uint256(uint160(address(token3))), 30 ether];
        fees[2] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts3 });

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), 15 ether);
        token2.approve(address(feeCollector), 35 ether);
        token3.approve(address(feeCollector), 30 ether);
        vm.stopPrank();

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);

        assertEq(token1.balanceOf(feeRecipient1), 10 ether);
        assertEq(token2.balanceOf(feeRecipient1), 15 ether);
        assertEq(token3.balanceOf(feeRecipient1), 30 ether);

        assertEq(token1.balanceOf(feeRecipient2), 5 ether);
        assertEq(token2.balanceOf(feeRecipient2), 20 ether);
    }

    function test_collectFees_EmptyArray_Succeeds() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](0);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_collectFee_RevertsWhen_InsufficientBalance() public {
        address poorRelayer = makeAddr("poorRelayer");
        FeeCollector.Fee memory fee = _createSingleTokenFee(address(token1), 10 ether);

        vm.expectRevert();
        vm.prank(poorRelayer);
        feeCollector.exposed_collectFee(fee);
    }

    function test_collectFee_RevertsWhen_InsufficientAllowance() public {
        FeeCollector.Fee memory fee = _createSingleTokenFee(address(token1), 10 ether);

        vm.expectRevert();
        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);
    }

    function test_collectFee_RevertsWhen_PartialInsufficientAllowance() public {
        FeeCollector.Fee memory fee = _createMultipleTokenFee();

        vm.prank(relayer);
        token1.approve(address(feeCollector), 5 ether);

        vm.expectRevert();
        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);
    }

    function test_collectFees_RevertsWhen_OneFeeFailsInBatch() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token2))), 10_000 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts2 });

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), 10 ether);
        token2.approve(address(feeCollector), 10_000 ether);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);

        assertEq(token1.balanceOf(feeRecipient1), 0);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_collectFee_SingleToken(uint256 amount) public {
        amount = bound(amount, 0, 1000 ether);
        FeeCollector.Fee memory fee = _createSingleTokenFee(address(token1), amount);

        vm.prank(relayer);
        token1.approve(address(feeCollector), amount);

        uint256 recipientBalanceBefore = token1.balanceOf(feeRecipient1);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);

        assertEq(token1.balanceOf(feeRecipient1), recipientBalanceBefore + amount);
    }

    function testFuzz_collectFee_MultipleTokens(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 0, 333 ether);
        amount2 = bound(amount2, 0, 333 ether);
        amount3 = bound(amount3, 0, 333 ether);

        uint256[2][] memory tokenAndAmounts = new uint256[2][](3);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), amount1];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), amount2];
        tokenAndAmounts[2] = [uint256(uint160(address(token3))), amount3];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts });

        vm.startPrank(relayer);
        token1.approve(address(feeCollector), amount1);
        token2.approve(address(feeCollector), amount2);
        token3.approve(address(feeCollector), amount3);
        vm.stopPrank();

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fee);

        assertEq(token1.balanceOf(feeRecipient1), amount1);
        assertEq(token2.balanceOf(feeRecipient1), amount2);
        assertEq(token3.balanceOf(feeRecipient1), amount3);
    }

    function testFuzz_collectFees_MultipleFees(uint8 feeCount) public {
        feeCount = uint8(bound(feeCount, 1, 10));

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](feeCount);

        for (uint256 i = 0; i < feeCount; i++) {
            uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
            tokenAndAmounts[0] = [uint256(uint160(address(token1))), 1 ether];
            fees[i] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts });
        }

        vm.prank(relayer);
        token1.approve(address(feeCollector), uint256(feeCount) * 1 ether);

        vm.prank(relayer);
        feeCollector.exposed_collectFee(fees);

        assertEq(token1.balanceOf(feeRecipient1), uint256(feeCount) * 1 ether);
    }
}
