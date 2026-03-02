// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Caller, MultiCaller, ISingleCaller } from "../utils/Caller.sol";
import { FeeCollector } from "../utils/FeeCollector.sol";
import { IIndexedEvents } from "@rhinestone/compact-utils/src/interfaces/IEvents.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IdLib } from "the-compact/lib/IdLib.sol";

/**
 * @title IDirectRoute
 * @notice Interface defining fee collection functions for direct routing operations
 * @dev This interface provides standardized fee collection methods that can be called
 *      directly within the router without delegatecall overhead. Designed for gas-optimized
 *      fee processing during fill operations.
 */
interface IDirectRoute {
    /**
     * @notice Collects a single fee directly within the router context
     * @dev This function provides a direct interface for collecting a single fee without
     *      the overhead of delegatecall. Returns a function selector for consistency
     *      with the router's expected return patterns.
     * @param fee The fee structure containing recipient and token/amount pairs
     * @return The function selector of this function for validation purposes
     * @custom:gas Optimized for single fee collection to minimize gas overhead
     */
    function onFill_inRouter_collectFee(FeeCollector.Fee calldata fee) external returns (bytes4);

    /**
     * @notice Collects multiple fees directly within the router context
     * @dev This function provides batch fee collection capability without delegatecall
     *      overhead. Processes an array of fees in a single transaction for efficiency.
     * @param fees Array of fee structures to be processed
     * @return The function selector of this function for validation purposes
     * @custom:gas Optimized for batch fee collection, amortizing fixed costs across multiple fees
     */
    function onFill_inRouter_collectFees(FeeCollector.Fee[] calldata fees) external returns (bytes4);

    /**
     * @notice Sets a single token approval directly within the router context
     * @dev The actual calldata uses packed encoding for gas efficiency:
     *      abi.encodePacked(address token, address spender, uint256 amount, uint64 chainId, uint32 expires)
     *      Layout: [20 bytes token][20 bytes spender][32 bytes amount][8 bytes chainId][4 bytes expires]
     * @param token The token address to approve (for selector identification only)
     * @param spender The address to approve for spending (for selector identification only)
     * @param amount The amount to approve (for selector identification only)
     * @return The function selector of this function for validation purposes
     */
    function onFill_inRouter_setApproval(
        address token,
        address spender,
        uint256 amount,
        uint64 chainId,
        uint32 expires
    )
        external
        returns (bytes4);

    /**
     * @notice Sets multiple token approvals directly within the router context
     * @dev The actual calldata uses a packed prefix followed by ABI-encoded array:
     *      abi.encodePacked(uint64 chainId, uint32 expires) + abi.encode(uint256[3][] tokenAndSpenderAndAmounts)
     *      Layout: [8 bytes chainId][4 bytes expires][abi.encode(array)]
     * @param tokenAndSpenderAndAmounts Array of [token, spender, amount] tuples (for selector identification only)
     * @return The function selector of this function for validation purposes
     */
    function onFill_inRouter_setApprovals(
        uint64 chainId,
        uint32 expires,
        uint256[3][] calldata tokenAndSpenderAndAmounts
    )
        external
        returns (bytes4);
}

/**
 * @title DirectRoutes
 * @notice Abstract contract implementing direct routing functionality for gas optimization
 * @dev DirectRoutes provides a "direct routing" mechanism where operations can be executed
 *      without delegatecall overhead. This is primarily designed for gas optimizations by
 *      avoiding the costs associated with proxy patterns and delegate calls. The contract
 *      supports both claim and fill operations with specialized routing for fee collection.
 * @custom:security All external calls are made through the immutable CALLER contract to maintain security
 * @custom:gas Eliminates delegatecall overhead by using direct calls and inline processing
 */
abstract contract DirectRoutes is FeeCollector {
    using SafeTransferLib for *;
    using IdLib for *;
    /// @notice Thrown when an external call fails
    error CallFailed();

    error InvalidApprovalChainId();
    error InvalidApprovalExpired();
    /**
     * @notice Immutable Caller contract used for executing external calls
     * @dev This contract is deployed once during construction and used for all external
     *      call operations. Being immutable ensures the call target cannot be changed
     *      after deployment, maintaining security guarantees.
     */
    Caller public immutable CALLER;

    /**
     * @notice Initializes the DirectRoutes contract with a new Caller instance
     * @dev Deploys a new Caller contract that will be used for all external call operations.
     *      The Caller contract is immutable to prevent malicious address changes after deployment.
     */
    constructor() {
        CALLER = new Caller();
    }

    /**
     * @notice Processes direct claim routes without delegatecall for gas optimization
     * @dev This function implements direct routing for claim operations, avoiding delegatecall
     *      overhead by making direct calls to the CALLER contract. Supports both single and
     *      multi-call patterns for maximum flexibility.
     * @param selector The function selector identifying the type of call to make
     * @param adapterCalldata The calldata to be forwarded to the appropriate handler
     * @return used Boolean indicating whether the selector was recognized and processed
     */
    function _processDirectClaimRoute(bytes4 selector, bytes calldata adapterCalldata) internal returns (bool used) {
        if (selector == ISingleCaller.singleCall.selector) {
            // singleCall: Direct external call without going through an adapter
            // Used for simple external calls that don't need adapter logic
            // Skip first 4 bytes (selector) when passing to CALLER contract
            (bool success,) = address(CALLER).call(adapterCalldata[4:]);
            require(success, CallFailed());
            return true;
        } else if (selector == MultiCaller.multiCall.selector) {
            // multiCall: Batch multiple external calls in a single transaction
            // Entire calldata including selector is passed to MULTICALL contract
            (bool success,) = address(CALLER).call(adapterCalldata);
            require(success, CallFailed());
            return true;
        }
    }

    /**
     * @notice Processes direct fill routes without delegatecall for gas optimization
     * @dev This function implements direct routing for fill operations, supporting both external
     *      calls via CALLER contract and internal fee collection. Avoids delegatecall overhead
     *      for improved gas efficiency in fill scenarios.
     * @param selector The function selector identifying the type of operation to perform
     * @param adapterCalldata The calldata containing the parameters for the selected operation
     * @return used Boolean indicating whether the selector was recognized and processed
     */
    function _processDirectFillRoute(bytes4 selector, bytes calldata adapterCalldata) internal returns (bool used) {
        if (selector == ISingleCaller.singleCall.selector) {
            // singleCall: Direct external call without going through an adapter
            // Used for simple external calls that don't need adapter logic
            // Skip first 4 bytes (selector) when passing to CALLER contract
            (bool success,) = address(CALLER).call(adapterCalldata[4:]);
            require(success, CallFailed());
            return true;
        } else if (selector == MultiCaller.multiCall.selector) {
            // multiCall: Batch multiple external calls in a single transaction
            // Entire calldata including selector is passed to MULTICALL contract
            (bool success,) = address(CALLER).call(adapterCalldata);
            require(success, CallFailed());
            return true;
        } else if (selector == IDirectRoute.onFill_inRouter_collectFee.selector) {
            // In-router fee collection for a single fee
            // Handles fee distribution without external adapter calls
            // Skip the selector (first 4 bytes) when passing to internal function
            _onFill_inRouter_collectFee(adapterCalldata[4:]);
            return true;
        } else if (selector == IDirectRoute.onFill_inRouter_collectFees.selector) {
            // In-router fee collection for multiple fees
            // Batch processes multiple fee distributions internally
            // Skip the selector (first 4 bytes) when passing to internal function
            _onFill_inRouter_collectFees(adapterCalldata[4:]);
            return true;
        } else if (selector == IDirectRoute.onFill_inRouter_setApproval.selector) {
            _onFill_inRouter_setApproval(adapterCalldata[4:]);
            return true;
        } else if (selector == IDirectRoute.onFill_inRouter_setApprovals.selector) {
            _onFill_inRouter_setApprovals(adapterCalldata[4:]);
            return true;
        }
    }

    /**
     * @notice Checks if a given function selector corresponds to a direct fill route
     * @dev Determines whether a function selector can be processed directly without delegatecall
     *      overhead. Direct fill routes include single/multi calls, fee collection, and approval functions.
     * @param selector The 4-byte function selector to check
     * @return isDirect True if the selector corresponds to a direct fill route, false otherwise
     * @custom:gas Pure function with minimal gas cost for route determination
     */
    function _isDirectFillRoute(bytes4 selector) internal pure returns (bool isDirect) {
        return (selector == ISingleCaller.singleCall.selector || selector == MultiCaller.multiCall.selector
                || selector == IDirectRoute.onFill_inRouter_collectFee.selector
                || selector == IDirectRoute.onFill_inRouter_collectFees.selector
                || selector == IDirectRoute.onFill_inRouter_setApproval.selector
                || selector == IDirectRoute.onFill_inRouter_setApprovals.selector);
    }

    /**
     * @notice Checks if a given function selector corresponds to a direct claim route
     * @dev Determines whether a function selector can be processed directly for claim operations.
     *      Claim routes are limited to single and multi calls, excluding fee collection.
     * @param selector The 4-byte function selector to check
     * @return isDirect True if the selector corresponds to a direct claim route, false otherwise
     * @custom:gas Pure function with minimal gas cost for route determination
     */
    function _isDirectClaimRoute(bytes4 selector) internal pure returns (bool isDirect) {
        return (selector == ISingleCaller.singleCall.selector || selector == MultiCaller.multiCall.selector);
    }

    /**
     * @notice Processes a single fee collection directly within the router
     * @dev This function decodes ABI-encoded calldata containing a Fee struct and processes
     *      the fee collection internally. Uses assembly for efficient calldata parsing to
     *      minimize gas overhead compared to standard ABI decoding.
     * @param data Raw calldata containing the ABI-encoded Fee struct (selector already removed)
     * @custom:gas Uses assembly for direct calldata access, avoiding ABI decoding overhead
     * @custom:security Assembly operations are bounded to prevent buffer overflows
     */
    function _onFill_inRouter_collectFee(bytes calldata data) internal {
        // Decode the ABI-encoded Fee struct parameter manually for gas efficiency
        // ABI encoding layout after selector removal:
        // [0x00-0x20]: offset to the Fee struct parameter (typically 0x20 for single parameter)
        // [0x20-0x40]: recipient address within the Fee struct (20 bytes, right-padded)
        // [0x40-0x60]: offset to tokenAndAmounts array (relative to Fee struct start)
        // [0x60-0x80]: array length (number of token/amount pairs)
        // [0x80+]: array elements (each element is 64 bytes: 32 bytes token + 32 bytes amount)

        address recipient;
        uint256[2][] calldata tokenAndAmounts;

        assembly {
            // Get the starting position of our calldata
            let dataOffset := data.offset

            // Read the offset to the Fee struct parameter from the beginning of data
            // This tells us where the actual Fee struct begins relative to dataOffset
            let feeOffset := calldataload(dataOffset)

            // Calculate the absolute position where the Fee struct starts
            // This is where the recipient address and array offset are stored
            let feeStart := add(dataOffset, feeOffset)

            // Extract the recipient address from the Fee struct (first 20 bytes of first word)
            // Use bitwise AND to mask out the upper 12 bytes, keeping only the address
            recipient := and(calldataload(feeStart), 0xffffffffffffffffffffffffffffffffffffffff)

            // Read the offset to the tokenAndAmounts array (second word of Fee struct)
            // This offset is relative to the start of the Fee struct
            let arrayOffsetFromFeeStart := calldataload(add(feeStart, 0x20))

            // Calculate the absolute position where the array data begins
            let arrayDataStart := add(feeStart, arrayOffsetFromFeeStart)

            // Set up the calldata array reference for tokenAndAmounts
            // The array length is stored at arrayDataStart
            tokenAndAmounts.length := calldataload(arrayDataStart)

            // The actual array elements start after the length field (32 bytes later)
            // Each element is a uint256[2] struct (token address + amount)
            tokenAndAmounts.offset := add(arrayDataStart, 0x20)
        }

        // Call the inherited fee collection function with the decoded parameters
        // This delegates to FeeCollector's implementation for actual token transfers
        _collectFee(recipient, tokenAndAmounts);
    }

    /**
     * @notice Processes multiple fee collections directly within the router
     * @dev This function decodes ABI-encoded calldata containing a Fee[] array and processes
     *      each fee collection internally. Uses assembly for efficient array parsing and
     *      iterates through each fee using the inherited _collectFee function.
     * @param data Raw calldata containing the ABI-encoded Fee[] array (selector already removed)
     * @custom:gas Uses assembly for direct calldata access and caches array length for efficient iteration
     * @custom:security Bounded iteration prevents infinite loops, assembly operations are safe
     */
    function _onFill_inRouter_collectFees(bytes calldata data) internal {
        // Decode the ABI-encoded Fee[] array parameter manually for gas efficiency
        // ABI encoding layout after selector removal:
        // [0x00-0x20]: offset to the Fee[] array parameter (typically 0x20 for single parameter)
        // [0x20-0x40]: array length (number of Fee structs)
        // [0x40+]: array elements (each Fee struct contains recipient + tokenAndAmounts array)

        // Set up a calldata reference to efficiently access the Fee[] array
        Fee[] calldata fees;
        uint256 length;

        assembly {
            // Read the offset to the Fee[] array from the beginning of data
            // This tells us where the actual array data begins relative to data.offset
            let arrayOffset := calldataload(data.offset)

            // Calculate the absolute position where the Fee[] array starts
            let arrayStart := add(data.offset, arrayOffset)

            // Read the array length from the first word of the array data
            // Cache this value in a local variable for gas-efficient loop iteration
            length := calldataload(arrayStart)

            // Set up the calldata array reference for direct access to Fee structs
            // The actual array elements start after the length field (32 bytes later)
            fees.offset := add(arrayStart, 0x20)

            // Set the array length for bounds checking in Solidity
            fees.length := length
        }

        // Process each Fee in the array using the existing single fee collection mechanism
        // This approach reuses the proven _collectFee logic while maintaining gas efficiency
        // through the direct calldata access pattern established above
        for (uint256 i; i < length; i++) {
            // Each fees[i] access uses the calldata reference established in assembly
            // This avoids additional ABI decoding overhead for each individual Fee struct
            _collectFee(fees[i]);
        }
    }

    /**
     * @notice Sets a single token approval directly within the router
     * @dev This function decodes tightly packed calldata containing token, spender, and amount
     *      parameters and sets the approval internally. Uses assembly for efficient calldata
     *      parsing to minimize gas overhead. Packed encoding saves ~64 bytes vs ABI encoding.
     * @param data Raw calldata containing the packed approval parameters (selector already removed)
     *      Expected encoding: abi.encodePacked(address token, address spender, uint256 amount)
     *      Layout: [20 bytes token][20 bytes spender][32 bytes amount] = 72 bytes total
     *      - bytes [0:20]: token address
     *      - bytes [20:40]: spender address
     *      - bytes [40:72]: amount (uint256)
     * @custom:gas Packed encoding saves calldata costs; assembly avoids decoding overhead
     * @custom:security Uses SafeTransferLib.safeApprove to handle non-standard ERC20 implementations
     * @custom:usage Typically called during fill operations to set up approvals needed for swaps or transfers
     */
    function _onFill_inRouter_setApproval(bytes calldata data) internal {
        // Decode the packed parameters: abi.encodePacked(address, address, uint256, uint64, uint32)
        // Total: 20 + 20 + 32 + 8 + 4 = 84 bytes
        address token;
        address spender;
        uint256 amount;
        uint64 chainId;
        uint32 expires;

        assembly ("memory-safe") {
            // Load token address from bytes [0:20]
            // Right-shift by 96 bits (12 bytes) to align address in lower 20 bytes
            token := shr(96, calldataload(data.offset))

            // Load spender address from bytes [20:40]
            // Right-shift by 96 bits to align address in lower 20 bytes
            spender := shr(96, calldataload(add(data.offset, 20)))

            // Load amount from bytes [40:72]
            // Full 32-byte word, no shifting needed
            amount := calldataload(add(data.offset, 40))

            // Load chainId from bytes [72:80]
            // Right-shift by 192 bits (24 bytes) to align uint64 in lower 8 bytes
            chainId := shr(192, calldataload(add(data.offset, 72)))

            // Load expires from bytes [80:84]
            // Right-shift by 224 bits (28 bytes) to align uint32 in lower 4 bytes
            expires := shr(224, calldataload(add(data.offset, 80)))
        }

        require(chainId == block.chainid, InvalidApprovalChainId());
        require(expires >= block.timestamp, InvalidApprovalExpired());

        // Set the approval using SafeTransferLib
        token.safeApproveWithRetry(spender, amount);
    }

    /**
     * @notice Sets multiple token approvals directly within the router in a single transaction
     * @dev This function decodes calldata with a packed prefix followed by ABI-encoded array.
     *      Uses assembly for efficient parsing and iterates through each approval tuple.
     * @param adapterCalldata Raw calldata containing packed prefix + ABI-encoded approval array
     *      Expected encoding: abi.encodePacked(uint64 chainId, uint32 expires) + abi.encode(uint256[3][] array)
     *      Layout: [8 bytes chainId][4 bytes expires][abi.encode(uint256[3][] tokenAndSpenderAndAmounts)]
     *      where each array element is [token_address, spender_address, amount]:
     *      - tokenAndSpenderAndAmounts[i][0]: Token address (as uint256)
     *      - tokenAndSpenderAndAmounts[i][1]: Spender address (as uint256)
     *      - tokenAndSpenderAndAmounts[i][2]: Approval amount
     * @custom:gas Uses assembly for direct calldata access and caches array length for efficient iteration
     * @custom:security Uses SafeTransferLib.safeApprove to handle non-standard ERC20 implementations
     * @custom:usage Ideal for setting up multiple approvals in a single call, amortizing fixed costs
     * @custom:batch Processing stops on first failure, reverting the entire transaction atomically
     */
    function _onFill_inRouter_setApprovals(bytes calldata adapterCalldata) internal {
        uint256 length;
        uint64 chainId;
        uint32 expires;
        uint256[3][] calldata tokenAndSpenderAndAmounts;

        assembly ("memory-safe") {
            // Extract chainId from bytes [0:8] - packed uint64
            // Right-shift by 192 bits (24 bytes) to align uint64 in lower 8 bytes
            chainId := shr(192, calldataload(adapterCalldata.offset))

            // Extract expires from bytes [8:12] - packed uint32
            // Right-shift by 224 bits (28 bytes) to align uint32 in lower 4 bytes
            expires := shr(224, calldataload(add(adapterCalldata.offset, 8)))

            // ABI-encoded array starts after the 12-byte packed prefix
            let abiEncodedStart := add(adapterCalldata.offset, 12)
            let o := add(abiEncodedStart, calldataload(abiEncodedStart))
            tokenAndSpenderAndAmounts.offset := add(o, 0x20)
            length := calldataload(o)
            tokenAndSpenderAndAmounts.length := length
        }

        require(chainId == block.chainid, InvalidApprovalChainId());
        require(expires >= block.timestamp, InvalidApprovalExpired());
        for (uint256 i; i < length; i++) {
            tokenAndSpenderAndAmounts[i][0].toAddress()
                .safeApproveWithRetry(tokenAndSpenderAndAmounts[i][1].toAddress(), tokenAndSpenderAndAmounts[i][2]);
        }
    }
}
