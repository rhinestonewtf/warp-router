// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAdapter } from "@rhinestone/compact-utils/src/interfaces/IAdapter.sol";

interface IRouterManager is IAccessControl {
    struct TokenAndAmount {
        address token;
        uint256 amount;
    }
    error AdapterAlreadyInstalled();
    error AdapterNotInstalled();
    error OnlyPatchAllowed();
    error InvalidAdapter();
    error InvalidArbiter();
    error Unauthorized();
    error AdapterMajorVersionMismatch();
    error SettingApprovalsNotSupported(IAdapter adapter);

    event FillAdapter(bytes2 protocolVersion, address adapter, bytes4 selector, bytes12 adapterTag);
    event ClaimAdapter(bytes2 protocolVersion, address adapter, bytes4 selector, bytes12 adapterTag);
    event FillAdapterRetired(bytes2 protocolVersion, bytes4 selector, address adapter);
    event ClaimAdapterRetired(bytes2 protocolVersion, bytes4 selector, address adapter);

    event SetApproval(address spender, address token);

    event FillSignerSet(address signer);

    function initialized() external view returns (bool);

    function $atomicFillSigner() external view returns (address);

    function initialize(address atomicSigner, address addAdmin, address rmAdmin) external;

    function pauseRouter() external;

    function installFillAdapter(bytes2 version, bytes4 selector, address adapter) external;

    function hotfixFillAdapter(bytes2 version, bytes4 selector, address adapter) external;

    function installClaimAdapter(bytes2 version, bytes4 selector, address adapter) external;

    function hotfixClaimAdapter(bytes2 version, bytes4 selector, address adapter) external;

    function getFillAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);

    function getClaimAdapter(bytes2 version, bytes4 selector) external view returns (address adapter, bytes12 adapterTag);

    function retireFillAdapter(bytes2 version, bytes4 selector) external;

    function retireClaimAdapter(bytes2 version, bytes4 selector) external;
}
