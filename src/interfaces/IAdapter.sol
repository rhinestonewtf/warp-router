// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IAdapter is IERC165 {
    function ARBITER() external view returns (address);
    function settlementLayerSpender() external view returns (address);
    function ADAPTER_TAG() external view returns (bytes12);
}
