// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;
import { Constants } from "../../types/Constants.sol";
import { IAdapter } from "../../interfaces/IAdapter.sol";
import { SemVer } from "../../common/semver/SemVer.sol";
import { IIndexedEvents } from "@rhinestone/compact-utils/src/interfaces/IEvents.sol";

/**
 * @title AdapterBase
 * @notice Abstract base contract for settlement layer specific adapters in the Router ecosystem
 * @dev This contract provides the foundational functionality that all settlement adapters must implement.
 *      Adapters are delegate-called from the Router contract to handle cross-chain operations, token transfers,
 *      and settlement logic for specific protocols or chains. Inheriting contracts must implement settlement-specific
 *      logic while leveraging the common patterns provided here for security, token handling, and router integration.
 *
 * @dev CRITICAL SECURITY NOTICE:
 *      - Adapters are ALWAYS executed via delegatecall from the Router contract
 *      - The Router's storage and balance are accessible during adapter execution
 *      - DO NOT implement direct calls to untrusted contracts from adapter functions
 *      - All external calls to untrusted contracts could be detrimental to Router security
 *      - Use only trusted, well-audited protocols and contracts in adapter implementations
 *
 * @dev IMPLEMENTATION REQUIREMENTS:
 *      - All external functions that implement fill or claim logic MUST return their own function selector
 *      - Return signature must be: returns(bytes4) with value of functionName.selector
 *      - All claim/fill functions MUST be added to the IERC165 supportsInterface implementation
 *      - Example: function myFillFunction() external returns(bytes4) { return this.myFillFunction.selector; }
 *
 * @dev ADAPTER IMPLEMENTATION GUIDE:
 *
 * When creating a new adapter that inherits from AdapterBase, follow these critical guidelines:
 *
 * 1. FUNCTION SIGNATURE REQUIREMENTS:
 *    - All fill/claim functions MUST return bytes4 (their own selector)
 *    - Example: function myFill(...) external returns(bytes4) { ...; return this.myFill.selector; }
 *
 * 2. SECURITY REQUIREMENTS:
 *    - NEVER make direct calls to untrusted external contracts
 *    - Remember: adapters run in Router's context via delegatecall
 *    - Any storage writes affect Router's storage, not adapter's storage
 *    - Use only trusted, audited protocols (e.g., Uniswap, AAVE, Compound)
 *
 * 3. IERC165 IMPLEMENTATION:
 *    - Override supportsInterface to include all your fill/claim function selectors
 *    - Example:
 *      function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
 *          return interfaceId == this.myFill.selector ||
 *                 interfaceId == this.myClaim.selector ||
 *                 super.supportsInterface(interfaceId);
 *      }
 *
 * 4. RELAYER CONTEXT:
 *    - Use _loadRelayerContext() to retrieve relayer-provided data
 *    - Define your own struct for the expected relayer context format
 *    - Example: (uint contextLength, bytes calldata relayerCtx) = _loadRelayerContext();
 *               MyRelayerData memory data = abi.decode(relayerCtx, (MyRelayerData));
 *
 * 5. TOKEN HANDLING:
 *    - Use provided helpers: _prefundRecipient
 *    - Handle both ERC20 and native ETH (Constants.NATIVE_TOKEN)
 */
abstract contract AdapterBase is IAdapter, SemVer, IIndexedEvents {
    /// @notice The Router contract address that this adapter is designed to work with
    /// @dev Used for security checks to ensure adapter functions are only called via delegatecall from the Router
    address public immutable _ROUTER;

    /// @notice The Arbiter contract address responsible for validating settlements
    /// @dev If no arbiter is provided during construction, defaults to address(this) for self-arbitration
    address public immutable ARBITER;

    /// @notice Thrown when adapter functions are called directly instead of via Router delegatecall
    error OnlyDelegateCall();

    error InvalidRelayerContext();

    /**
     * @notice Initializes the adapter with router and arbiter addresses
     * @dev Sets up the fundamental addresses needed for adapter operation and security validation
     * @param router The Router contract address that will delegatecall into this adapter
     * @param arbiter The Arbiter contract address for settlement validation, or address(0) for self-arbitration
     */
    constructor(address router, address arbiter) {
        _ROUTER = router;
        if (arbiter == address(0)) {
            ARBITER = address(this);
        } else {
            ARBITER = arbiter;
        }
    }

    /**
     * @notice Ensures function is only called via delegatecall from the Router contract
     * @dev Critical security modifier that prevents direct calls to adapter functions
     *      When adapter functions are delegatecalled from Router, they execute in Router's context,
     *      meaning they have access to Router's storage, balance, and permissions.
     *      This modifier prevents malicious actors from calling adapter functions directly
     *      which could bypass Router's security checks and access controls.
     */
    modifier onlyViaRouter() {
        _onlyRouterAdapter();
        _;
    }

    /**
     * @notice Internal function to verify the adapter is being called via Router delegatecall
     * @dev When delegatecalled from Router, address(this) equals _ROUTER due to delegatecall context
     *      This prevents malicious direct calls to adapter functions that could bypass Router's security checks
     */
    function _onlyRouterAdapter() internal view virtual {
        require(address(this) == _ROUTER, OnlyDelegateCall());
    }

    /**
     * @notice Extracts relayer-provided context data from the end of the calldata
     * @dev The Router's `_callAdapterWithRelayerContext` function appends relayer context to adapter calls using:
     *      `abi.encodePacked(adapterCalldata, relayerContext, uint256(relayerContext.length))`
     *
     *      Resulting calldata format: [original_function_calldata][relayer_context_bytes][context_length_32_bytes]
     *
     *      This function efficiently extracts the relayer context without copying data by:
     *      1. Reading the context length from the last 32 bytes of calldata
     *      2. Calculating the offset where relayer context begins
     *      3. Returning a calldata slice pointing to the relayer context
     *
     *      The relayer context contains settlement-layer-specific data that varies by adapter implementation.
     *      Each adapter should `abi.decode(relayerContext, (SpecificStructType))` to parse their expected format.
     *
     *      Example usage in adapter implementations:
     *      ```solidity
     *      (uint contextLength, bytes calldata relayerCtx) = _loadRelayerContext();
     *      MySettlementData memory data = abi.decode(relayerCtx, (MySettlementData));
     *      ```
     *
     * @return contextLength The length of the relayer context in bytes
     * @return relayerContext The relayer context as a calldata slice ready for abi.decode by the adapter
     */
    function _loadRelayerContext() internal pure returns (uint256 contextLength, bytes calldata relayerContext) {
        assembly ("memory-safe") {
            let totalSize := calldatasize()
            contextLength := calldataload(sub(totalSize, 0x20))
            relayerContext.offset := sub(totalSize, add(contextLength, 0x20))
            relayerContext.length := contextLength
        }
    }

    function supportsInterface(bytes4 selector) public pure virtual returns (bool) {
        return selector == this.supportsInterface.selector || selector == type(IAdapter).interfaceId;
    }

    /**
     * @notice Returns the address authorized to spend tokens for settlement
     * @dev Adapters must override this function to specify the correct spender address
     */
    // solhint-disable-next-line no-empty-blocks
    function settlementLayerSpender() external view virtual returns (address tokenSpender) { }

    function ADAPTER_TAG() external pure virtual returns (bytes12 adapterTag) {
        adapterTag = Constants.DEFAULT_ADAPTER_TAG;
    }
}
