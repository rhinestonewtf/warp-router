import "./AdapterDriverBase.sol";
import "src/arbiters/samechain/SameChainAdapter.sol";

contract DriverSameChainAdapter is IAdapterDriver {
    bytes4[] private fillSelectors;
    bytes4[] private claimSelectors;

    constructor() {
        fillSelectors.push(SameChainAdapter.samechain_compact_handleFill.selector);
        fillSelectors.push(SameChainAdapter.samechain_permit2_handleFill.selector);
    }

    function getSelectors() external view returns (bytes4[] memory _fillSelectors, bytes4[] memory _claimSelectors) {
        return (fillSelectors, claimSelectors);
    }
}
