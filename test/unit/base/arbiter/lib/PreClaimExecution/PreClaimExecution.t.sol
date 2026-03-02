// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { PreClaimExecution } from "@rhinestone/compact-utils/src/base/arbiter/lib/PreClaimExecution.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { IAddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/IAddressBook.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { AddressBookLib } from "@rhinestone/compact-utils/src/common/AddressBook/AddressBook.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

/* //////////////////////////////////////////////////////////////
                            MOCKS
//////////////////////////////////////////////////////////////*/

/// @notice Reuse MockAddressBook from existing tests
contract MockAddressBookForPreClaim is IAddressBook {
    address public executor;

    function setExecutor(address _executor) external {
        executor = _executor;
    }

    function getAddress(AddressBookLib.ID id) external view returns (address) {
        if (AddressBookLib.ID.unwrap(id) == AddressBookLib.ID.unwrap(Constants.INTENT_EXECUTOR_ID)) {
            return executor;
        }
        return address(0);
    }

    function getBytes32(AddressBookLib.ID) external pure returns (bytes32) { return bytes32(0); }
    function getBytes(AddressBookLib.ID) external pure returns (bytes memory) { return ""; }
    function getUint(AddressBookLib.ID) external pure returns (uint256) { return 0; }
    function setAddress(AddressBookLib.ID, address) external { }
    function setAddresses(SetAddress[] calldata) external { }
    function setUint(AddressBookLib.ID, uint256) external { }
    function setUints(SetUint[] calldata) external { }
    function setBytes32(AddressBookLib.ID, bytes32) external { }
    function setBytes32s(SetBytes32[] calldata) external { }
    function setBytes(AddressBookLib.ID, bytes calldata) external { }
    function setBytess(SetBytess[] calldata) external { }
    function unsafeGetAddress(AddressBookLib.ID id) external view returns (address) { return this.getAddress(id); }
}

/// @notice Mock Permit2 intent executor with configurable success/failure
contract MockPermit2IntentExecutor is IPermit2IntentExecutor {
    bool public shouldSucceed = true;

    function setShouldSucceed(bool _val) external {
        shouldSucceed = _val;
    }

    function executePreClaimOpsWithPermit2Stub(
        address,
        EIP712Permit2Stub calldata,
        EIP712Permit2MandateStub calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        view
        returns (bytes32)
    {
        if (!shouldSucceed) revert("Permit2 execution failed");
        return keccak256("permit2hash");
    }

    function executeTargetOpsWithPermit2Stub(
        address,
        EIP712Permit2Stub calldata,
        EIP712Permit2MandateDestinationStub calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes32)
    {
        return bytes32(0);
    }

    function isPermit2IntentNonceConsumed(uint256, address) external pure returns (bool) {
        return false;
    }
}

/// @notice Mock Compact intent executor with configurable sigOk/execOk and signature recording
contract MockCompactIntentExecutorForPreClaim is ICompactIntentExecutor {
    bool public sigOkReturn = true;
    bool public execOkReturn = true;
    bool public shouldRevert;
    bytes public lastSignatureReceived;

    function setSigOkReturn(bool _val) external {
        sigOkReturn = _val;
    }

    function setExecOkReturn(bool _val) external {
        execOkReturn = _val;
    }

    function setShouldRevert(bool _val) external {
        shouldRevert = _val;
    }

    function executePreClaimOpsWithCompactStub(
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubOrigin calldata,
        Types.Operation calldata,
        bytes calldata signature
    )
        external
        returns (bool sigOk, bool execOk)
    {
        lastSignatureReceived = signature;
        if (shouldRevert) revert("Compact execution failed");
        sigOk = sigOkReturn;
        execOk = execOkReturn;
    }

    function executeTargetOpsWithCompactStub(
        address,
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubDestination calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes32)
    {
        return bytes32(0);
    }

    function isCompactIntentNonceConsumed(uint256, address) external pure returns (bool) {
        return false;
    }
}

/// @notice Test arbiter exposing Permit2, Multicall, Calldata, and CompactERC7579 preclaim handlers
contract MockArbiterForPreClaim is PreClaimExecution {
    constructor(address addressBook) PreClaimExecution(addressBook) { }

    function callHandlePreClaimOpsPermit2ERC7579(
        address account,
        IPermit2IntentExecutor.EIP712Permit2Stub memory permit2Stub,
        IPermit2IntentExecutor.EIP712Permit2MandateStub memory mandateStub,
        Types.Operation calldata preClaimOps,
        bytes calldata signature,
        uint256 preClaimGasStipend
    )
        external
        returns (bool success)
    {
        return _handlePreClaimOpsPermit2ERC7579(account, permit2Stub, mandateStub, preClaimOps, signature, preClaimGasStipend);
    }

    function callHandlePreClaimOpsMulticall(Types.Operation calldata preClaimOps, uint256 preClaimGasStipend)
        external
        returns (bool success)
    {
        return _handlePreClaimOpsMulticall(preClaimOps, preClaimGasStipend);
    }

    function callHandlePreClaimOpsCallData(address target, bytes calldata callData, uint256 preClaimGasStipend)
        external
        returns (bool success)
    {
        return _handlePreClaimOpsCallData(target, callData, preClaimGasStipend);
    }

    function callHandlePreClaimOpsCompactERC7579(
        address account,
        Types.Order calldata order,
        Types.Signatures calldata signature,
        ICompactIntentExecutor.EIP712ElementStubOrigin memory elementStub,
        uint256 notarizedChainId,
        uint256 preClaimGasStipend,
        SmartExecutionLib.SigMode sigMode
    )
        external
        returns (bool success)
    {
        return _handlePreClaimOpsCompactERC7579(account, order, signature, elementStub, notarizedChainId, preClaimGasStipend, sigMode);
    }
}

/// @notice Simple target contract for testing calldata/multicall operations
contract MockCallTarget {
    uint256 public value;
    bool public shouldRevert;

    function setShouldRevert(bool _val) external {
        shouldRevert = _val;
    }

    function doSomething(uint256 _val) external {
        if (shouldRevert) revert("doSomething reverted");
        value = _val;
    }
}

/* //////////////////////////////////////////////////////////////
                        BASE TEST CONTRACT
//////////////////////////////////////////////////////////////*/

contract PreClaimExecution_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    MockArbiterForPreClaim internal arbiter;
    MockPermit2IntentExecutor internal mockPermit2Executor;
    MockAddressBookForPreClaim internal addressBook;
    MockCallTarget internal callTarget;

    address internal account = address(0x1234);
    uint256 internal constant GAS_STIPEND = 1_000_000;

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        addressBook = new MockAddressBookForPreClaim();
        mockPermit2Executor = new MockPermit2IntentExecutor();
        addressBook.setExecutor(address(mockPermit2Executor));
        arbiter = new MockArbiterForPreClaim(address(addressBook));
        callTarget = new MockCallTarget();
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createPermit2Stub() internal pure returns (IPermit2IntentExecutor.EIP712Permit2Stub memory) {
        return IPermit2IntentExecutor.EIP712Permit2Stub({ nonce: 1, expires: type(uint256).max });
    }

    function _createMandateStub() internal pure returns (IPermit2IntentExecutor.EIP712Permit2MandateStub memory) {
        return IPermit2IntentExecutor.EIP712Permit2MandateStub({
            tokenInHash: keccak256("tokenIn"),
            minGas: 0,
            targetAttributesHash: keccak256("attrs"),
            destOpsHash: keccak256("dest"),
            qHash: keccak256("q")
        });
    }

    function _buildERC7579Ops() internal view returns (Types.Operation memory) {
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(callTarget),
            value: 0,
            callData: abi.encodeCall(MockCallTarget.doSomething, (42))
        });
        return Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.ERC7579),
                uint8(SmartExecutionLib.SigMode.ERC1271),
                abi.encode(execs)
            )
        });
    }

    function _buildMulticallOps() internal view returns (Types.Operation memory) {
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(callTarget),
            value: 0,
            callData: abi.encodeCall(MockCallTarget.doSomething, (42))
        });
        return Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.MultiCall),
                uint8(SmartExecutionLib.SigMode.ERC1271),
                abi.encode(execs)
            )
        });
    }

    function _buildCalldataOps() internal view returns (Types.Operation memory) {
        return Types.Operation({
            data: abi.encodePacked(
                uint8(SmartExecutionLib.Type.Calldata),
                uint8(SmartExecutionLib.SigMode.ERC1271),
                address(callTarget),
                abi.encodeCall(MockCallTarget.doSomething, (42))
            )
        });
    }
}
