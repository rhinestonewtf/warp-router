// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { AddressBookLib } from "../common/AddressBook/lib/AddressBookLib.sol";
import { Vm } from "forge-std/Vm.sol";
import { AddressBook } from "../common/AddressBook/AddressBook.sol";

bytes32 constant SALT = keccak256("default_salt");

contract Create2Factory {
    event Deploying(string name, address predictedAddress);

    function deploy(bytes memory bytecode) public payable returns (address) {
        return deploy(SALT, bytecode, "");
    }

    function deploy(bytes32 salt, bytes memory bytecode) public payable returns (address) {
        return deploy(salt, bytecode, "");
    }

    function deploy(bytes memory bytecode, bytes memory constructorArg) public payable returns (address) {
        return deploy(SALT, bytecode, constructorArg);
    }

    function deploy(bytes32 salt, bytes memory bytecode, bytes memory constructorArg) public payable returns (address) {
        bytecode = abi.encodePacked(bytecode, constructorArg);
        address addr;
        assembly ("memory-safe") {
            addr := create2(callvalue(), add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
        return addr;
    }

    function predictDeploymentAddress(bytes32 salt, bytes memory bytecode, bytes memory constructorArg) internal view returns (address) {
        bytecode = abi.encodePacked(bytecode, constructorArg);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function predictDeploymentAddress(bytes32 salt, bytes memory bytecode) internal view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function create2(bytes32 salt, string memory name, bytes memory bytecode) public returns (address) {
        address _predictedAddress = predictDeploymentAddress(salt, bytecode);
        emit Deploying(name, _predictedAddress);
        return deploy(salt, bytecode, "");
    }

    function create2(bytes32 salt, string memory name, bytes memory bytecode, bytes memory args) public returns (address) {
        address _predictedAddress = predictDeploymentAddress(salt, bytecode, args);
        emit Deploying(name, _predictedAddress);
        return deploy(salt, bytecode, args);
    }

    function predictCreate2(bytes32 salt, bytes memory bytecode) public view returns (address) {
        return predictDeploymentAddress(salt, bytecode);
    }

    function predictCreate2(bytes32 salt, bytes memory bytecode, bytes memory args) public view returns (address) {
        return predictDeploymentAddress(salt, bytecode, args);
    }
}

contract AddressBookHelper is Create2Factory {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct InitCode {
        bytes bytecode;
        bytes args;
    }

    struct Deployment {
        string name;
        AddressBookLib.ID id;
        address predictedAddress;
        InitCode code;
    }

    mapping(bytes32 nameHash => Deployment) $deploymentMap;
    AddressBook ADDRESSBOOK = new AddressBook(address(this));

    function _getAddress(string memory name) internal view returns (address) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        Deployment storage deployment = $deploymentMap[nameHash];
        require(deployment.predictedAddress != address(0), "Deployment not found");
        return deployment.predictedAddress;
    }

    function _addDeployment(string memory name, AddressBookLib.ID id, bytes memory bytecode, bytes memory args) internal returns (address) {
        Deployment memory deployment =
            Deployment({ name: name, id: id, predictedAddress: address(0), code: InitCode({ bytecode: bytecode, args: args }) });
        $deploymentMap[keccak256(abi.encodePacked(name))] = deployment;
        return _registerAddress($deploymentMap[keccak256(abi.encodePacked(name))]);
    }

    function _addDeployment(string memory name, AddressBookLib.ID id, bytes memory bytecode) internal returns (address) {
        Deployment memory deployment =
            Deployment({ name: name, id: id, predictedAddress: address(0), code: InitCode({ bytecode: bytecode, args: "" }) });

        $deploymentMap[keccak256(abi.encodePacked(name))] = deployment;
        return _registerAddress($deploymentMap[keccak256(abi.encodePacked(name))]);
    }

    function _deploymentId(string memory name) internal view returns (bytes32) {
        return AddressBookLib.ID.unwrap($deploymentMap[keccak256(abi.encodePacked(name))].id);
    }

    function _registerAddress(Deployment storage deployment) internal returns (address) {
        address addr = predictCreate2(keccak256(abi.encodePacked(deployment.name)), deployment.code.bytecode, deployment.code.args);
        deployment.predictedAddress = addr;
        vm.label(addr, string(abi.encodePacked(deployment.name)));
        ADDRESSBOOK.setAddress(deployment.id, deployment.predictedAddress);
        return addr;
    }

    function _deploy(string memory name) internal returns (address) {
        return _deploy($deploymentMap[keccak256(abi.encodePacked(name))]);
    }

    function _deploy(Deployment storage deployment) internal returns (address addr) {
        addr = create2(
            keccak256(abi.encodePacked(deployment.name)),
            string(abi.encodePacked(deployment.name)),
            deployment.code.bytecode,
            deployment.code.args
        );
        require(addr == deployment.predictedAddress, "Deployment failed, address mismatch");
    }
}
