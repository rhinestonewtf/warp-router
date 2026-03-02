#!/bin/bash
set -e
export FOUNDRY_WARNINGS=off

# Array of contract names to build
CONTRACTS=(
    # Core contracts from Build.sol
    "src/allocator/RSAllocator.sol"
    "src/relayerPot/RhinestoneRelayerV0.sol"
    "src/relayerPot/RhinestoneRelayerV1.sol"
    "src/arbiters/multicall/SingleCallAdapter.sol"
    "src/arbiters/multicall/MultiCallAdapter.sol"
    "src/arbiters/samechain/SameChainAdapter.sol"
    "src/emissary/Emissary.sol"
    "src/executor/IntentExecutor.sol"
    "src/executor/StandaloneIntent/aux/Paymaster.sol"
    "src/router/Router.sol"
    "src/router/utils/Caller.sol"
    "src/common/MulticallHandler.sol"
    "src/simulate/SimulateAllocator.sol"
    "src/simulate/SimulateEmissary.sol"
    "src/simulate/SimulateRouter.sol"
    "src/adapters/IntentExecutorAdapter.sol"
    "src/adapters/IntentExecutorAdapterGasRefund.sol"
    "script/DriverSameChainAdapter.sol"
    "script/DriverIntentExecutorAdapter.sol"
    "script/DriverIntentExecutorAdapterGasRefund.sol"
    "script/DriverMultiCallAdapter.sol"
    "src/executor/StandaloneIntent/aux/Paymaster.sol"
)

# Loop through the contracts and run build-artifacts.sh for each
for CONTRACT in "${CONTRACTS[@]}"; do
    echo "Building artifacts for $CONTRACT..."
    ./build-artifacts.sh "$CONTRACT"
    
    # Check the exit status of the previous command
    if [ $? -eq 0 ]; then
        echo "Successfully built artifacts for $CONTRACT"
    else
        echo "Failed to build artifacts for $CONTRACT"
        # Optionally, you can choose to exit the script on first failure
        exit 1
    fi
done

echo "Artifact build process completed."


cast interface ./artifacts/SameChainAdapter/SameChainAdapter.json > ./artifacts/SameChainAdapter/ISameChainAdapter.sol
cast interface ./artifacts/IntentExecutorAdapter/IntentExecutorAdapter.json > ./artifacts/IntentExecutorAdapter/IntentExecutorAdapter.sol
cast interface ./artifacts/IntentExecutorAdapterGasRefund/IntentExecutorAdapterGasRefund.json > ./artifacts/IntentExecutorAdapterGasRefund/IntentExecutorAdapterGasRefund.sol

