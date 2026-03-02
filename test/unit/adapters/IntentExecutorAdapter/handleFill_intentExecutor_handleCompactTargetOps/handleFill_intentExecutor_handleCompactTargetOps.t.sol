// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { IntentExecutorAdapter_Unit_Test } from "test/unit/adapters/IntentExecutorAdapter/IntentExecutorAdapter.t.sol";

// Contracts
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";

// Interfaces
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";

// Mocks
import { MockExecutor } from "test/utils/mocks/MockExecutor.sol";

// Types
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract IntentExecutorAdapter_HandleFill_IntentExecutor_HandleCompactTargetOps_Unit_Test is IntentExecutorAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handleFill_intentExecutor_handleCompactTargetOps_RevertsWhen_OnlyDelegateCall() public {
        // Setup proper compact target ops calldata
        (
            address account,
            address notarizedArbiter,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub,
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            Types.Operation memory targetOps,
            bytes memory signature
        ) = _createCompactTargetOpsParams();

        bytes memory callData = abi.encode(account, notarizedArbiter, compactStub, elementStub, targetOps, signature);

        // Expect revert
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        intentExecutorAdapter.handleFill_intentExecutor_handleCompactTargetOps(callData);
    }

    function test_handleFill_intentExecutor_handleCompactTargetOps() public {
        // Setup proper compact target ops calldata
        (
            address account,
            address notarizedArbiter,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub,
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            Types.Operation memory targetOps,
            bytes memory signature
        ) = _createCompactTargetOpsParams();

        bytes memory callData = abi.encode(account, notarizedArbiter, compactStub, elementStub, targetOps, signature);

        // Etch the adapter code to the router address to mock a delegate call
        vm.etch(address(router), address(intentExecutorAdapter).code);

        // Call the function
        vm.expectCall(
            address(mockExecutor),
            abi.encodeWithSelector(
                ICompactIntentExecutor.executeTargetOpsWithCompactStub.selector,
                account,
                notarizedArbiter,
                compactStub,
                elementStub,
                targetOps,
                signature
            )
        );
        IntentExecutorAdapter(address(router)).handleFill_intentExecutor_handleCompactTargetOps(callData);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createCompactTargetOpsParams()
        internal
        pure
        returns (
            address account,
            address notarizedArbiter,
            ICompactIntentExecutor.EIP712CompactStub memory compactStub,
            ICompactIntentExecutor.EIP712ElementStubDestination memory elementStub,
            Types.Operation memory targetOps,
            bytes memory signature
        )
    {
        account = address(0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef);
        notarizedArbiter = address(0xCAfEcAfeCAfECaFeCaFecaFecaFECafECafeCaFe);

        compactStub = ICompactIntentExecutor.EIP712CompactStub({ nonce: 123, expires: 1_234_567_890, notarizedChainId: 1 });

        bytes32[] memory otherElements = new bytes32[](2);
        otherElements[0] = keccak256("element1");
        otherElements[1] = keccak256("element2");

        elementStub = ICompactIntentExecutor.EIP712ElementStubDestination({
            sponsor: address(0x5555555555555555555555555555555555555555),
            otherElements: otherElements,
            elementOffset: 1,
            preClaimOpsHash: keccak256("preClaimOps"),
            tokenInHash: keccak256("tokenIn"),
            tokenOutHash: keccak256("tokenOut"),
            fillExpires: 9_999_999_999,
            qHash: keccak256("qualifier")
        });

        targetOps = Types.Operation({ data: hex"4206969420" });

        signature = new bytes(65);
        signature[64] = 0x1c; // v value
    }
}
