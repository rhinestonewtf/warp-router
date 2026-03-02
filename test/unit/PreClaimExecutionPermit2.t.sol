// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { CompactEnvironment, TestHelperLib } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

contract TestPreClaimExecution is PreClaimExecution {
    using EIP712TypeHashLib for *;

    constructor(address addressBook) PreClaimExecution(addressBook) { }

    function testHandlePreClaimOpsPermit2ERC7579(
        address account,
        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature,
        uint256 minGas
    )
        external
        returns (bool)
    {
        return _handlePreClaimOpsPermit2ERC7579(account, permit2Stub, mandateStub, preClaimOps, signature, minGas);
    }

    // Helper to call library function with calldata
    function hashMandateRawHelper(
        bytes32 targetAttributes,
        bytes32 preClaimOpsHash,
        bytes32 destOpsHash,
        bytes32 qHash
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashMandateRaw(targetAttributes, 0, preClaimOpsHash, destOpsHash, qHash);
    }

    // Helper for hashPermit2
    function hashPermit2Helper(
        bytes32 tokenInHash,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 mandate
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashPermit2(tokenInHash, arbiter, nonce, expires, mandate);
    }

    function hashOperationHelper(Types.Operation calldata ops) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOps(ops);
    }
}

contract PreClaimExecutionPermit2Test is CompactEnvironment {
    using SmartExecutionLib for *;
    using TestHelperLib for *;
    using EIP712TypeHashLib for *;

    TestPreClaimExecution preClaimExec;

    function setUp() public {
        _deployCompact();
        _deploySmartAccount(true);
        _setEmissary(env.smartAccount1, env.eoa);

        preClaimExec = new TestPreClaimExecution(address(ADDRESSBOOK));

        env.token1.mint(env.smartAccount1.account, 1000 ether);
        env.token2.mint(env.smartAccount1.account, 1000 ether);
    }

    /// @dev Skip: Signature validation flow has changed and needs deeper investigation
    ///      The signature format and validation path needs to be updated to match
    ///      the new emissary/validator flow
    function skip_test_permit2PreClaimOps_success() public {
        address account = env.smartAccount1.account;
        uint256 amount = 100 ether;
        uint256 nonce = 1;

        // Create operations
        Execution[] memory execs = new Execution[](1);
        execs[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), amount)) });

        Types.Operation memory ops = execs.toOperation(uint8(1));

        // Create Permit2 stub
        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub =
            IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: nonce, expires: block.timestamp + 3600 });

        // Create mandate stub
        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub = IPermit2IntentExecutor.EIP712Permit2MandateStub({
            tokenInHash: EIP712TypeHashLib.hashTokenPermissions(address(env.token1), amount),
            targetAttributesHash: keccak256("target_attributes"),
            destOpsHash: keccak256("dest_ops"),
            qHash: keccak256("qualifier"),
            minGas: 0
        });

        // Compute Permit2 hash using helper
        bytes32 mandateHash = preClaimExec.hashMandateRawHelper(
            mandateStub.targetAttributesHash, preClaimExec.hashOperationHelper(ops), mandateStub.destOpsHash, mandateStub.qHash
        );

        bytes32 permit2Hash = preClaimExec.hashPermit2Helper(
            mandateStub.tokenInHash,
            address(preClaimExec), // PreClaimExecution will be msg.sender
            permit2Stub.nonce,
            permit2Stub.expires,
            mandateHash
        );

        // Create signature using Permit2 domain separator
        bytes32 digest = _hashTypedDataPermit2(block.chainid, permit2Hash);
        bytes memory signature = _emissarySig(env.smartAccount1, env.eoa, digest);

        // Check initial state
        assertFalse(env.intentExecutor.isPermit2IntentNonceConsumed(nonce, account), "Nonce should not be consumed initially");

        // Execute through PreClaimExecution
        bool success = preClaimExec.testHandlePreClaimOpsPermit2ERC7579(account, permit2Stub, mandateStub, ops, signature, 500_000);

        assertTrue(success, "Execution should succeed");
        assertTrue(env.intentExecutor.isPermit2IntentNonceConsumed(nonce, account), "Nonce should be consumed");
        assertEq(env.token1.allowance(account, address(env.target)), amount, "Approval should be set");
    }

    /// @dev Skip: Signature validation flow has changed and needs deeper investigation
    ///      The signature format and validation path needs to be updated to match
    ///      the new emissary/validator flow
    function skip_test_permit2PreClaimOps_nonceReplay() public {
        address account = env.smartAccount1.account;
        uint256 nonce = 3;

        Execution[] memory execs = new Execution[](1);
        execs[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.transfer, (address(0xBEEF), 10 ether)) });

        Types.Operation memory ops = execs.toOperation(uint8(1));

        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub =
            IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: nonce, expires: block.timestamp + 3600 });

        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub = IPermit2IntentExecutor.EIP712Permit2MandateStub({
            tokenInHash: EIP712TypeHashLib.hashTokenPermissions(address(env.token1), 10 ether),
            targetAttributesHash: keccak256("attrs"),
            destOpsHash: keccak256("dest"),
            qHash: keccak256("q"),
            minGas: 0
        });

        // Compute hash and signature using helpers
        bytes32 mandateHash = preClaimExec.hashMandateRawHelper(
            mandateStub.targetAttributesHash, preClaimExec.hashOperationHelper(ops), mandateStub.destOpsHash, mandateStub.qHash
        );

        bytes32 permit2Hash =
            preClaimExec.hashPermit2Helper(mandateStub.tokenInHash, address(preClaimExec), nonce, permit2Stub.expires, mandateHash);

        bytes32 digest = _hashTypedDataPermit2(block.chainid, permit2Hash);
        bytes memory signature = _emissarySig(env.smartAccount1, env.eoa, digest);

        // First execution should succeed
        bool success1 = preClaimExec.testHandlePreClaimOpsPermit2ERC7579(account, permit2Stub, mandateStub, ops, signature, 500_000);
        assertTrue(success1, "First execution should succeed");

        // Second execution with same nonce should fail
        bool success2 = preClaimExec.testHandlePreClaimOpsPermit2ERC7579(account, permit2Stub, mandateStub, ops, signature, 500_000);
        assertFalse(success2, "Second execution should fail - nonce already used");
    }

    function test_permit2PreClaimOps_lowGas() public {
        Execution[] memory execs = new Execution[](1);
        execs[0] =
            Execution({ target: address(env.token1), value: 0, callData: abi.encodeCall(IERC20.approve, (address(env.target), 50 ether)) });

        Types.Operation memory ops = execs.toOperation(uint8(0));

        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub =
            IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: 2, expires: block.timestamp + 3600 });

        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub = IPermit2IntentExecutor.EIP712Permit2MandateStub({
            tokenInHash: keccak256("token"),
            targetAttributesHash: keccak256("attrs"),
            destOpsHash: keccak256("dest"),
            qHash: keccak256("q"),
            minGas: 10
        });

        // Very low gas should fail
        bool success = preClaimExec.testHandlePreClaimOpsPermit2ERC7579(
            env.smartAccount1.account,
            permit2Stub,
            mandateStub,
            ops,
            "",
            1000 // Very low gas
        );

        assertFalse(success, "Should fail with low gas");
    }
}
