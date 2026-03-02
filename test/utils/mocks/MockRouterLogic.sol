// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RouterLogic } from "src/router/core/RouterLogic.sol";

/**
 * @title MockRouterLogic
 * @notice Mock contract that exposes internal RouterLogic functions for testing
 */
contract MockRouterLogic is RouterLogic {
    constructor(address atomicFillSigner, address adder, address remover) RouterLogic(atomicFillSigner, adder, remover) { }

    /**
     * @notice Exposed version of _isAtomic for direct testing
     */
    function exposed_isAtomic(bytes32 hash, bytes calldata atomicSig) external returns (bool) {
        return _isAtomic(hash, atomicSig);
    }

    /**
     * @notice Exposed version of _processDirectFillRoute for testing
     */
    function exposed_processDirectFillRoute(bytes4 selector, bytes calldata adapterCalldata) external returns (bool) {
        return _processDirectFillRoute(selector, adapterCalldata);
    }

    /**
     * @notice Exposed version of _processDirectClaimRoute for testing
     */
    function exposed_processDirectClaimRoute(bytes4 selector, bytes calldata adapterCalldata) external returns (bool) {
        return _processDirectClaimRoute(selector, adapterCalldata);
    }

    /**
     * @notice Exposed version of _isDirectFillRoute for testing
     */
    function exposed_isDirectFillRoute(bytes4 selector) external pure returns (bool) {
        return _isDirectFillRoute(selector);
    }

    /**
     * @notice Exposed version of _isDirectClaimRoute for testing
     */
    function exposed_isDirectClaimRoute(bytes4 selector) external pure returns (bool) {
        return _isDirectClaimRoute(selector);
    }

    /**
     * @notice Exposed version of _onFill_inRouter_collectFee for testing
     */
    function exposed_onFill_inRouter_collectFee(bytes calldata data) external {
        _onFill_inRouter_collectFee(data);
    }

    /**
     * @notice Exposed version of _onFill_inRouter_collectFees for testing
     */
    function exposed_onFill_inRouter_collectFees(bytes calldata data) external {
        _onFill_inRouter_collectFees(data);
    }

    /**
     * @notice Exposed version of _onFill_inRouter_setApproval for testing
     */
    function exposed_onFill_inRouter_setApproval(bytes calldata data) external {
        _onFill_inRouter_setApproval(data);
    }

    /**
     * @notice Exposed version of _onFill_inRouter_setApprovals for testing
     */
    function exposed_onFill_inRouter_setApprovals(bytes calldata data) external {
        _onFill_inRouter_setApprovals(data);
    }
}
