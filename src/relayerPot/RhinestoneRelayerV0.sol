// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { RhinestoneRelayerV1 } from "./RhinestoneRelayerV1.sol";
import { TokenAmount } from "./RhinestoneRelayerV1.sol";

contract RhinestoneRelayerV0 is RhinestoneRelayerV1 {
    address public immutable RHINESTONE_V0;

    constructor(address _routerV0, address _routerV1, address _owner) RhinestoneRelayerV1(_routerV1, _owner) {
        require(_routerV0 != address(0), InvalidConstructorArg());
        RHINESTONE_V0 = _routerV0;
    }

    /// @notice Executes calldata on the Rhinestone Spokepool (v0).
    /// @dev Doesn't allow using an ETH amount stored in the contract.
    // Selector: 0x00000019
    function relayV0_ERC20_13732236() external payable onlyTrustedRelayer {
        address routerV0 = RHINESTONE_V0;
        assembly {
            // Get calldata size minus
            // the function selector (first 4 bytes)
            let s := sub(calldatasize(), 0x04)
            // Copy calldata to memory
            calldatacopy(0x00, 0x04, s)
            // Call the Warp Routerr with the copied calldata, bubble revert if the call failed
            if iszero(call(gas(), routerV0, 0x00, 0x00, s, 0x00, 0x00)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function setApprovalsV0(TokenAmount[] calldata tokenAmounts) external onlyOwner {
        _setApprovalForRouter(tokenAmounts, RHINESTONE_V0);
    }
}
