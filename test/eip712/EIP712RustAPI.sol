pragma solidity ^0.8.28;

import "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";

contract EIP712RustAPI is StdCheats {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function rustTypehash(string memory name) public returns (bytes32 typehash) {
        string[] memory cmds = new string[](7);
        cmds[0] = "cargo";
        cmds[1] = "run";
        cmds[2] = "--";
        cmds[3] = "--mode";
        cmds[4] = "type-hash";
        cmds[5] = "--typehash";
        cmds[6] = name;

        bytes memory result = vm.ffi(cmds);
        typehash = abi.decode(result, (bytes32));
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

    function rustDataHash(string memory name, bytes memory data) internal returns (bytes32 hash) {
        string[] memory cmds = new string[](8);
        cmds[0] = "cargo";
        cmds[1] = "run";
        cmds[2] = "--";
        cmds[3] = "--mode";
        cmds[4] = "hash";
        cmds[5] = "--typehash";
        cmds[6] = name;
        cmds[7] = iToHex(data);

        bytes memory result = vm.ffi(cmds);
        hash = abi.decode(result, (bytes32));
    }
}
