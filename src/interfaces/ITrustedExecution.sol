// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

interface ITrustedExecution {
    function executeWithoutSignature(address account, Execution[] calldata executions) external;
    function executeOpsWithoutSignature(address account, Types.Operation calldata ops) external;
}
