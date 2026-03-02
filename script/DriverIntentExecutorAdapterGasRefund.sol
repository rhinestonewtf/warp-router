import "./AdapterDriverBase.sol";
import "src/adapters/IntentExecutorAdapterGasRefund.sol";
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";

// Driver contract for IntentExecutorAdapterGasRefund
contract DriverIntentExecutorAdapterGasRefund is IAdapterDriver {
    using AdapterTagLib for bytes12;
    bytes4[] private fillSelectors;
    bytes4[] private claimSelectors;

    constructor() {
        fillSelectors.push(IntentExecutorAdapterGasRefund.handleFill_intentExecutor_executeMultichainOps_gasRefund.selector);
        fillSelectors.push(IntentExecutorAdapterGasRefund.handleFill_intentExecutor_executeSinglechainOps_gasRefund.selector);
    }

    function getSelectors() external view returns (bytes4[] memory _fillSelectors, bytes4[] memory _claimSelectors) {
        return (fillSelectors, claimSelectors);
    }
}
