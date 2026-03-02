import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Mandate } from "@rhinestone/compact-utils/src/types/TheCompactStructs.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";
import { EIP712TypeHashLib } from "../types/EIP712TypeHashLib.sol";
import { Permit2Lib } from "@rhinestone/compact-utils/src/base/arbiter/Permit2Arbiter/lib/Permit2Lib.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { IStandaloneIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IStandaloneIntent.sol";
import { EIP712Lib } from "@rhinestone/compact-utils/src/executor/StandaloneIntent/lib/EIP712Lib.sol";
import { console2 } from "forge-std/console2.sol";

contract Hasher {
    using EIP712TypeHashLib for *;
    using SmartExecutionLib for Types.Operation;

    bytes32 private constant _NAME_HASH = 0x9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a;
    bytes32 private constant _PERMIT2_DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function hashTypedDataPermit2(uint256 chainId, bytes32 permit2Hash) external pure returns (bytes32 digest) {
        bytes32 domainSeparator = _permit2DomainSeparator(chainId);
        assembly ("memory-safe") {
            mstore(0x00, 0x1901000000000000)
            mstore(0x1a, domainSeparator)
            mstore(0x3a, permit2Hash)
            digest := keccak256(0x18, 0x42)
            mstore(0x3a, 0)
        }
    }

    function _permit2DomainSeparator(uint256 notarizedChainId) internal pure returns (bytes32 notarizedDomainSeparator) {
        assembly ("memory-safe") {
            let m := mload(0x40)
            mstore(m, _PERMIT2_DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), _NAME_HASH)
            mstore(add(m, 0x40), notarizedChainId)
            mstore(add(m, 0x60), PERMIT2)
            notarizedDomainSeparator := keccak256(m, 0x80)
        }
    }

    function hashTokenIn(uint256[2][] calldata tokenIn) external view returns (bytes32) {
        return EIP712TypeHashLib.hashTokenIn(tokenIn);
    }

    function hashTokenPermissions(uint256[2][] calldata tokenIn) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTokenPermissions(tokenIn);
    }

    function hashTokenOut(uint256[2][] calldata tokenOut) external view returns (bytes32) {
        return EIP712TypeHashLib.hashTokenOut(tokenOut);
    }

    function hashQualifier(bytes calldata data) external view returns (bytes32) {
        return keccak256(data);
    }

    function hashTargetAttributes(Types.Order calldata order) external view returns (bytes32) {
        return order.hashTargetAttributes();
    }

    function hashElement(Types.Order calldata order, address arbiter, uint256 originChainId) external view returns (bytes32) {
        return EIP712TypeHashLib.hashElement({ order: order, arbiter: arbiter, originChainId: originChainId, qualifier: order.qualifier });
    }

    function hashMandate(Types.Order calldata order) external view returns (bytes32) {
        return EIP712TypeHashLib.hashMandate(order, order.qualifier);
    }

    function hashMandate(Mandate calldata mandate) external view returns (bytes32) {
        bytes32 tokenOutHash = EIP712TypeHashLib.hashTokenOut(mandate.target.tokenOut);
        bytes32 targetAttrsHash = EIP712TypeHashLib.hashTargetAttributesRaw({
            recipient: mandate.target.recipient,
            tokenOutHash: tokenOutHash,
            targetChainId: mandate.target.targetChain,
            fillDeadline: mandate.target.fillExpiry
        });
        bytes32 preClaimOpsHash = mandate.originOps.hashOps();
        bytes32 destOpsHash = mandate.destOps.hashOps();
        bytes32 qHash = keccak256(mandate.q);

        return EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: targetAttrsHash,
            minGas: uint128(mandate.minGas),
            preClaimOpsHash: preClaimOpsHash,
            destOpsHash: destOpsHash,
            qHash: qHash
        });
    }

    function hashCompact(Types.Order calldata order, bytes32[] calldata allElements) external view returns (bytes32) {
        return EIP712TypeHashLib.hashCompact(order.sponsor, order.nonce, order.expires, keccak256(abi.encodePacked(allElements)));
    }

    function hashOps(Types.Operation calldata ops) external pure returns (bytes32) {
        return ops.hashOps();
    }

    function hashOps(Execution[] calldata execs) external view returns (bytes32) {
        // Encode executions as Operation with NONE signature mode, then hash
        Types.Operation memory ops = SmartExecutionLib.encode(SmartExecutionLib.SigMode.ERC1271_EMISSARY, execs);
        // Convert memory to calldata by using a self-call
        return this.hashOps(ops);
    }

    function hashOps(Execution[] calldata execs, SmartExecutionLib.SigMode sigMode) external view returns (bytes32) {
        // Encode executions as Operation with specified signature mode, then hash
        Types.Operation memory ops = SmartExecutionLib.encode(sigMode, execs);
        // Convert memory to calldata by using a self-call
        return this.hashOps(ops);
    }

    // Additional helper functions for Permit2 testing
    function hashMandateRaw(
        bytes32 targetAttributes,
        uint128 minGas,
        bytes32 preClaimOpsHash,
        bytes32 destOpsHash,
        bytes32 qHash
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashMandateRaw(targetAttributes, minGas, preClaimOpsHash, destOpsHash, qHash);
    }

    function hashPermit2(
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

    function hashOperation(Types.Operation calldata ops) external pure returns (bytes32) {
        return ops.hashOps();
    }

    // Helper for computing complete Permit2 hash for testing
    function permit2HashForTesting(
        IPermit2IntentExecutor.EIP712Permit2Stub calldata permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateStub calldata mandateStub,
        bytes32 preClaimOpsHash,
        address arbiter
    )
        external
        pure
        returns (bytes32 permit2Hash)
    {
        // Compute the mandate hash combining all operation and target parameters
        // Note: v parameter removed, now encoded in Op.vt
        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw({
            targetAttributes: mandateStub.targetAttributesHash,
            minGas: mandateStub.minGas,
            preClaimOpsHash: preClaimOpsHash,
            destOpsHash: mandateStub.destOpsHash,
            qHash: mandateStub.qHash
        });

        // Compute the final Permit2 hash combining mandate with Permit2-specific fields
        permit2Hash = EIP712TypeHashLib.hashPermit2({
            tokenInHash: mandateStub.tokenInHash,
            arbiter: arbiter,
            nonce: permit2Stub.nonce,
            expires: permit2Stub.expires,
            mandate: mandateHash
        });
    }

    // Gas measurement functions for benchmarking
    function measureTokenInGas(uint256[2][] calldata tokenIn) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashTokenIn(tokenIn);
        gasUsed = gasStart - gasleft();
    }

    function measureTokenOutGas(uint256[2][] calldata tokenOut) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashTokenOut(tokenOut);
        gasUsed = gasStart - gasleft();
    }

    function measureCompactGas(Types.Order calldata order, bytes32[] calldata allElements) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashCompact(order.sponsor, order.nonce, order.expires, keccak256(abi.encodePacked(allElements)));
        gasUsed = gasStart - gasleft();
    }

    function measureElementGas(Types.Order calldata order, address arbiter, uint256 originChainId) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashElement(order, arbiter, originChainId, order.qualifier);
        gasUsed = gasStart - gasleft();
    }

    function measureMandateGas(Types.Order calldata order) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashMandate(order, order.qualifier);
        gasUsed = gasStart - gasleft();
    }

    function measureTargetAttributesGas(Types.Order calldata order) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        EIP712TypeHashLib.hashTargetAttributes(order);
        gasUsed = gasStart - gasleft();
    }

    function measureOpsGas(Types.Operation calldata ops) external view returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        ops.hashOps();
        gasUsed = gasStart - gasleft();
    }

    // function permit2_hashWithWitness(
    // ISignatureTransfer.PermitTransferFrom memory permit,
    // bytes32 witness,
    // address arbiter
    //)
    // internal
    // view
    // returns (bytes32)
    //{
    // string memory _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
    // "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    //
    // bytes32 typeHash = keccak256(abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, Permit2Lib.WITNESS_TYPESTRING));
    //
    // bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
    // return keccak256(abi.encode(typeHash, tokenPermissionsHash, arbiter, permit.nonce, permit.deadline, witness));
    //}

    function permit2_hashBatchWithWitness(Types.Order calldata order, address arbiter) external view returns (bytes32) {
        (
            ISignatureTransfer.TokenPermissions[] memory tokenPermission,
            ISignatureTransfer.SignatureTransferDetails[] memory signatureTransferDetails
        ) = Permit2Lib.toTokenPermissions(order.tokenIn, address(0));

        ISignatureTransfer.PermitBatchTransferFrom memory permit =
            ISignatureTransfer.PermitBatchTransferFrom({ permitted: tokenPermission, nonce: order.nonce, deadline: order.expires });

        string memory _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB =
            "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,";

        bytes32 typeHash = keccak256(abi.encodePacked(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, Permit2Lib.WITNESS_TYPESTRING));

        bytes32 mandate = order.hashMandate(order.qualifier);

        uint256 numPermitted = permit.permitted.length;
        bytes32[] memory tokenPermissionHashes = new bytes32[](numPermitted);

        for (uint256 i = 0; i < numPermitted; ++i) {
            tokenPermissionHashes[i] = _hashTokenPermissions(permit.permitted[i]);
        }

        bytes32 hash = keccak256(
            abi.encode(typeHash, keccak256(abi.encodePacked(tokenPermissionHashes)), arbiter, permit.nonce, permit.deadline, mandate)
        );

        return hash;
    }

    function _hashTokenPermissions(ISignatureTransfer.TokenPermissions memory permitted) private pure returns (bytes32) {
        bytes32 _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }

    // StandaloneIntent helper functions
    function hashGasRefund(address token, uint256 exchangeRate, uint256 overhead) external pure returns (bytes32) {
        return EIP712Lib.hashGasRefund(token, exchangeRate, overhead);
    }

    function hashChainOps(
        uint256 chainId,
        uint256 nonce,
        Types.Operation calldata ops,
        bytes32 gasRefundHash
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712Lib.hashChainOps(chainId, nonce, ops, gasRefundHash);
    }

    function hashSingleChainOps(
        address account,
        uint256 nonce,
        Types.Operation calldata ops,
        bytes32 gasRefundHash
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712Lib.hashSingleChainOps(account, nonce, ops, gasRefundHash);
    }

    function hashMultiChainOps(address account, bytes32[] calldata allChains) external pure returns (bytes32) {
        return EIP712Lib.hash(account, allChains);
    }
}
