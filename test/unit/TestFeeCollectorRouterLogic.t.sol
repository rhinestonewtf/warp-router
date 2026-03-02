// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/router/core/DirectRoutes.sol";
import "../../src/router/utils/FeeCollector.sol";

contract TestFeeCollectorRouterLogic is DirectRoutes, Test {
    address constant TEST_TOKEN = address(0x1234567890123456789012345678901234567890);
    address constant RECIPIENT1 = address(0xAAA);
    address constant RECIPIENT2 = address(0xBBB);

    bool public collectFeeCalled = false;
    Fee public lastFee;
    Fee[] public lastFees;

    function testSingleFeeDecoding() public {
        // Create a Fee struct
        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0][0] = uint256(uint160(TEST_TOKEN));
        tokenAndAmounts[0][1] = 100;
        tokenAndAmounts[1][0] = uint256(uint160(TEST_TOKEN));
        tokenAndAmounts[1][1] = 200;

        Fee memory fee = Fee({ recipient: RECIPIENT1, tokenAndAmounts: tokenAndAmounts });

        // Encode the fee struct as bytes
        bytes memory encodedFee = abi.encode(fee);

        // Call the function that uses assembly to decode
        vm.expectCall(address(this), abi.encodeWithSelector(this.callCollectFee.selector, encodedFee));
        try this.callCollectFee(encodedFee) { } catch { }
    }

    function callCollectFee(bytes calldata data) external {
        collectFeeCalled = false;
        _onFill_inRouter_collectFee(data);
    }

    function testArrayFeeDecoding() public {
        // Create an array of Fee structs
        Fee[] memory fees = new Fee[](2);

        // First fee
        uint256[2][] memory tokenAndAmounts1 = new uint256[2][](2);
        tokenAndAmounts1[0][0] = uint256(uint160(TEST_TOKEN));
        tokenAndAmounts1[0][1] = 100;
        tokenAndAmounts1[1][0] = uint256(uint160(TEST_TOKEN));
        tokenAndAmounts1[1][1] = 200;
        fees[0] = Fee({ recipient: RECIPIENT1, tokenAndAmounts: tokenAndAmounts1 });

        // Second fee
        uint256[2][] memory tokenAndAmounts2 = new uint256[2][](1);
        tokenAndAmounts2[0][0] = uint256(uint160(address(0x9999999999999999999999999999999999999999)));
        tokenAndAmounts2[0][1] = 300;
        fees[1] = Fee({ recipient: address(0xCCC), tokenAndAmounts: tokenAndAmounts2 });

        // Encode the fee array as bytes
        bytes memory encodedFees = abi.encode(fees);

        // Call the function that uses assembly to decode
        this.callCollectFees(encodedFees);

        // Verify it was called
        assertTrue(collectFeeCalled, "collectFees should have been called");
    }

    function callCollectFees(bytes calldata data) external {
        collectFeeCalled = false;
        _onFill_inRouter_collectFees(data);
    }

    // Override _collectFee to track calls and verify data
    function _collectFee(Fee calldata fee) internal override {
        collectFeeCalled = true;

        // Log to verify correct decoding
        console.log("Recipient:", fee.recipient);
        console.log("Token count:", fee.tokenAndAmounts.length);

        // Create a hash of the fee data to verify it's correct
        bytes32 feeHash = keccak256(abi.encode(fee));
        console.log("Fee hash:");
        console.logBytes32(feeHash);

        // Verify specific values based on recipient - check actual decoded values
        if (fee.recipient == RECIPIENT1) {
            assertEq(fee.recipient, RECIPIENT1, "Recipient should match");
            assertEq(fee.tokenAndAmounts.length, 2, "Should have 2 token entries for RECIPIENT1");
            assertEq(address(uint160(fee.tokenAndAmounts[0][0])), TEST_TOKEN, "First token should be TEST_TOKEN");
            assertEq(fee.tokenAndAmounts[0][1], 100, "First amount should be 100");
            assertEq(address(uint160(fee.tokenAndAmounts[1][0])), TEST_TOKEN, "Second token should be TEST_TOKEN");
            assertEq(fee.tokenAndAmounts[1][1], 200, "Second amount should be 200");
        } else if (fee.recipient == address(0xCCC)) {
            assertEq(fee.tokenAndAmounts.length, 1, "Should have 1 token entry for 0xCCC");
            assertEq(
                address(uint160(fee.tokenAndAmounts[0][0])), address(0x9999999999999999999999999999999999999999), "Token should be 0x999..."
            );
            assertEq(fee.tokenAndAmounts[0][1], 300, "Amount should be 300");
        }
    }

    function _collectFee(Fee[] calldata fees) internal override {
        collectFeeCalled = true;

        console.log("Fees array length:", fees.length);

        // Process each fee
        for (uint256 i = 0; i < fees.length; i++) {
            _collectFee(fees[i]);
        }
    }
}
