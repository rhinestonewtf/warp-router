import "./AdapterDriverBase.sol";
import "src/adapters/IntentExecutorAdapter.sol";
import { AdapterTagLib } from "@rhinestone/compact-utils/src/router/lib/v1/AdapterTagLib.sol";

contract DriverIntentExecutorAdapter is IAdapterDriver {
    using AdapterTagLib for bytes12;
    bytes4[] private fillSelectors;
    bytes4[] private claimSelectors;

    constructor() {
        fillSelectors.push(IntentExecutorAdapter.handleFill_intentExecutor_handleCompactTargetOps.selector);
        fillSelectors.push(IntentExecutorAdapter.handleFill_intentExecutor_handlePermit2TargetOps.selector);
        fillSelectors.push(IntentExecutorAdapter.handleFill_intentExecutor_executeMultichainOps.selector);
        fillSelectors.push(IntentExecutorAdapter.handleFill_intentExecutor_executeSinglechainOps.selector);
    }

    function getSelectors() external view returns (bytes4[] memory _fillSelectors, bytes4[] memory _claimSelectors) {
        return (fillSelectors, claimSelectors);
    }
}
