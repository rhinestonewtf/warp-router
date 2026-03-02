# AdapterConfig
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/lib/RouterStorageLib.sol)

Configuration struct for storing adapter information in the router

This struct is used to store both the adapter address and its associated tag
in a compact format for efficient storage and retrieval.
Storage layout (packed in single slot):
- bytes12 adapterTag: bits 160-255 (upper 96 bits)
- address adapter: bits 0-159 (lower 160 bits)


```solidity
struct AdapterConfig {
bytes12 adapterTag; // Arbitrary tag for adapter identification/metadata
address adapter; // The deployed adapter contract address
}
```

