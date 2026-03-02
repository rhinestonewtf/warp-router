// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library IStandaloneIntentExecutor {
    struct GasRefund {
        address token;
        uint256 exchangeRate;
        uint256 overhead;
    }

    struct MultiChainOps {
        address account;
        uint256 chainIndex;
        bytes32[] otherChains;
        uint256 nonce;
        Types.Operation ops;
        bytes signature;
    }

    struct SingleChainOps {
        address account;
        uint256 nonce;
        Types.Operation ops;
        bytes signature;
    }
}

library Types {
    struct Operation {
        bytes data;
    }
}

interface Interface {
    error InvalidRelayerContext();
    error MajorVersionTooLarge(uint256 major);
    error MinorVersionTooLarge(uint256 minor);
    error OnlyDelegateCall();
    error PatchVersionTooLarge(uint256 patch);

    event RouterClaimed_Compact(address sponsor, uint256 nonce);
    event RouterClaimed_Permit2(address sponsor, uint256 nonce);
    event RouterFilled(address recipient, uint256 nonce);

    function ADAPTER_TAG() external pure returns (bytes12);
    function ARBITER() external view returns (address);
    function _ROUTER() external view returns (address);
    function handleFill_intentExecutor_executeMultichainOps_gasRefund(
        IStandaloneIntentExecutor.MultiChainOps memory ops,
        IStandaloneIntentExecutor.GasRefund memory gasRefund
    ) external payable returns (bytes4);
    function handleFill_intentExecutor_executeSinglechainOps_gasRefund(
        IStandaloneIntentExecutor.SingleChainOps memory ops,
        IStandaloneIntentExecutor.GasRefund memory gasRefund
    ) external payable returns (bytes4);
    function semVer() external view returns (bytes6 packedVersion);
    function semVerUnpacked() external view returns (uint256 major, uint256 minor, uint256 patch);
    function settlementLayerSpender() external view returns (address tokenSpender);
    function supportsInterface(bytes4 selector) external pure returns (bool supported);
    function version() external view returns (bytes memory);
}
