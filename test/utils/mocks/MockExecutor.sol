// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Interfaces
import { IStandaloneIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IStandaloneIntent.sol";
import { IPermit2IntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/IPermit2Intent.sol";
import { ICompactIntentExecutor } from "@rhinestone/compact-utils/src/executor/interfaces/ICompactIntent.sol";

// Types
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

contract MockExecutor is IStandaloneIntentExecutor, IPermit2IntentExecutor, ICompactIntentExecutor {
    /* //////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Executed();

    /* //////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function executeTargetOpsWithCompactStub(
        address,
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubDestination calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bytes32)
    {
        emit Executed();
        return bytes32(0);
    }

    function executePreClaimOpsWithCompactStub(
        address,
        EIP712CompactStub calldata,
        EIP712ElementStubOrigin calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bool sigOk, bool execOk)
    {
        emit Executed();
        return (true, true);
    }

    function executePreClaimOpsWithPermit2Stub(
        address,
        EIP712Permit2Stub calldata,
        EIP712Permit2MandateStub calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bytes32)
    {
        emit Executed();
        return bytes32(0);
    }

    function executeTargetOpsWithPermit2Stub(
        address,
        EIP712Permit2Stub calldata,
        EIP712Permit2MandateDestinationStub calldata,
        Types.Operation calldata,
        bytes calldata
    )
        external
        returns (bytes32)
    {
        emit Executed();
        return bytes32(0);
    }

    function executeMultichainOps(MultiChainOps calldata signedOps) external {
        emit Executed();
    }

    /// @notice Mock implementation of executeSinglechainOps for testing
    /// @dev Emits Executed event without returning any value per interface specification
    function executeSinglechainOps(SingleChainOps calldata signedOps) external {
        emit Executed();
    }

    function executeMultichainOpsWithGasRefund_ERC20(
        MultiChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        emit Executed();
        return (signedOps.account, signedOps.nonce);
    }

    function executeMultichainOpsWithGasRefund_ETH(
        MultiChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        emit Executed();
        return (signedOps.account, signedOps.nonce);
    }

    function executeSinglechainOpsWithGasRefund_ERC20(
        SingleChainOps calldata signedOps,
        GasRefund calldata gasRefund,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        emit Executed();
        return (signedOps.account, signedOps.nonce);
    }

    function executeSinglechainOpsWithGasRefund_ETH(
        SingleChainOps calldata signedOps,
        uint256 overhead,
        address gasRefundRecipient
    )
        external
        returns (address account, uint256 nonce)
    {
        emit Executed();
        return (signedOps.account, signedOps.nonce);
    }

    function isStandaloneIntentNonceConsumed(uint256, address) external pure returns (bool used) {
        return false;
    }

    function isCompactIntentNonceConsumed(uint256, address) external pure returns (bool used) {
        return false;
    }

    function isPermit2IntentNonceConsumed(uint256, address) external pure returns (bool used) {
        return false;
    }
}
