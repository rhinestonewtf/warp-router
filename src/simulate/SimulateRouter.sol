// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { RouterLogic, RouterManagerV1 } from "../router/core/RouterLogic.sol";
import { AdapterLib } from "@rhinestone/compact-utils/src/router/lib/AdapterLib.sol";
import { RouterManagerStorageLib, AdapterConfig } from "../router/lib/RouterStorageLib.sol";
import { Version } from "@rhinestone/compact-utils/src/Version.sol";

/**
 * @title SimulateRouter
 * @author Rhinestone (zeroknots.eth, highskore.eth)
 * @notice A specialized router for simulating and measuring the gas costs of various routing operations.
 *         This contract inherits the core logic from `RouterLogic` but wraps key functions
 *         in a `withGasMeasurement` modifier. Instead of completing the state change, it reverts
 *         with a `GasUsed` error, reporting the amount of gas consumed. This is invaluable for
 *         off-chain systems to estimate transaction costs accurately.
 */
contract SimulateRouter layout at 88_967_819_156_726_863_884_428_300_865_593_401_225_272_190_543_010_065_736_923_496_773_938_567_778_360
    is
    RouterLogic
{
    using AdapterLib for address;
    using RouterManagerStorageLib for bytes4;
    using RouterManagerStorageLib for AdapterConfig;

    using RouterManagerV1 for bytes4;
    using RouterManagerStorageLib for AdapterConfig;
    using AdapterLib for address;
    /**
     * @notice Initializes the SimulateRouter.
     * @param atomicFillSigner The address authorized to sign for atomic fills.
     * @param adder The address granted the role to add routes.
     * @param remover The address granted the role to remove routes.
     */

    constructor(address atomicFillSigner, address adder, address remover) RouterLogic(atomicFillSigner, adder, remover) { }

    /**
     * @notice Custom error to report the gas used by a simulated transaction.
     * @dev This error is intentionally reverted by the `withGasMeasurement` modifier to return
     *      the gas cost without making a state change.
     * @param success Always true, indicating the simulation itself was successful.
     * @param gasUsed The amount of gas consumed by the wrapped operation.
     */
    error GasUsed(bool success, uint256 gasUsed);

    /**
     * @notice A modifier that measures the gas consumed by the function it wraps.
     * @dev It records `gasleft()` before and after the function execution (`_`),
     *      calculates the difference, and then reverts with the `GasUsed` error to
     *      report the cost.
     */
    modifier withGasMeasurement() {
        // Record the amount of gas remaining before the operation.
        uint256 gasBefore = gasleft();
        _;
        // Calculate the gas consumed by subtracting the remaining gas from the initial amount.
        uint256 gasUsed = gasBefore - gasleft();
        // Revert with the gas usage information. This prevents state changes
        // and provides the simulation result to the caller.
        revert GasUsed(true, gasUsed);
    }

    /**
     * @notice Override of _isAtomic that bypasses signature validation for gas simulation purposes
     * @dev This override is specifically designed for the simulation environment where we need to
     *      measure gas costs without requiring valid atomic signatures. The function still calls
     *      the parent implementation to ensure any side effects or gas costs from the original
     *      validation logic are included in the simulation, but then unconditionally returns true.
     *
     *      This design allows for accurate gas measurement of the complete routing flow while
     *      removing the signature validation requirement that would otherwise prevent simulation
     *      without access to the atomic signer's private key.
     *
     *      **Why this override is safe for simulation**:
     *      - SimulateRouter is used exclusively for gas estimation via the withGasMeasurement modifier
     *      - All simulation functions revert with GasUsed error, preventing state changes
     *      - No actual asset transfers or protocol state modifications occur during simulation
     *      - The parent call ensures gas costs of signature verification are still measured
     *
     * @param hash The keccak256 hash of the encoded adapter calldatas. While not used for validation
     *             in this override, it's still passed to the parent function for gas measurement accuracy.
     * @param atomicSig The ECDSA signature bytes. Not validated in simulation, but passed to parent
     *                  to ensure the complete gas cost profile is captured.
     * @return atomic Always returns true to allow simulation to proceed without signature validation.
     *                This enables gas measurement of routing operations without requiring valid signatures.
     *
     * @custom:security This override is safe because:
     *                  - Only used in simulation context where all operations revert via withGasMeasurement
     *                  - No state changes are persisted due to the GasUsed revert pattern
     *                  - Cannot be used to bypass security in production Router contracts
     *                  - Parent call preserves gas measurement accuracy for the validation logic
     *
     * @custom:gas The parent call ensures simulation includes:
     *            - Storage read costs for $atomicFillSigner
     *            - ECDSA signature recovery computation costs
     *            - All other gas overhead from the original validation logic
     *            This provides accurate gas estimates for production routing calls.
     */
    function _isAtomic(bytes32 hash, bytes calldata atomicSig) internal override returns (bool atomic) {
        super._isAtomic(hash, atomicSig);
        return true;
    }

    /**
     * @notice Simulates the gas cost of a `routeFill` operation.
     * @dev This function wraps the `routeFill` logic with the `withGasMeasurement` modifier
     *      to report the gas cost via a revert.
     * @param relayerContexts An array of solver-specific contexts for each adapter call.
     * @param encodedAdapterCalldatas An abi encoded array of calldata for each adapter call.
     * @param sig The atomic fill signature authorizing the batch of operations.
     */
    function simulate_routeFill(
        bytes[] calldata relayerContexts,
        bytes calldata encodedAdapterCalldatas,
        bytes calldata sig
    )
        external
        virtual
        withGasMeasurement
    {
        // The actual `routeFill` logic is executed, but the `withGasMeasurement`
        // modifier will prevent state changes and report the gas usage.
        super.optimized_routeFill921336808(relayerContexts, encodedAdapterCalldatas, sig);
    }

    /**
     * @notice Simulates the gas cost of a `routeClaim` operation.
     * @dev This function wraps the `routeClaim` logic with the `withGasMeasurement` modifier
     *      to report the gas cost via a revert.
     * @param relayerContext The solver-specific context for the claim.
     * @param adapterCalldata The calldata for the claim adapter.
     */
    function simulate_routeClaim(bytes calldata relayerContext, bytes calldata adapterCalldata) external withGasMeasurement {
        // Get the appropriate claim adapter for the given calldata.
        bytes4 selector = bytes4(adapterCalldata[:4]);
        address adapter = selector.withClaimAdapter(Version.PROTOCOL_V1).adapterAddress();
        // Perform the delegatecall to the adapter. The `withGasMeasurement` modifier
        // will measure the gas and revert with the result.
        adapter.callAdapterWithRelayerContext(relayerContext, adapterCalldata);
    }

    // /**
    // * @notice Retrieves the adapter addresses that would be used for a batch of fill operations.
    // * @dev This view function allows callers to determine which adapters will be used for execution
    // * without actually executing the operations. Useful for:
    //*
    // * **SIMULATION AND VALIDATION:**
    // * - Pre-flight checks to ensure all required adapters are properly configured
    // * - Gas estimation by determining which adapters will be called
    // * - Frontend integration to display execution paths to users
    // * - Solver validation to ensure operations can be executed successfully
    //*
    // * **ADAPTER RESOLUTION LOGIC:**
    // * Uses the same resolution logic as the actual fill execution:
    // * 1. **Special Selectors**: Built-in operations return address(this) as they're handled directly
    // * 2. **Regular Selectors**: Mapped to their corresponding fill adapter addresses via storage lookup
    // * 3. **Assembly Decoding**: Uses the same optimized calldata decoding as execution functions
    //*
    // * **CONSISTENCY GUARANTEE:**
    // * The returned addresses exactly match what would be used during actual execution,
    // * ensuring simulation accuracy and preventing execution surprises.
    //*
    // * @param encodedAdapterCalldatas ABI-encoded bytes containing the array of adapter calldatas.
    // * Must be encoded as: abi.encode(bytes[] adapterCalldatas)
    // * Same format as used by optimized_routeFill921336808.
    //*
    // * @return adapters Array of adapter addresses in the same order as the input calldatas.
    // * Special selectors return address(this), regular selectors return their
    // * mapped adapter addresses from storage.
    //*
    // * @custom:view Read-only function safe for external integration and simulation
    // * @custom:gas Uses same assembly decoding as execution for consistent gas estimation
    // * @custom:simulation Provides exact adapter resolution used during actual execution
    //*/
    // function predictFillAdapters(bytes calldata encodedAdapterCalldatas)
    // external
    // view
    // returns (address[] memory adapters, bytes[] memory mockrelayerContexts)
    //{
    // bytes[] calldata adapterCalldatas;
    // uint256 length;
    // assembly ("memory-safe") {
    // // The encoded data structure for abi.encode(bytes[]) is:
    // // [0x00] offset to array start (always 0x20 for single dynamic type)
    // // [0x20] array length
    // // [0x40] offset to first element
    // // [0x60] offset to second element...
    // // [actual data follows after all offsets]
    //
    // // Read the offset to the array data (skip the ABI encoding wrapper)
    // let o := add(encodedAdapterCalldatas.offset, calldataload(encodedAdapterCalldatas.offset))
    // // Point to array elements (skip the length field at o)
    // adapterCalldatas.offset := add(o, 0x20)
    // // Read the array length from position o
    // length := calldataload(o)
    // adapterCalldatas.length := length
    //}
    // adapters = new address[](length);
    // mockrelayerContexts = new bytes[](length);
    //
    // uint256 solverCnt;
    //
    // for (uint256 i; i < length; i++) {
    // bytes4 selector = bytes4(adapterCalldatas[i][:4]);
    // if (_isDirectFillRoute(selector)) {
    // adapters[i] = address(this);
    // } else {
    // IAdapter adapter = IAdapter(selector.withFillAdapter().adapterAddress());
    // mockrelayerContexts[solverCnt] = adapter.mockrelayerContext();
    // adapters[i] = address(adapter);
    // solverCnt++;
    //}
    //}
    // assembly ("memory-safe") { }
    //}
    //
    // function checkFillAdapters(
    // bytes calldata encodedAdapterCalldatas,
    // bytes[] calldata relayerContexts
    //)
    // external
    // view
    // returns (address[] memory adapters)
    //{
    // bytes[] calldata adapterCalldatas;
    // uint256 length;
    // assembly ("memory-safe") {
    // // The encoded data structure for abi.encode(bytes[]) is:
    // // [0x00] offset to array start (always 0x20 for single dynamic type)
    // // [0x20] array length
    // // [0x40] offset to first element
    // // [0x60] offset to second element...
    // // [actual data follows after all offsets]
    //
    // // Read the offset to the array data (skip the ABI encoding wrapper)
    // let o := add(encodedAdapterCalldatas.offset, calldataload(encodedAdapterCalldatas.offset))
    // // Point to array elements (skip the length field at o)
    // adapterCalldatas.offset := add(o, 0x20)
    // // Read the array length from position o
    // length := calldataload(o)
    // adapterCalldatas.length := length
    //}
    // adapters = new address[](length);
    //
    // uint256 solverCnt;
    // for (uint256 i; i < length; i++) {
    // bytes4 selector = bytes4(adapterCalldatas[i][:4]);
    // if (_isDirectFillRoute(selector)) {
    // adapters[i] = address(this);
    // } else {
    // IAdapter adapter = IAdapter(selector.withFillAdapter().adapterAddress());
    // require(adapter.isValidrelayerContext(relayerContexts[solverCnt]), IAdapter.InvalidrelayerContext());
    // ++solverCnt;
    //}
    //}
    // require(solverCnt == relayerContexts.length, IAdapter.InvalidrelayerContext());
    //}
    //
    // /**
    // * @notice Retrieves the adapter addresses that would be used for a batch of claim operations.
    // * @dev This view function provides adapter resolution for claim operations, enabling simulation
    // * and validation without execution. Serves similar purposes to getFillAdapters but for
    // * claim-specific operations:
    //*
    // * **CLAIM OPERATION SIMULATION:**
    // * - Validate that all claim adapters are properly configured before execution
    // * - Enable gas estimation for claim batches by identifying target adapters
    // * - Support frontend displays showing users which protocols will be accessed
    // * - Allow solvers to verify claim operations can complete successfully
    //*
    // * **ADAPTER RESOLUTION FOR CLAIMS:**
    // * Mirrors the claim execution logic for adapter resolution:
    // * 1. **Special Selectors**: Built-in claim operations return address(this) for direct handling
    // * 2. **Protocol Adapters**: Regular selectors map to claim-specific adapter addresses
    // * 3. **Direct Array Processing**: Simpler than fill version as it processes unencoded arrays
    //*
    // * **CLAIM vs FILL DIFFERENCES:**
    // * - Accepts standard bytes[] array (not encoded) unlike getFillAdapters
    // * - Maps to claim adapters rather than fill adapters via withClaimAdapter()
    // * - Used for resource unlocking operations rather than settlement fulfillment
    //*
    // * **CONSISTENCY ASSURANCE:**
    // * Returns the exact same adapter addresses that would be used during actual claim execution,
    // * maintaining perfect simulation-to-execution consistency for reliable pre-flight validation.
    //*
    // * @param adapterCalldatas Array of calldata for claim operations, each prefixed with a 4-byte
    // * selector identifying the target claim adapter or special operation.
    // * Standard array format (not ABI-encoded like fill operations).
    //*
    // * @return adapters Array of adapter addresses corresponding to each input calldata.
    // * Special selectors return address(this), protocol selectors return their
    // * registered claim adapter addresses from the adapter registry.
    //*
    // * @custom:view Read-only function safe for simulation and external integration
    // * @custom:claims Specifically designed for claim operation adapter resolution
    // * @custom:simulation Ensures perfect consistency with actual claim execution paths
    //*/
    // function predictClaimAdapters(bytes[] calldata adapterCalldatas) external view returns (address[] memory adapters) {
    // uint256 length = adapterCalldatas.length;
    // for (uint256 i; i < length; i++) {
    // bytes4 selector = bytes4(adapterCalldatas[i][:4]);
    // adapters[i] = _isDirectClaimRoute(selector) ? address(this) : selector.withClaimAdapter().adapterAddress();
    //}
    //}
}
