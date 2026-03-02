// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { FeeCollector } from "src/router/utils/FeeCollector.sol";

contract MockFeeCollector is FeeCollector {
    function exposed_collectFee(Fee calldata fee) external {
        _collectFee(fee);
    }

    function exposed_collectFee(address recipient, uint256[2][] calldata tokenAndAmounts) external {
        _collectFee(recipient, tokenAndAmounts);
    }

    function exposed_collectFee(Fee[] calldata fees) external {
        _collectFee(fees);
    }
}
