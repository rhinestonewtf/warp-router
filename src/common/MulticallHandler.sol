// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { MulticallCompanion } from "@rhinestone/compact-utils/src/common/MulticallCompanion.sol";
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";
import { IAddressBook } from "@rhinestone/compact-utils/src/common/AddressBook/IAddressBook.sol";

interface IMulticallHandler {
    function handleTargetOpsMulticall(Types.Operation calldata targetOps) external;
}

contract MulticallHandler is MulticallCompanion {
    using SmartExecutionLib for Types.Operation;

    error InvalidOperationType();

    address internal immutable WETH;

    constructor(address addressBook) {
        WETH = IAddressBook(addressBook).getAddress(Constants.WETH_ID);
    }

    function _weth() internal view virtual override returns (address) {
        return WETH;
    }

    function handleTargetOpsMulticall(Types.Operation calldata targetOps) external nonReentrant {
        SmartExecutionLib.Type execType = targetOps.toExecType();
        if (execType == SmartExecutionLib.Type.MultiCall) {
            Execution[] calldata targetExecs = targetOps.safeToMultiCall();
            _multiCall(targetExecs);
        } else if (execType == SmartExecutionLib.Type.Calldata) {
            (address target, bytes calldata callData) = targetOps.safeToCalldata();
            _singleCall(target, 0, callData);
        } else {
            revert InvalidOperationType();
        }
    }
}
