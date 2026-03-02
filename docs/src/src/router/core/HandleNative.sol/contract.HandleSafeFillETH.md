# HandleSafeFillETH
[Git Source](https://github.com/rhinestonewtf/compact-utils/blob/1c4e4566192e5b39577aef085af405aca2f20a9d/src/router/core/HandleNative.sol)

Security contract that prevents stuck ETH exploitation in the router during intent fills

When relayers/solvers fill user intents with ETH, they send ETH to the payable fill function.
The fill function may call multiple fill routines across one or many adapters in a loop,
with each adapter potentially consuming some of the provided ETH.
Security Risk: If adapters don't consume all ETH, leftover funds remain stuck in the router.
This creates an attack vector where malicious actors could deliberately underpay in
subsequent fills, relying on stuck ETH from previous transactions to complete their fills.
Solution: This modifier enforces that ALL provided ETH must be consumed by the end of
the fill operation, preventing any ETH from remaining stuck in the contract.


## Functions
### handleNative

Modifier that ensures all sent ETH is consumed during the fill operation

Applied to the main fill function to prevent stuck ETH exploitation
Behavior:
- If no ETH is sent (msg.value == 0): Executes normally without balance check
- If ETH is sent (msg.value > 0): Executes the fill operation, then verifies
that the contract balance is zero afterwards
The post-execution balance check ensures that:
1. All sent ETH was properly forwarded to adapters
2. No ETH remains stuck that could be exploited in future fills
3. Relayers/solvers must accurately calculate required ETH amounts

**Note:**
security-note: Reverts if any ETH remains in the contract after fill execution,
preventing cross-transaction ETH exploitation


```solidity
modifier handleNative() ;
```

## Errors
### UnusedETH

```solidity
error UnusedETH(uint256 overpayed)
```

