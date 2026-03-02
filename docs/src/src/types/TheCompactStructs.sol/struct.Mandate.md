# Mandate
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/types/TheCompactStructs.sol)


```solidity
struct Mandate {
Target target;
SmartExecutionLib.SigMode v;
uint128 minGas;
Execution[] originOps;
Execution[] destOps;
bytes q;
}
```

