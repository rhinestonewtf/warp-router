// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { SmartExecutionLib, Types } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";

struct MultichainCompact {
    address sponsor;
    uint256 nonce;
    uint256 expires;
    Element[] elements;
}

struct Element {
    address arbiter;
    uint256 chainId;
    uint256[2][] idsAndAmounts;
    Mandate mandate;
}

struct Mandate {
    Target target;
    uint128 minGas;
    Types.Operation originOps;
    Types.Operation destOps;
    bytes q;
}

struct Target {
    address recipient;
    uint256[2][] tokenOut;
    uint256 targetChain;
    uint256 fillExpiry;
}

struct QualifiedClaim {
    bytes32 claimHash;
    bytes32 qualificationHash;
}
