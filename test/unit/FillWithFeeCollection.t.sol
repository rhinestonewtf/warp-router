// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/tests/Environment.sol";
import "../../src/tests/MockAdapter.sol";
import "../../src/router/core/DirectRoutes.sol";
import { FeeCollector } from "../../src/router/utils/FeeCollector.sol";
import { IDirectRoute } from "../../src/router/core/DirectRoutes.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract MockFeeRouter is DirectRoutes {
    function processDirectClaimRoute(bytes calldata adapterCalldata) external {
        _processDirectFillRoute(bytes4(adapterCalldata[:4]), adapterCalldata[4:]);
    }
}

contract FillWithFeeCollectionTest is CompactEnvironment {
    MockAdapter mockAdapter;
    MockFeeRouter mockFeeRouter;

    address constant FEE_RECIPIENT1 = address(0xFEE1);
    address constant FEE_RECIPIENT2 = address(0xFEE2);

    function setUp() public {
        _deployCompact();
        mockAdapter = new MockAdapter(address(env.router), address(0));
        mockFeeRouter = new MockFeeRouter();

        // Register the mock adapter's function with the router
        _setFillRoute(mockAdapter.mockFill.selector, address(mockAdapter));

        // Fund the test contract with tokens for fee payments
        env.token1.mint(address(this), 1000e18);
        env.token2.mint(address(this), 1000e18);
        env.token3.mint(address(this), 1000e18);

        // Approve the fee router to spend tokens
        env.token1.approve(address(mockFeeRouter), type(uint256).max);
        env.token2.approve(address(mockFeeRouter), type(uint256).max);
        env.token3.approve(address(mockFeeRouter), type(uint256).max);
    }

    function _createValidSignature(bytes[] memory adapterCalldatas) internal view returns (bytes memory) {
        // Create EIP-712 digest following the router's implementation
        bytes32 hash = keccak256(abi.encode(adapterCalldatas));

        // Sign with atomic fill signer using the Environment's _signHashRaw helper
        return _signHashRaw(env.atomicFillSigner, hash);
    }

    function test_FillWithMockAdapterAndFeeCollection() public {
        bytes32 nonce = keccak256("test_nonce_1");
        address recipient = address(0x789);

        // Create tokenOut array for mock adapter
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(env.token1))), 100e18];

        // Create fee data for fee collection
        uint256[2][] memory tokenAndAmounts = new uint256[2][](2);
        tokenAndAmounts[0] = [uint256(uint160(address(env.token1))), 1e18];
        tokenAndAmounts[1] = [uint256(uint160(address(env.token2))), 2e18];

        FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts });
        FeeCollector.Fee memory fee2 = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts });

        // Record balances before
        uint256 recipient1Token1Before = env.token1.balanceOf(FEE_RECIPIENT1);
        uint256 recipient1Token2Before = env.token2.balanceOf(FEE_RECIPIENT1);

        // Call the fee collection directly on our mock router
        bytes memory adapterData = abi.encodeCall(IDirectRoute.onFill_inRouter_collectFee, (fee));

        console2.logBytes(adapterData);

        mockFeeRouter.processDirectClaimRoute(adapterData);

        FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](1);
        fees[0] = fee;
        // fees[1] = fee2;
        adapterData = abi.encodeCall(IDirectRoute.onFill_inRouter_collectFees, (fees));
        mockFeeRouter.processDirectClaimRoute(adapterData);

        console2.logBytes(adapterData);
    }

    // function test_FillWithMultipleFeeCollections() public {
    // // Create multiple fees
    // uint256[2][] memory tokenAndAmounts1 = new uint256[2][](1);
    // tokenAndAmounts1[0] = [uint256(uint160(address(env.token1))), 1e18];
    //
    // uint256[2][] memory tokenAndAmounts2 = new uint256[2][](2);
    // tokenAndAmounts2[0] = [uint256(uint160(address(env.token2))), 3e18];
    // tokenAndAmounts2[1] = [uint256(uint160(address(env.token3))), 4e18];
    //
    // FeeCollector.Fee memory fee1 = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts1 });
    //
    // FeeCollector.Fee memory fee2 = FeeCollector.Fee({ recipient: FEE_RECIPIENT2, tokenAndAmounts: tokenAndAmounts2 });
    //
    // // Record balances before
    // uint256 recipient1Token1Before = env.token1.balanceOf(FEE_RECIPIENT1);
    // uint256 recipient2Token2Before = env.token2.balanceOf(FEE_RECIPIENT2);
    // uint256 recipient2Token3Before = env.token3.balanceOf(FEE_RECIPIENT2);
    //
    // // Create array of fees
    // FeeCollector.Fee[] memory fees = new FeeCollector.Fee[](2);
    // fees[0] = fee1;
    // fees[1] = fee2;
    //
    // // Call the fee collection for multiple fees
    // mockFeeRouter.onFill_inRouter_collectFees(abi.encode(fees));
    //
    // // Verify fees were collected for both recipients
    // assertEq(env.token1.balanceOf(FEE_RECIPIENT1), recipient1Token1Before + 1e18, "FEE_RECIPIENT1 should receive 1e18 token1");
    // assertEq(env.token2.balanceOf(FEE_RECIPIENT2), recipient2Token2Before + 3e18, "FEE_RECIPIENT2 should receive 3e18 token2");
    // assertEq(env.token3.balanceOf(FEE_RECIPIENT2), recipient2Token3Before + 4e18, "FEE_RECIPIENT2 should receive 4e18 token3");
    //
    // // Verify both fees were marked as collected
    // bytes32 feeHash1 = keccak256(abi.encode(fee1));
    // bytes32 feeHash2 = keccak256(abi.encode(fee2));
    // assertTrue(mockFeeRouter.feeCollected(feeHash1), "Fee1 should be marked as collected");
    // assertTrue(mockFeeRouter.feeCollected(feeHash2), "Fee2 should be marked as collected");
    //
    // console.log("Successfully collected multiple fees");
    // console.log("FEE_RECIPIENT1 received 1e18 token1");
    // console.log("FEE_RECIPIENT2 received 3e18 token2 and 4e18 token3");
    //}
    //
    // function test_FillWithOnlyMockAdapter() public {
    // bytes32 nonce = keccak256("test_nonce_no_fee");
    // address recipient = address(0x789);
    //
    // // Create tokenOut array
    // uint256[2][] memory tokenOut = new uint256[2][](1);
    // tokenOut[0] = [uint256(uint160(address(env.token1))), 100e18];
    //
    // // Prepare single adapter calldata (no fee collection)
    // bytes[] memory relayerContexts = new bytes[](1);
    // bytes[] memory adapterCalldatas = new bytes[](1);
    //
    // relayerContexts[0] = abi.encode("test_solver_context_only_fill");
    // adapterCalldatas[0] = abi.encodeWithSelector(mockAdapter.mockFill.selector, nonce, recipient, tokenOut);
    //
    // // Create proper atomic signature
    // bytes memory signature = _createValidSignature(adapterCalldatas);
    //
    // // Execute only the mock adapter operation
    // vm.prank(env.solver.addr);
    // env.router.optimized_routeFill921336808(relayerContexts, abi.encode(adapterCalldatas), signature);
    //
    // // Verify the mock fill was executed without fee collection
    // assertTrue(mockAdapter.fillExecuted(nonce), "Mock fill should have been executed");
    //
    // console.log("Successfully executed mock fill without fee collection");
    // console.log("Fill nonce:", vm.toString(uint256(nonce)));
    //}
    //
    // function test_FeeCollectionWithDifferentTokens() public {
    // // Test fee collection with multiple different tokens to the same recipient
    // uint256[2][] memory tokenAndAmounts = new uint256[2][](3);
    // tokenAndAmounts[0] = [uint256(uint160(address(env.token1))), 5e18];
    // tokenAndAmounts[1] = [uint256(uint160(address(env.token2))), 10e18];
    // tokenAndAmounts[2] = [uint256(uint160(address(env.token3))), 15e18];
    //
    // FeeCollector.Fee memory fee = FeeCollector.Fee({ recipient: FEE_RECIPIENT1, tokenAndAmounts: tokenAndAmounts });
    //
    // // Record balances before
    // uint256 token1Before = env.token1.balanceOf(FEE_RECIPIENT1);
    // uint256 token2Before = env.token2.balanceOf(FEE_RECIPIENT1);
    // uint256 token3Before = env.token3.balanceOf(FEE_RECIPIENT1);
    //
    // // Execute fee collection
    // mockFeeRouter.onFill_inRouter_collectFee(abi.encode(fee));
    //
    // // Verify all token fees were collected
    // assertEq(env.token1.balanceOf(FEE_RECIPIENT1), token1Before + 5e18, "Should receive 5e18 token1");
    // assertEq(env.token2.balanceOf(FEE_RECIPIENT1), token2Before + 10e18, "Should receive 10e18 token2");
    // assertEq(env.token3.balanceOf(FEE_RECIPIENT1), token3Before + 15e18, "Should receive 15e18 token3");
    //
    // console.log("Successfully collected fees for multiple different tokens");
    //}
}
