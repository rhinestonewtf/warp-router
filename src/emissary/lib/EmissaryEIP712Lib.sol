// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IStatelessValidator } from "@rhinestone/compact-utils/src/interfaces/IStatelessValidator.sol";

library TYPEHASH {
    bytes32 internal constant CONFIG = keccak256(
        // solhint-disable-next-line max-line-length
        "SetConfig(address sponsor,address validator,uint8 configId,bytes12 lockTag,uint256 expires,bytes config,uint256 nonce,uint256[] chainIds)"
    );
}

library EIP712Hash {
    error InvalidSignature();

    function config(
        address sponsor,
        IStatelessValidator validator,
        uint8 configId,
        uint256 expires,
        bytes12 lockTag,
        uint256 nonce,
        bytes calldata validatorConfig,
        uint256[] calldata chainIds
    )
        internal
        pure
        returns (bytes32 hash)
    {
        hash = keccak256(
            abi.encode(
                TYPEHASH.CONFIG,
                sponsor,
                validator,
                configId,
                lockTag,
                expires,
                keccak256(validatorConfig),
                nonce,
                keccak256(abi.encodePacked(chainIds))
            )
        );
    }
}
