// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockTheCompact {
    uint96 private _nextAllocatorId = 1;
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 internal constant _COMPACT_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev `keccak256(bytes("The Compact"))`.
    bytes32 internal constant _NAME_HASH = 0x5e6f7b4e1ac3d625bac418bc955510b3e054cb6cc23cc27885107f080180b292;

    /// @dev `keccak256("1")`.
    bytes32 internal constant _VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(_COMPACT_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this)));
    }

    function __registerAllocator(address, bytes calldata) external returns (uint96) {
        return _nextAllocatorId++;
    }

    mapping(uint256 => bool) public consumedNonces;

    function consume(uint256[] calldata nonces) external returns (bool) {
        for (uint256 i; i < nonces.length; i++) {
            consumedNonces[nonces[i]] = true;
        }
        return true;
    }
}
