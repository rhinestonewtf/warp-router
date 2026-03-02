// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { Emissary } from "@rhinestone/compact-utils/src/emissary/Emissary.sol";
import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";
import { EIP712Hash } from "@rhinestone/compact-utils/src/emissary/lib/EmissaryEIP712Lib.sol";
import { Compressed } from "@rhinestone/compact-utils/src/emissary/lib/CompressedStorageLib.sol";
import { EmissaryStorageLib } from "@rhinestone/compact-utils/src/emissary/lib/EmissaryStorageLib.sol";
import { WebAuthnCredential } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";

import { ISmartSessionEmissary } from "@rhinestone/compact-utils/src/interfaces/ISmartSessionEmissary.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

contract DebugEmissary is Emissary, ISmartSessionEmissary {
    using Compressed for Compressed.Bytes;
    using EmissaryStorageLib for address;
    using EmissaryStorageLib for bytes32;

    bool passOverrite;

    constructor(address compact) { }

    function mock_setConfig(address sponsor, uint8 id, bytes12 lockTag, IStatelessValidator validator, bytes calldata data) external {
        bytes32 slot = sponsor.configSlot(id, lockTag, address(validator));
        Compressed.Bytes storage $config = slot.loadCompressedBytes();
        $config.sstore(data); // Store the validator configuration data
    }

    function _config(address sponsor, uint8 id, bytes12 lockTag, IStatelessValidator validator) external view returns (bytes memory) {
        bytes32 slot = sponsor.configSlot(id, lockTag, address(validator));
        Compressed.Bytes storage $config = slot.loadCompressedBytes();
        return $config.sload();
    }

    /// @notice Helper to setup passkey config for testing
    function setupPasskeyConfig(
        address account,
        bytes12 lockTag,
        uint256 pubKeyX,
        uint256 pubKeyY,
        bool requireUV,
        bool usePrecompile
    )
        external
    {
        bytes32 slot = account.configSlot(2, lockTag, address(0x1001)); // PASSKEY_VALIDATOR
        WebAuthnCredential storage creds = slot.loadPasskeyCredentials();
        creds.pubKeyX = pubKeyX;
        creds.pubKeyY = pubKeyY;
        creds.requireUV = requireUV;
        creds.usePrecompile = usePrecompile;
    }

    function getHash(
        address account,
        bytes12 lockTag,
        uint256 expires,
        EmissaryConfig calldata config,
        EmissaryEnable calldata enableData
    )
        external
        view
        returns (bytes32)
    {
        bytes32 hash = EIP712Hash.config({
            sponsor: account,
            validator: config.validator,
            configId: config.configId,
            lockTag: lockTag,
            expires: expires,
            nonce: enableData.nonce,
            validatorConfig: config.validatorConfig,
            chainIds: enableData.allChainIds
        });
        return _hashTypedDataSansChainId(hash);
    }

    function verifyClaim(
        address sponsor,
        bytes32 digest,
        bytes32 claimHash,
        bytes calldata emissaryData,
        bytes12 lockTag
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        if (passOverrite) {
            return this.verifyClaim.selector;
        }

        return _validateSignature(sponsor, digest, emissaryData, lockTag) ? this.verifyClaim.selector : INVALID_SIGNATURE;
    }

    function overwrite(bool ovr) external {
        passOverrite = ovr;
    }

    function verifyExecution(address account, bytes32 digest, bytes calldata data, Types.Operation calldata ops) external returns (bytes4) {
        if (passOverrite) {
            return this.verifyExecution.selector;
        } else {
            return bytes4(0xFFFFFFFF);
        }
    }
}
