// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { IntentExecutorAdapter_Unit_Test } from "test/unit/adapters/IntentExecutorAdapter/IntentExecutorAdapter.t.sol";

// Contracts
import { IntentExecutorAdapter } from "@rhinestone/compact-utils/src/adapters/IntentExecutorAdapter.sol";
import { AdapterBase } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";

// Interfaces
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";

// Mocks
import { MockExecutor } from "test/utils/mocks/MockExecutor.sol";

// Types
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract IntentExecutorAdapter_HandleFill_IntentExecutor_HandlePermit2TargetOps_Unit_Test is IntentExecutorAdapter_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_handleFill_intentExecutor_handlePermit2TargetOps_RevertsWhen_OnlyDelegateCall() public {
        // Setup proper permit2 target ops calldata
        (
            address account,
            IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
            IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
            Types.Operation memory targetOps,
            bytes memory signature
        ) = _createPermit2TargetOpsParams();

        bytes memory callData = abi.encode(account, permit2Stub, mandateStub, targetOps, signature);

        // Expect revert
        vm.expectRevert(AdapterBase.OnlyDelegateCall.selector);
        intentExecutorAdapter.handleFill_intentExecutor_handlePermit2TargetOps(callData);
    }

    function test_handleFill_intentExecutor_handlePermit2TargetOps() public {
        // Setup proper permit2 target ops calldata
        (
            address account,
            IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
            IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
            Types.Operation memory targetOps,
            bytes memory signature
        ) = _createPermit2TargetOpsParams();

        bytes memory callData = abi.encode(account, permit2Stub, mandateStub, targetOps, signature);

        // Etch the adapter code to the router address to mock a delegate call
        vm.etch(address(router), address(intentExecutorAdapter).code);

        // Call the function
        vm.expectCall(
            address(mockExecutor),
            abi.encodeWithSelector(
                IPermit2IntentExecutor.executeTargetOpsWithPermit2Stub.selector, account, permit2Stub, mandateStub, targetOps, signature
            )
        );
        IntentExecutorAdapter(address(router)).handleFill_intentExecutor_handlePermit2TargetOps(callData);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createPermit2TargetOpsParams()
        internal
        pure
        returns (
            address account,
            IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
            IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub memory mandateStub,
            Types.Operation memory targetOps,
            bytes memory signature
        )
    {
        account = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);

        permit2Stub = IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: 456, expires: 2_234_567_890 });

        mandateStub = IPermit2IntentExecutor.EIP712Permit2MandateDestinationStub({
            sponsor: address(0x1111111111111111111111111111111111111111),
            arbiter: address(0x2222222222222222222222222222222222222222),
            minGas: 0,
            notarizedChainId: 10, // Optimism
            preClaimOpsHash: keccak256("permit2PreClaimOps"),
            tokenInHash: keccak256("permit2TokenIn"),
            qHash: keccak256("permit2Qualifier"),
            targetStub: IPermit2IntentExecutor.Target({ fillExpiry: 8_888_888_888, tokenOutHash: keccak256("permit2TokenOut") })
        });

        targetOps = Types.Operation({ data: hex"4206969420" });

        signature = new bytes(65);
        signature[64] = 0x1b; // v value
    }
}
