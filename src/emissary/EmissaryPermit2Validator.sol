// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Contracts
import { ERC7579ValidatorBase } from "modulekit/module-bases/ERC7579ValidatorBase.sol";

// Constants
import { MODULE_TYPE_VALIDATOR } from "modulekit/module-bases/utils/ERC7579Constants.sol";

// Interfaces
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";

// Types
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

/// @title EmissaryPermit2Validator
/// @notice A validator that allows Smart Session emissary contracts to be used with
///         Permit2 signature validation
contract EmissaryPermit2Validator is ERC7579ValidatorBase {
    /* //////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a function is not supported
    error NotSupported();

    /// @notice Thrown when a function is called by an unauthorized sender
    error OnlyPermit2();

    IEmissary public immutable EMISSARY;

    mapping(address account => bool isInit) public isInitialized;

    /// @notice Constructor to set the Smart Session Emissary address
    /// @param emissary The address of the Smart Session Emissary contract
    constructor(address emissary) {
        EMISSARY = IEmissary(emissary);
    }

    /* //////////////////////////////////////////////////////////////
                               VALIDATION
    //////////////////////////////////////////////////////////////*/

    function isValidSignatureWithSender(address, bytes32 hash, bytes calldata data) external view virtual override returns (bytes4) {
        // Decode lockTag from the first 12 bytes of data
        bytes12 lockTag = bytes12(data[:12]);
        // Delegate to the Smart Session Emissary for signature verification
        return EMISSARY.verifyClaim({ sponsor: msg.sender, digest: hash, claimHash: bytes32(0), signature: data[12:], lockTag: lockTag });
    }

    /* //////////////////////////////////////////////////////////////
                              7579 CONFIG
    //////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata) external override {
        isInitialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata) external override {
        isInitialized[msg.sender] = false;
    }

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /* //////////////////////////////////////////////////////////////
                              UNSUPPORTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Stub to satisfy the interface, always reverts
    function validateUserOp(PackedUserOperation calldata, bytes32) external virtual override returns (ValidationData) {
        revert NotSupported();
    }
}
