// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library SameChainAdapter {
    struct FillDataCompact {
        Types.Order order;
        Types.Signatures userSigs;
        bytes32[] otherElements;
        bytes allocatorData;
    }

    struct FillDataPermit2 {
        Types.Order order;
        Types.Signatures userSigs;
    }
}

library Types {
    struct Operation {
        bytes data;
    }

    struct Order {
        address sponsor;
        address recipient;
        uint256 nonce;
        uint256 expires;
        uint256 fillDeadline;
        uint256 notarizedChainId;
        uint256 targetChainId;
        uint256[2][] tokenIn;
        uint256[2][] tokenOut;
        uint256 packedGasValues;
        Operation preClaimOps;
        Operation targetOps;
        bytes qualifier;
    }

    struct Signatures {
        bytes notarizedClaimSig;
        bytes preClaimSig;
    }
}

interface Interface {
    error ClaimFailed();
    error GasStipendTooLow();
    error IncorrectType();
    error InsufficientGasForMinGas(uint256 required, uint256 available);
    error InvalidEip712HashLength();
    error InvalidOrderData();
    error InvalidRelayerContext();
    error MajorVersionTooLarge(uint256 major);
    error MinGasExceedsLimit();
    error MinorVersionTooLarge(uint256 minor);
    error NoOperationsAllowed();
    error OnlyDelegateCall();
    error OnlyRouter();
    error OrderExpired();
    error PatchVersionTooLarge(uint256 patch);

    event PreClaimExecutionFailed();
    event ProcessedClaim(address indexed sponsor, uint256 indexed nonce, bytes32 indexed claimHash);
    event RouterClaimed_Compact(address sponsor, uint256 nonce);
    event RouterClaimed_Permit2(address sponsor, uint256 nonce);
    event RouterFilled(address recipient, uint256 nonce);
    event SameChainTargetOpsNotHandled();

    function ADAPTER_TAG() external pure returns (bytes12 adapterTag);
    function ARBITER() external view returns (address);
    function EXECUTOR() external view returns (address);
    function _ROUTER() external view returns (address);
    function handleCompact_NotarizedChain(
        Types.Order memory order,
        Types.Signatures memory sigs,
        bytes32[] memory otherElements,
        bytes memory allocatorData,
        address relayer
    ) external returns (address sponsor, uint256 nonce);
    function handlePermit2(Types.Order memory order, Types.Signatures memory sigs, address relayer)
        external
        returns (address sponsor, uint256 nonce);
    function qualificationHash(bytes memory data) external pure returns (bytes32 result);
    function samechain_compact_handleFill(SameChainAdapter.FillDataCompact memory fillData)
        external
        payable
        returns (bytes4 selector);
    function samechain_permit2_handleFill(SameChainAdapter.FillDataPermit2 memory fillData)
        external
        payable
        returns (bytes4 selector);
    function semVer() external view returns (bytes6 packedVersion);
    function semVerUnpacked() external view returns (uint256 major, uint256 minor, uint256 patch);
    function settlementLayerSpender() external view returns (address tokenSpender);
    function supportsInterface(bytes4 selector) external pure returns (bool supported);
    function version() external view returns (bytes memory);
}
