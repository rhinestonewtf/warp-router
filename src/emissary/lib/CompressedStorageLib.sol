// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { LibZip } from "solady/utils/LibZip.sol";

library Compressed {
    struct Bytes {
        bytes data;
    }

    function sstore(Bytes storage self, bytes memory data) internal {
        self.data = LibZip.flzCompress(data);
    }

    function sload(Bytes storage self) internal view returns (bytes memory data) {
        data = LibZip.flzDecompress(self.data);
    }
}
