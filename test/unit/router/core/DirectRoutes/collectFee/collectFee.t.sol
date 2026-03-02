// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "test/unit/router/core/RouterLogic/RouterLogic.t.sol";

// Contracts
import { FeeCollector } from "src/router/utils/FeeCollector.sol";

contract DirectRoutes_CollectFee_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                    COLLECT SINGLE FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_collectFee_SingleToken_Succeeds() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.prank(solver);
        token1.approve(address(routerLogic), 10 ether);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);

        assertEq(token1.balanceOf(feeRecipient), 10 ether);
        assertEq(token1.balanceOf(solver), 990 ether);
    }

    function test_onFill_inRouter_collectFee_MultipleTokens_Succeeds() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), 15 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), 5 ether);
        token2.approve(address(routerLogic), 15 ether);
        vm.stopPrank();

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);

        assertEq(token1.balanceOf(feeRecipient), 5 ether);
        assertEq(token2.balanceOf(feeRecipient), 15 ether);
    }

    function test_onFill_inRouter_collectFee_ZeroAmount_Succeeds() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 0];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);

        assertEq(token1.balanceOf(feeRecipient), 0);
    }

    /* //////////////////////////////////////////////////////////////
                    COLLECT MULTIPLE FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_collectFees_SingleFee_Succeeds() public {
        address feeRecipient = makeAddr("feeRecipient");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](1);

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fees);

        vm.prank(solver);
        token1.approve(address(routerLogic), 10 ether);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        assertEq(token1.balanceOf(feeRecipient), 10 ether);
    }

    function test_onFill_inRouter_collectFees_MultipleFees_DifferentRecipients() public {
        address feeRecipient1 = makeAddr("feeRecipient1");
        address feeRecipient2 = makeAddr("feeRecipient2");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token2))), 20 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient2, tokenAndAmounts: tokenAndAmounts2 });

        bytes memory data = abi.encode(fees);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), 10 ether);
        token2.approve(address(routerLogic), 20 ether);
        vm.stopPrank();

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        assertEq(token1.balanceOf(feeRecipient1), 10 ether);
        assertEq(token2.balanceOf(feeRecipient2), 20 ether);
    }

    function test_onFill_inRouter_collectFees_SameRecipient_MultipleTokens() public {
        address feeRecipient = makeAddr("feeRecipient");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts1 });

        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token1))), 15 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts2 });

        bytes memory data = abi.encode(fees);

        vm.prank(solver);
        token1.approve(address(routerLogic), 25 ether);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        assertEq(token1.balanceOf(feeRecipient), 25 ether);
    }

    function test_onFill_inRouter_collectFees_ComplexScenario() public {
        address feeRecipient1 = makeAddr("feeRecipient1");
        address feeRecipient2 = makeAddr("feeRecipient2");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](3);

        // Fee 1: recipient1 gets token1
        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts1 });

        // Fee 2: recipient2 gets token1 and token2
        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](2);
        tokenAndAmounts2[0] = [uint256(uint160(address(token1))), 5 ether];
        tokenAndAmounts2[1] = [uint256(uint160(address(token2))), 20 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient2, tokenAndAmounts: tokenAndAmounts2 });

        // Fee 3: recipient1 gets token2 and token3
        uint256[2][] memory tokenAndAmounts3 = new uint256[2][](2);
        tokenAndAmounts3[0] = [uint256(uint160(address(token2))), 15 ether];
        tokenAndAmounts3[1] = [uint256(uint160(address(token3))), 30 ether];
        fees[2] = FeeCollector.Fee({ recipient: feeRecipient1, tokenAndAmounts: tokenAndAmounts3 });

        bytes memory data = abi.encode(fees);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), 15 ether);
        token2.approve(address(routerLogic), 35 ether);
        token3.approve(address(routerLogic), 30 ether);
        vm.stopPrank();

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        assertEq(token1.balanceOf(feeRecipient1), 10 ether);
        assertEq(token2.balanceOf(feeRecipient1), 15 ether);
        assertEq(token3.balanceOf(feeRecipient1), 30 ether);

        assertEq(token1.balanceOf(feeRecipient2), 5 ether);
        assertEq(token2.balanceOf(feeRecipient2), 20 ether);
    }

    function test_onFill_inRouter_collectFees_EmptyArray_Succeeds() public {
        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](0);
        bytes memory data = abi.encode(fees);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        // Should succeed without doing anything
    }

    /* //////////////////////////////////////////////////////////////
                            REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onFill_inRouter_collectFee_RevertsWhen_InsufficientBalance() public {
        address poorSolver = makeAddr("poorSolver");
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 100 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.expectRevert();
        vm.prank(poorSolver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);
    }

    function test_onFill_inRouter_collectFee_RevertsWhen_InsufficientAllowance() public {
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), 10 ether];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        // No approval given
        vm.expectRevert();
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);
    }

    function test_onFill_inRouter_collectFees_RevertsWhen_OneFeeFailsInBatch() public {
        address feeRecipient = makeAddr("feeRecipient");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);

        // Fee 1: valid
        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
        tokenAndAmounts1[0] = [uint256(uint160(address(token1))), 10 ether];
        fees[0] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts1 });

        // Fee 2: insufficient balance
        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0] = [uint256(uint160(address(token2))), 10_000 ether];
        fees[1] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts2 });

        bytes memory data = abi.encode(fees);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), 10 ether);
        token2.approve(address(routerLogic), 10_000 ether);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        // First fee should not have been collected due to revert
        assertEq(token1.balanceOf(feeRecipient), 0);
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_onFill_inRouter_collectFee_SingleToken(uint256 amount) public {
        amount = bound(amount, 0, 1000 ether);
        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), amount];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.prank(solver);
        token1.approve(address(routerLogic), amount);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);

        assertEq(token1.balanceOf(feeRecipient), amount);
    }

    function testFuzz_onFill_inRouter_collectFee_MultipleTokens(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 0, 333 ether);
        amount2 = bound(amount2, 0, 333 ether);
        amount3 = bound(amount3, 0, 333 ether);

        address feeRecipient = makeAddr("feeRecipient");

        uint256[2][] memory tokenAndAmounts = new uint256[2][](3);
        tokenAndAmounts[0] = [uint256(uint160(address(token1))), amount1];
        tokenAndAmounts[1] = [uint256(uint160(address(token2))), amount2];
        tokenAndAmounts[2] = [uint256(uint160(address(token3))), amount3];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });

        bytes memory data = abi.encode(fee);

        vm.startPrank(solver);
        token1.approve(address(routerLogic), amount1);
        token2.approve(address(routerLogic), amount2);
        token3.approve(address(routerLogic), amount3);
        vm.stopPrank();

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFee(data);

        assertEq(token1.balanceOf(feeRecipient), amount1);
        assertEq(token2.balanceOf(feeRecipient), amount2);
        assertEq(token3.balanceOf(feeRecipient), amount3);
    }

    function testFuzz_onFill_inRouter_collectFees_MultipleFees(uint8 feeCount) public {
        feeCount = uint8(bound(feeCount, 1, 10));
        address feeRecipient = makeAddr("feeRecipient");

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](feeCount);

        for (uint256 i = 0; i < feeCount; i++) {
            uint256[2][] memory tokenAndAmounts = new uint256[2][](1);
            tokenAndAmounts[0] = [uint256(uint160(address(token1))), 1 ether];
            fees[i] = FeeCollector.Fee({ recipient: feeRecipient, tokenAndAmounts: tokenAndAmounts });
        }

        bytes memory data = abi.encode(fees);

        vm.prank(solver);
        token1.approve(address(routerLogic), uint256(feeCount) * 1 ether);

        vm.prank(solver);
        routerLogic.exposed_onFill_inRouter_collectFees(data);

        assertEq(token1.balanceOf(feeRecipient), uint256(feeCount) * 1 ether);
    }
}
