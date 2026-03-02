// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Bytes32ArrayLib } from "@rhinestone/compact-utils/src/common/Bytes32ArrayLib.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";
import { IStandaloneIntentExecutor } from "../../interfaces/IStandaloneIntent.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";

/**
 * @title EIP712Lib
 * @notice Library for EIP-712 structured data hashing in standalone intent execution
 * @dev This library provides efficient EIP-712 hash computation for multi-chain operations
 *      with gas-optimized assembly implementations. It supports two main data structures:
 *
 *      1. ChainOps: Operations for a specific chain (chainId, nonce, operation wrapper, gas refund)
 *      2. MultiChainOps: Account-level operations across multiple chains
 *      3. SingleChainOps: Account-level operations for a single chain
 *
 *      The library implements a Merkle tree-like structure where operations from different
 *      chains are combined into a single hash, enabling atomic multi-chain intent execution
 *      with a single signature.
 *
 *      EIP-712 Structure:
 *      - ChainOps(uint256 chainId, uint256 nonce, Op op, GasRefund gasRefund)
 *      - MultiChainOps(address account, ChainOps[] ops)
 *      - SingleChainOps(address account, uint256 nonce, Op op, GasRefund gasRefund)
 *      - GasRefund(address token, uint256 amount)
 *      - Op(bytes32 vt, Ops[] ops)
 *      - Ops(address to, uint256 value, bytes data)
 *
 * @custom:gas All hash functions use assembly for gas optimization while maintaining memory safety
 */
library EIP712Lib {
    using Bytes32ArrayLib for bytes32[];
    using EfficientHashLib for bytes32;
    using EfficientHashLib for bytes32[];
    using EIP712TypeHashLib for Types.Operation;

    /// @dev EIP-712 type hash for GasRefund struct
    /// keccak256("GasRefund(address token,uint256 exchangeRate,uint256 overhead)")
    bytes32 internal constant TYPEHASH_GAS_REFUND = 0x0bf04d9dcc5e703a75ba16d19c00f9d87fa30b9a815627102c15624d338eb094;

    /// @dev NO_GASREFUND constant - hash of GasRefund with address(0), exchangeRate 0, and overhead 0
    /// keccak256(abi.encode(TYPEHASH_GAS_REFUND, address(0), uint256(0), uint256(0)))
    bytes32 internal constant NO_GASREFUND = 0x44db4de84d423abe696e354fc99de162153ee2f8985ab84305061247a78a3be4;

    /// @dev EIP-712 type hash for ChainOps structure - includes dependent Op and GasRefund type definitions
    /// keccak256("ChainOps(uint256 chainId,uint256 nonce,Op op,GasRefund gasRefund)GasRefund(address token,uint256
    /// exchangeRate,uint256 overhead)Op(bytes32 vt,Ops[] ops)Ops(address to,uint256 value,bytes data)")
    bytes32 internal constant CHAINOPS_TYPEHASH = 0x23be58b49a785664b9fdef60b8b3cb9055a50028051e331c42e768dc45755135;

    /// @dev EIP-712 type hash for MultiChainOps structure - includes all dependent type definitions
    /// keccak256("MultiChainOps(address account,ChainOps[] ops)ChainOps(uint256 chainId,uint256 nonce,Op op,GasRefund
    /// gasRefund)GasRefund(address token,uint256 exchangeRate,uint256 overhead)Op(bytes32 vt,Ops[] ops)Ops(address to,uint256 value,bytes data)")
    bytes32 internal constant MULTICHAINOPS_TYPEHASH = 0x59c4799388bfef9799e06e269d9a96259f3fd0ca05fd3bd399750d2c045f06aa;

    /// @dev EIP-712 type hash for single-chain operations
    /// @dev Includes account address, nonce, operation, and gas refund
    /// keccak256("SingleChainOps(address account,uint256 nonce,Op op,GasRefund gasRefund)GasRefund(address token,uint256
    /// exchangeRate,uint256 overhead)Op(bytes32 vt,Ops[] ops)Ops(address to,uint256 value,bytes data)")
    bytes32 internal constant SINGLECHAINOPS_TYPEHASH = 0xbae11135c33effc421d699bbb53d9926a005ed0f2f5eb672c62cbfa943807291;

    /**
     * @notice Computes the EIP-712 hash for a GasRefund struct
     * @dev Uses assembly for gas-optimized hashing of gas refund data
     * @param token The token address for gas refund
     * @param exchangeRate The amount of tokens for gas refund
     * @param overhead The fixed gas overhead to add to the gas calculation
     * @return _hash The computed EIP-712 hash for the GasRefund struct
     * @custom:gas Assembly optimization for efficient hashing
     */
    function hashGasRefund(address token, uint256 exchangeRate, uint256 overhead) internal pure returns (bytes32 _hash) {
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, TYPEHASH_GAS_REFUND) // Store type hash
            mstore(add(m, 0x20), token) // Store token address at offset 0x20
            mstore(add(m, 0x40), exchangeRate) // Store exchangeRate at offset 0x40
            mstore(add(m, 0x60), overhead) // Store overhead at offset 0x60
            _hash := keccak256(m, 0x80) // Hash 128 bytes total (4 * 32 bytes)
        }
    }

    /**
     * @notice Computes the EIP-712 hash for chain-specific operations
     * @dev Creates a structured hash for operations on a specific chain, including
     *      the chain ID for replay protection across different networks. Uses
     *      gas-optimized assembly for memory management and hashing.
     *
     *      Hash structure: keccak256(typehash || chainId || nonce || opHash || gasRefundHash)
     *
     * @param chainId The blockchain identifier where these operations will execute
     * @param nonce The nonce for replay protection on this specific chain
     * @param ops The operations to execute on this chain
     * @param gasRefundHash The EIP-712 hash of the gas refund struct
     * @return _hash The computed EIP-712 hash for this chain's operations
     *
     * @custom:gas Uses assembly with memory-safe annotation for efficient hashing
     */
    function hashChainOps(
        uint256 chainId,
        uint256 nonce,
        Types.Operation calldata ops,
        bytes32 gasRefundHash
    )
        internal
        pure
        returns (bytes32 _hash)
    {
        // Hash the operations using EIP712TypeHashLib
        bytes32 opsHash = ops.hashOps();
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, CHAINOPS_TYPEHASH) // Store type hash at memory location
            mstore(add(m, 0x20), chainId) // Store chain ID at offset 0x20
            mstore(add(m, 0x40), nonce) // Store nonce at offset 0x40
            mstore(add(m, 0x60), opsHash) // Store op hash at offset 0x60
            mstore(add(m, 0x80), gasRefundHash) // Store gas refund hash at offset 0x80
            _hash := keccak256(m, 0xa0) // Hash 160 bytes total (5 * 32 bytes)
        }
    }

    /**
     * @notice Computes the EIP-712 hash for single-chain operations
     * @dev Creates a structured hash for operations limited to a single chain. This is simpler
     *      than the multi-chain variant as it doesn't include chainIndex or otherChains arrays.
     *      The hash combines the account, nonce, operations, and gas refund.
     *
     *      Gas optimization: Uses inline assembly for efficient memory management and hashing,
     *      directly storing values in memory without intermediate copies.
     *
     * @param account The account address owning these operations
     * @param nonce The nonce for replay protection at the account level
     * @param ops The operations to be executed on the current chain
     * @param gasRefundHash The EIP-712 hash of the gas refund struct
     * @return _hash The computed EIP-712 structured hash for the single-chain operations
     *
     * @custom:gas More gas efficient than hashMultiChainOps due to fewer fields to hash
     */
    function hashSingleChainOps(
        address account,
        uint256 nonce,
        Types.Operation calldata ops,
        bytes32 gasRefundHash
    )
        internal
        pure
        returns (bytes32 _hash)
    {
        _hash = SINGLECHAINOPS_TYPEHASH;

        // Hash the operations using EIP712TypeHashLib
        bytes32 opsHash = ops.hashOps();

        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, _hash) // Store type hash at memory location
            mstore(add(m, 0x20), account) // Store account address at offset 0x20
            mstore(add(m, 0x40), nonce) // Store nonce at offset 0x40
            mstore(add(m, 0x60), opsHash) // Store op hash at offset 0x60
            mstore(add(m, 0x80), gasRefundHash) // Store gas refund hash at offset 0x80
            _hash := keccak256(m, 0xa0) // Hash 160 bytes total (5 * 32 bytes)
        }
    }

    /**
     * @notice Hashes single-chain operations for signature validation
     * @dev Extracts the nonce and computes the EIP-712 hash for the single-chain operations.
     *      This is the primary entry point for processing SingleChainOps before signature
     *      validation and execution.
     *
     * @param singleChainOps The complete single-chain operations structure containing account,
     *                       nonce, operations, and signature
     * @param gasRefundHash The EIP-712 hash of the gas refund struct
     * @return _hash The computed EIP-712 structured hash for signature validation
     * @return nonce The extracted nonce value for replay protection
     *
     * @custom:gas Single-pass processing minimizes memory copies and redundant operations
     */
    function hashAndDecode(
        IStandaloneIntentExecutor.SingleChainOps calldata singleChainOps,
        bytes32 gasRefundHash
    )
        internal
        pure
        returns (bytes32 _hash, uint256 nonce)
    {
        nonce = singleChainOps.nonce;
        _hash = hashSingleChainOps(singleChainOps.account, nonce, singleChainOps.ops, gasRefundHash);
    }

    /**
     * @notice Computes the complete EIP-712 hash for multi-chain operations
     * @dev This is the main hash function that combines operations from multiple chains
     *      into a single hash for signature validation. The process:
     *
     *      1. Extracts nonce and account from the multi-chain operations
     *      2. Computes hash for operations on the current chain
     *      3. Inserts current chain operations into the multi-chain structure
     *      4. Combines all chain operations into final EIP-712 hash
     *
     *      This enables atomic multi-chain execution with a single signature.
     *
     * @param multichainOps The complete multi-chain operations structure
     * @param gasRefundHash The EIP-712 hash of the gas refund struct
     * @return _hash The computed EIP-712 hash for signature validation
     * @return nonce The extracted nonce for replay protection
     *
     * @custom:gas Uses view function to access block.chainid and assembly for efficient hashing
     */
    function hashAndDecode(
        IStandaloneIntentExecutor.MultiChainOps calldata multichainOps,
        bytes32 gasRefundHash
    )
        internal
        view
        returns (bytes32 _hash, uint256 nonce)
    {
        nonce = multichainOps.nonce;
        address account = multichainOps.account;

        // Compute hash for operations on the current chain
        bytes32 chainOpsThisChain =
            hashChainOps({ chainId: block.chainid, nonce: nonce, ops: multichainOps.ops, gasRefundHash: gasRefundHash });

        // Insert current chain operations into the multi-chain structure at the specified index
        // This creates a deterministic ordering across all chains
        bytes32 allElements = multichainOps.otherChains.insertAtAndHash({ index: multichainOps.chainIndex, element: chainOpsThisChain });

        // Compute final multi-chain operations hash
        bytes32 typehash = MULTICHAINOPS_TYPEHASH;
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, typehash) // Store type hash
            mstore(add(m, 0x20), account) // Store account address
            mstore(add(m, 0x40), allElements) // Store combined chains hash
            _hash := keccak256(m, 0x60) // Hash 96 bytes total (3 * 32 bytes)
        }
    }

    /**
     * @notice Computes EIP-712 hash from pre-computed chain operation hashes
     * @dev Alternative hash function that takes pre-computed chain hashes instead of
     *      raw multi-chain operations. Useful for optimization when chain hashes
     *      are already available or for external hash verification.
     *
     *      This function is pure since it doesn't need access to block.chainid.
     *
     * @param account The account address that owns these multi-chain operations
     * @param allChains Array of pre-computed hashes for all chain operations
     * @return _hash The computed EIP-712 hash for signature validation
     *
     * @custom:gas Pure function with assembly optimization for gas efficiency
     */
    function hash(address account, bytes32[] calldata allChains) internal pure returns (bytes32 _hash) {
        // Hash the array of chain operation hashes
        bytes32 allElements = allChains.hash();

        // Compute the final multi-chain operations hash
        bytes32 typehash = MULTICHAINOPS_TYPEHASH;
        assembly ("memory-safe") {
            let m := mload(0x40) // Get free memory pointer
            mstore(m, typehash) // Store type hash
            mstore(add(m, 0x20), account) // Store account address
            mstore(add(m, 0x40), allElements) // Store combined chains hash
            _hash := keccak256(m, 0x60) // Hash 96 bytes total (3 * 32 bytes)
        }
    }
}
