// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IStatelessValidator {
    function validateSignatureWithData(bytes32 hash, bytes calldata sig, bytes calldata data) external view returns (bool validSig);
}
