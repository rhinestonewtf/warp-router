import "./AdapterDriverBase.sol";
import "src/arbiters/multicall/MultiCallAdapter.sol";

contract DriverMultiCallAdapter is IAdapterDriver {
    bytes4[] private fillSelectors;
    bytes4[] private claimSelectors;

    constructor() {
        fillSelectors.push(MultiCallAdapter.multicall_handlePayable.selector);
        fillSelectors.push(MultiCallAdapter.multicall_handleFill.selector);
        claimSelectors.push(MultiCallAdapter.multicall_handleJITClaim.selector);
    }

    function getSelectors() external view returns (bytes4[] memory _fillSelectors, bytes4[] memory _claimSelectors) {
        return (fillSelectors, claimSelectors);
    }
}
