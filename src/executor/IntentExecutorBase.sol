// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Scope } from "the-compact/types/Scope.sol";
import { ResetPeriod } from "the-compact/types/ResetPeriod.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";

/**
 * @title IntentExecutorBase
 * @notice Base contract for intent executors with router access control
 * @dev Provides core functionality for intent execution including router-only access control
 */
abstract contract IntentExecutorBase {
    using IdLib for address;
    using IdLib for uint96;
    /* //////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a function is called by an unauthorized account
    error OnlyRouter();

    /* //////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The router contract address authorized to call restricted functions
    address internal immutable ROUTER;

    /// @dev The tag used for resource locking during execution
    bytes12 public immutable LOCKTAG;

    /* //////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the intent executor base with router and lock tag
     * @param router The address of the authorized router contract
     */
    constructor(address router, address allocator) {
        ROUTER = router;
        LOCKTAG = allocator.toAllocatorId().toLockTag(Scope.Multichain, ResetPeriod.SevenDaysAndOneHour);
    }

    /* //////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to the designated router contract only
     * @dev Prevents unauthorized cross-chain execution attempts by enforcing that only
     *      the router can trigger intent execution functions
     */
    modifier onlyRouter() {
        require(msg.sender == ROUTER, OnlyRouter());
        _;
    }
}
