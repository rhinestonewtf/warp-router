// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// Contracts
import { AdapterBase, SemVer } from "@rhinestone/compact-utils/src/base/adapter/AdapterBase.sol";
import { Caller } from "@rhinestone/compact-utils/src/router/utils/Caller.sol";

// Interfaces
import { IAdapter } from "@rhinestone/compact-utils/src/interfaces/IAdapter.sol";

// Types
import { Constants } from "@rhinestone/compact-utils/src/types/Constants.sol";

// Libraries
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";

/**
 * @title SingleCallAdapter
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice Adapter for executing a single arbitrary call through the Warp Routerr
 * @dev This adapter enables solvers to execute a single call on behalf of users.
 *      It emits a nonce for tracking fill operations.
 */
contract SingleCallAdapter is AdapterBase, Caller {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using AdapterTagLib for bytes12;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the single call execution fails
    error SingleCallFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the SingleCallAdapter with router address
     * @param router Address of the Warp Routerr contract
     */
    constructor(address router) AdapterBase(router, address(0)) SemVer(0, 0) { }

    /*//////////////////////////////////////////////////////////////
                                  FILL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a single call fill operation
     * @dev Router-only function that forwards the call to the arbiter's singleCall (fallback)
     *      Uses assembly for gas-efficient calldata forwarding without re-encoding
     * @param nonce Unique identifier for tracking this fill operation
     * @param sponsor The account address associated with this fill, emitted in the RouterFilled event for tracking
     * @param packedData Packed calldata in format [target(20 bytes)][callData(...)]
     * @return Function selector for verification
     * @custom:fill-adapter
     */
    function singleCall_handleFill(uint256 nonce, address sponsor, bytes calldata packedData) external onlyViaRouter returns (bytes4) {
        // Initialize arbiter and target variables
        address arbiter = ARBITER;

        // Forward call to arbiter's fallback
        assembly ("memory-safe") {
            // Get free memory pointer
            let ptr := mload(0x40)

            // Copy packedData to memory
            calldatacopy(ptr, packedData.offset, packedData.length)

            // Forward to arbiter's fallback
            let success := call(gas(), arbiter, 0x00, ptr, packedData.length, 0x00, 0x00)

            // Revert if the call failed
            if iszero(success) {
                mstore(0x00, 0x91958168) // SingleCallFailed()
                revert(0x1c, 0x04)
            }
        }

        // Emit event and return selector
        emit RouterFilled(sponsor, nonce);
        return this.singleCall_handleFill.selector;
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if adapter supports a given function selector
     * @dev Used for interface detection and compatibility checks
     * @param selector Function selector to check
     * @return True if the selector is supported by this adapter
     */
    function supportsInterface(bytes4 selector) public pure override(AdapterBase, Caller) returns (bool) {
        return selector == this.singleCall_handleFill.selector || AdapterBase.supportsInterface(selector)
            || Caller.supportsInterface(selector) || selector == type(IAdapter).interfaceId;
    }

    /**
     * @notice Returns the adapter tag that defines how relayer context data should be handled
     * @dev This adapter does not consume relayer context, so it sets the skipRelayerContext flag.
     *      The adapter tag is used by the router to determine whether to include relayer-specific
     *      data when routing calls to this adapter. For SingleCallAdapter, all required
     *      information (the target address and calldata) is already provided in the packedData
     *      argument to singleCall_handleFill, so additional relayer context from the router is
     *      not required.
     * @return bytes12 The adapter tag with skipRelayerContext flag set, indicating this adapter
     *         does not need relayer context data from the router
     */
    function ADAPTER_TAG() external pure override returns (bytes12) {
        return Constants.DEFAULT_ADAPTER_TAG.setSkipRelayerContext();
    }
}
