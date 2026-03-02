// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@rhinestone/compact-utils/src/tests/Environment.sol";
import { IEmissary, WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { EmissaryLib } from "@rhinestone/compact-utils/src/emissary/lib/EmissaryLib.sol";
import { Emissary } from "@rhinestone/compact-utils/src/emissary/Emissary.sol";

/* //////////////////////////////////////////////////////////////
                        MOCK VALIDATORS
//////////////////////////////////////////////////////////////*/

/// @notice Mock stateless validator that always returns true
contract MockStatelessValidatorForEmissary is IStatelessValidator {
    function validateSignatureWithData(bytes32, bytes calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }
}

/// @notice Mock stateless validator that always returns false
contract RejectingStatelessValidator is IStatelessValidator {
    function validateSignatureWithData(bytes32, bytes calldata, bytes calldata) external pure override returns (bool) {
        return false;
    }
}

/// @notice Mock stateless validator that always reverts
contract RevertingStatelessValidator is IStatelessValidator {
    function validateSignatureWithData(bytes32, bytes calldata, bytes calldata) external pure override returns (bool) {
        revert("validator reverted");
    }
}

/* //////////////////////////////////////////////////////////////
                        BASE TEST
//////////////////////////////////////////////////////////////*/

contract Emissary_Unit_Test is CompactEnvironment {
    Account internal newSigner;
    Account internal wrongSigner;
    MockStatelessValidatorForEmissary internal mockValidator;
    RejectingStatelessValidator internal rejectingValidator;
    RevertingStatelessValidator internal revertingValidator;

    function setUp() public virtual {
        _deployCompact();
        _deploySmartAccount(true);
        _setEmissary(env.smartAccount1, env.eoa);
        newSigner = makeAccount("newSigner");
        wrongSigner = makeAccount("wrongSigner");
        mockValidator = new MockStatelessValidatorForEmissary();
        rejectingValidator = new RejectingStatelessValidator();
        revertingValidator = new RevertingStatelessValidator();
    }

    /* //////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createConfig(IStatelessValidator validator, uint8 configId, bytes memory validatorConfig)
        internal
        view
        returns (IEmissary.EmissaryConfig memory)
    {
        return IEmissary.EmissaryConfig({
            configId: configId,
            allocator: address(env.allocator),
            scope: env.scope,
            resetPeriod: env.resetPeriod,
            validator: validator,
            validatorConfig: validatorConfig
        });
    }

    function _createEnableData(uint256 nonce, uint256 expires, uint256[] memory chainIds, uint256 chainIndex)
        internal
        pure
        returns (IEmissary.EmissaryEnable memory)
    {
        return IEmissary.EmissaryEnable({
            allocatorSig: "",
            userSig: "",
            expires: expires,
            nonce: nonce,
            allChainIds: chainIds,
            chainIndex: chainIndex
        });
    }

    function _chainIds() internal view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = block.chainid;
        return ids;
    }
}
