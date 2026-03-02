# Threat Model: Rhinestone Compact Utils

**Document Purpose**: This threat model is provided to external auditors to facilitate comprehensive security review of the Rhinestone Compact Utils system. It identifies trust assumptions, attack surfaces, known risks, and current security controls.

---

## 1. System Overview

The Rhinestone Compact Utils is a sophisticated settlement orchestration system enabling atomic execution of DeFi operations across protocols and chains. The architecture implements a modular, delegatecall-based pattern with five primary layers:

- **Router Layer**: Central coordination hub (RouterLogic, RouterManager)
- **Adapter Layer**: Protocol-specific settlement implementations (AdapterBase, SameChainAdapter)
- **Arbiter Layer**: Resource validation and unlocking (CompactArbiter, Permit2Arbiter, SameChainArbiter)
- **Executor Layer**: Target operation execution (IntentExecutor)
- **Emissary Layer**: Stateless validator management (Emissary)

### Key Security Properties

1. **Atomic Settlement**: All operations succeed or revert together
2. **Signature-Based Authorization**: User operations require cryptographic signatures
3. **Delegatecall Isolation**: Adapters execute in Router context with strict access controls
4. **Pre-funding Model**: Recipients receive outputs before inputs are unlocked
5. **Nonce Protection**: Prevents replay attacks across all protocols

---

## 2. Trust Boundaries

The Rhinestone Compact Utils system has **three distinct trust perspectives** that must be analyzed separately. Each stakeholder has different trust assumptions and threat models:

### 2.1 Trust Model Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    RHINESTONE (Protocol Operator)                │
│  Controls: Adapters, Arbiters, Router, AddressBook              │
│  Trusts: Own infrastructure, External protocols (Compact/Permit2)│
│  Threats: Malicious solvers, malicious users, external exploits │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SOLVER/RELAYER (Order Filler)                 │
│  Controls: Solver context, pre-funding, atomic signature request│
│  Trusts: Rhinestone infrastructure, atomic signer               │
│  Threats: Malicious users, griefing, fund lock-up               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         USER (Order Sponsor)                     │
│  Controls: Order signing, asset authorization                   │
│  Trusts: Rhinestone infrastructure, specific solver (optional)  │
│  Threats: Malicious adapters, rogue admin, malicious solver     │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2.2 Rhinestone Trust Model (Protocol Operator Perspective)

**What Rhinestone Controls:**
- Router contracts (RouterLogic, RouterManager)
- All adapters and arbiters
- Atomic fill signer private key
- ADD_ROLE and RM_ROLE keys
- AddressBook (trusted contract registry)
- Emissary configuration

**What Rhinestone Must Trust:**
1. **External Protocols**: TheCompact, Permit2, bridges (audited, battle-tested)
2. **EVM Security**: Solidity compiler, underlying blockchain
3. **Cryptographic Primitives**: ECDSA, EIP-712

**What Rhinestone Does NOT Trust:**
1. **Solvers/Relayers**: Treated as potentially malicious
   - Must pre-fund before receiving user inputs
   - Cannot bypass atomic signature requirement
   - Can only execute via validated adapters
2. **Users**: Treated as potentially malicious
   - All orders signature-validated
   - Nonce-based replay protection
   - Operations executed in sandboxed context

**Rhinestone's Threat Model:**
- Malicious solver attempting to steal user's assets
- Malicious solver attempting to steal gas sponsorship
- Malicious user crafting exploitative orders
- Malicious user spending more gas than expected on preclaim and target ops
- External protocol compromise affecting settlements
- Admin key compromise (ADD_ROLE, RM_ROLE)
- Atomic signer key compromise
- Signature/hashing failure for atomic signature on fills

**Emergency Response Capability**:
- Can pause fills immediately via `pauseRouter()` (sets atomic signer to address(0))
- **Claims remain operational during pause** - ensures relayers can always recover funds
- Cannot pause claims by design (no signature requirement on `routeClaim()`)

---

### 2.3 Solver/Relayer Trust Model (Order Filler Perspective)

**What Solver Controls:**
- Solver context data (tokenInRecipient, routing parameters)
- Pre-funding assets (at risk during execution)
- Timing of fill operations
- Timing of claim operations

**What Solver Must Trust:**
1. **Rhinestone Infrastructure**:
   - Router won't steal pre-funded assets
   - Adapters correctly execute settlements
   - Arbiters properly unlock user resources and deposit into settlement layers correctly
2. **Atomic Signature System**:
   - Atomic signer won't sign malicious batches
   - Signature covers all operations as expected
3. **Pre-funding Atomicity**:
   - If arbiter validation fails, transaction reverts (pre-funding included)
   - No partial execution scenarios

**What Solver Does NOT Trust:**
1. **Users**: May provide invalid orders or grief solvers
   - Order may fail validation after pre-funding
   - User resources may be insufficient
   - Target operations may revert
2. **Router Admin**: Admin changes may invalidate claims
   - Claim adapter retirement before claims processed
   - Router state changes breaking claim flow

**Solver's Threat Model:**
- **Fund Lock-up**: Pre-fund assets but arbiter validation fails (MITIGATED: atomic revert)
- **Griefing**: User intentionally creates failing orders
- **Front-running**: Other solvers steal order execution after pre-funding seen
- **Malicious Adapter**: Rhinestone installs adapter that steals pre-funded assets
- **Atomic Signer Compromise**: Invalid signature allows unauthorized operations
- **🔍 Claim Adapter Retirement**: Claim adapter removed after fill but before claim (CRITICAL RISK)

**🔍 AUDITOR INFO - Claim Adapter Retirement Risk**:

In "fill first, claim later" flows, relayers face a **critical fund lock-up risk**:

1. **Fill Phase**: Relayer pre-funds recipient on target chain
2. **Pending State**: Relayer has not yet claimed user inputs from settlement layer
3. **Admin Action**: RM_ROLE calls `retireClaimAdapter()`
4. **Fund Lock**: Relayer permanently loses access to claim route, funds stranded

**Planned Mitigation**:
- 📋 RM_ROLE will be controlled by timelocked governor contract in production
- 📋  n-hours timelock on `retireClaimAdapter()` execution
- 📋 Public announcement of adapter retirement before timelock initiation
- ⚠️ **Current Status**: No on-chain enforcement of timelock requirement
- ⚠️ **Current Status**: No pending claim tracking mechanism
- ⚠️ **Current Status**: Relayer protection depends on operational procedures

**Auditor Recommendation**: Validate timelock governance implementation and verify adequate notice period for relayers.

**Solver's Risk Mitigation:**
- Only interact with audited, battle-tested Rhinestone deployments
- Simulate orders off-chain before pre-funding
- Use private mempools to prevent front-running
- Monitor Rhinestone governance for adapter changes
- Set appropriate slippage tolerances
- Claim immediately after filling when possible to minimize exposure window

---

### 2.4 User Trust Model (Order Sponsor Perspective)

**What User Controls:**
- Order parameters (tokens, amounts, recipients, deadlines)
- Private key for signing orders
- Target operations (swaps, transfers)
- Pre-claim operations (approvals, setup)
- Choice of solver (optional, via order visibility)

**What User Must Trust:**
1. **Rhinestone Infrastructure**:
   - Router won't steal assets during settlement
   - Adapters are non-malicious and correctly implemented
   - Arbiters properly validate signatures
   - Atomic fill signer won't authorize unauthorized operations
   - ADD_ROLE admin won't install malicious adapters
2. **External Protocols**:
   - TheCompact/Permit2 correctly manage resource locks
   - No vulnerabilities in external protocol contracts
3. **Solver (Implicit Trust)**:
   - Solver will pre-fund as promised
   - Solver won't manipulate solver context maliciously
   - Solver won't front-run or extract excessive MEV

**What User Does NOT Need to Trust (By Design):**
1. **Solver Pre-funding**: If solver doesn't pre-fund, arbiter validation won't unlock user assets (atomic protection)
2. **Order Execution**: Signatures prevent unauthorized execution of orders
3. **Cross-Chain Security**: Chain ID validation prevents cross-chain replay

**User's Threat Model:**
- **Malicious Adapter**: Rhinestone installs adapter that drains user funds during settlement
- **Rogue Admin**: ADD_ROLE compromised, installs malicious adapters
- **Atomic Signer Compromise**: Could authorize malicious batches
- **Solver Not Pre-funding**: Solver skips pre-funding (MITIGATED: atomic revert)
- **Malicious Target Operations**: User accidentally signs dangerous operations
- **Signature Phishing**: User tricked into signing malicious order
- **External Protocol Exploit**: TheCompact/Permit2 vulnerability affects user assets

**User's Risk Mitigation:**
- Only sign orders from trusted UIs with operation simulation
- Review all target operations and pre-claim operations carefully
- Monitor Rhinestone governance and adapter installations
- Use orders with appropriate deadlines and slippage
- Verify recipient addresses before signing
- Only interact with audited Rhinestone deployments

---

### 2.5 Trust Zones and Component Classification

#### Zone 1: Rhinestone-Controlled (Highest Trust Required)
- **Components**: RouterLogic, RouterManager, All Adapters, All Arbiters
- **Storage**: Adapter registry, atomic fill signer, AddressBook
- **Who Trusts**: Solvers, Users (MUST trust completely)
- **Who Controls**: Rhinestone (ADD_ROLE admin, RM_ROLE admin)
- **🔍 Risk**: Admin key compromise, malicious adapter installation
- **⚠️ Control Gap**: Multi-sig and timelock not enforced on-chain

#### Zone 2: Rhinestone-Operated Services
- **Components**: Atomic fill signer (off-chain), IntentExecutor, SameChainArbiter, ADD_ROLE keys, RM_ROLE keys
- **Who Trusts**: Solvers, Users
- **Who Controls**: Rhinestone operations team
- **🔍 Risk**: Key compromise, insider threat
- **⚠️ Control Gap**: Key management procedures are operational (off-chain)

#### Zone 3: External Protocols (External Trust)
- **Components**: TheCompact, Permit2, Settlement Layers
- **Who Trusts**: Rhinestone, Solvers, Users
- **Who Controls**: TheCompact and Permit2 are permissionless. Settlement Layers controlled by their teams
- **Risk**: Protocol vulnerability, upgrade issues
- **Mitigation**: Only use audited protocols with established security track record

#### Zone 4: Solver/Relayer Domain (Untrusted by Rhinestone)
- **Components**: Off-chain solver infrastructure, solver context
- **Who Trusts**: Users (implicitly when signing)
- **Who Controls**: Individual solver operators
- **Risk**: Malicious solver, front-running, MEV extraction
- **Mitigation**: Atomic revert protects users from non-performing solvers

#### Zone 5: User Domain (Untrusted by Everyone)
- **Components**: User's private key, signed orders
- **Who Trusts**: Nobody (adversarial model)
- **Who Controls**: Individual users
- **Risk**: Malicious orders, griefing, signature phishing
- **Mitigation**: Signature validation, nonce protection, gas limits

---

### 2.6 Critical Trust Boundaries

#### Boundary 1: Rhinestone → Adapter (Delegatecall Trust)
- **Nature**: Adapters execute with Router privileges via delegatecall
- **Trust Required**: Rhinestone must fully trust adapter code. Adapters are only developed in-house
- **Risk**: Faulty adapter can drain Router and user funds
- **Additional Risk**: Premature claim adapter retirement strands relayer funds in fill-first flows
- **Protection**:
  - ✅ Adapter validation, semantic versioning, interface checks
  - 📋 RM_ROLE timelock (minimum n days) for claim adapter retirement (planned for production)
- **🔍 AUDITOR INFO**: No on-chain storage isolation for adapters - they can write to any Router storage slot
- **Stakeholder Impact**:
  - Users: Complete trust in Rhinestone's adapter vetting on Fills
  - Solvers: Assets with Router approval at risk from malicious adapters
  - Relayers: Funds at risk if claim routes retired before claims processed

#### Boundary 2: Rhinestone → External Protocols
- **Nature**: Adapters/arbiters call external contracts (TheCompact, Permit2)
- **Trust Required**: External protocol security and correctness
- **Risk**: External protocol vulnerability affects settlements
- **Protection**: ✅ Only use audited, battle-tested protocols
- **Stakeholder Impact**: Users and solvers both exposed to external protocol risk

#### Boundary 3: Solver → Rhinestone (Atomic Signature Gate)
- **Nature**: Solvers request atomic signatures for batch execution
- **Trust Required**: Solver trusts atomic signer won't authorize malicious batches
- **Risk**: Atomic signer compromise enables unauthorized operations
- **Protection**: ✅ Atomic signature validates entire batch, private key security
- **🔍 AUDITOR INFO**: Private key management for atomic signer is operational control
- **Stakeholder Impact**:
  - Solvers: Must trust atomic signer for their pre-funded assets
  - Users: Must trust atomic signer won't sign unauthorized orders

#### Boundary 4: User → Rhinestone (Signature Validation Gate)
- **Nature**: Users sign orders that Rhinestone infrastructure executes
- **Trust Required**: User trusts Rhinestone won't modify or misuse signed orders
- **Risk**: Malicious adapter could exploit signed order
- **Protection**: ✅ EIP-712 signatures, nonce protection, deadline enforcement
- **Stakeholder Impact**: Users: Complete dependence on signature validation

#### Boundary 5: User → Solver (Implicit Trust)
- **Nature**: User creates order that solver will fill
- **Trust Required**: User trusts solver will pre-fund correctly and not manipulate context
- **Risk**: Solver doesn't pre-fund, manipulates tokenInRecipient
- **Protection**: ✅ Atomic revert if pre-funding missing, limited solver context impact
- **Stakeholder Impact**:
  - Users: Order may fail if solver unreliable (but funds safe)
  - Solvers: Competition for order fulfillment

---


## 3. Threat Actors

### Actor 1: Malicious Solver/Relayer
- **Motivation**: Steal user funds, extract MEV, griefing
- **Capabilities**:
  - Can submit arbitrary solver contexts
  - Controls fill operation timing
  - Can attempt to manipulate pre-funding
- **Constraints**:
  - Requires valid atomic fill signature
  - Must pre-fund recipients before claiming inputs
  - All operations signature-validated

### Actor 2: Compromised Adapter
- **Motivation**: Drain Router funds, steal user assets
- **Capabilities**:
  - Executes in Router's context via delegatecall
  - Full access to Router storage and balances
  - Can make arbitrary external calls
- **Constraints**:
  - Must be registered by ADD_ROLE
  - Must pass interface validation
  - Subject to semantic versioning controls

### Actor 3: Malicious User/Sponsor
- **Motivation**: Double-spend, replay attacks, protocol exploitation
- **Capabilities**:
  - Can craft malicious orders
  - Can attempt signature/nonce manipulation
  - Can grief solvers by creating failing orders
- **Constraints**:
  - All orders signature-validated
  - Nonces prevent replay
  - Resources locked before execution

### Actor 4: Rogue Admin (ADD_ROLE/RM_ROLE)
- **Motivation**: Install malicious adapters, disrupt protocol operations
- **Capabilities**:
  - Install new adapters
  - Hotfix existing adapters
  - Pause atomic fills
  - Retire adapters (including claim adapters)
- **Constraints**:
  - Semantic versioning enforcement
  - ⚠️ Multi-sig recommended but not enforced on-chain
  - On-chain actions are transparent and auditable

### Actor 5: External Protocol Exploit
- **Motivation**: Leverage protocol vulnerability against users
- **Capabilities**:
  - TheCompact/Permit2 vulnerabilities affect settlements
  - Bridge exploits impact cross-chain operations
- **Constraints**:
  - Cannot directly compromise Router
  - Must go through adapter interface

---

## 4. Attack Surfaces

### 4.1 Router Entry Points

| Function | Access | Attack Vectors | Controls |
|----------|--------|----------------|----------|
| `optimized_routeFill921336808()` | Public + signature | Signature forgery, replay attacks, calldata manipulation | ✅ ECDSA validation |
| `routeClaim()` | Public | Resource exhaustion, malicious adapter calls | ✅ Interface checks |
| `installFillAdapter()` | ADD_ROLE | Malicious adapter installation | 🔍 Role-based only |
| `hotfixFillAdapter()` | ADD_ROLE | Breaking changes, malicious upgrades | 🔍 Semver + role |
| `retireClaimAdapter()` | RM_ROLE | Relayer fund lock-up in fill-first flows |   |
| `pauseRouter()` | ADD_ROLE | DOS on fills (claims unaffected) | ✅ Role-based, fills only |

### 4.2 Adapter Entry Points

| Function | Access | Attack Vectors | Controls |
|----------|--------|----------------|----------|
| `samechain_compact_handleFill()` | Router only | Pre-funding manipulation, arbiter bypass | ✅ onlyViaRouter |
| `samechain_permit2_handleFill()` | Router only | Signature validation bypass | ✅ onlyViaRouter |
| `_loadrelayerContext()` | Internal | Context extraction vulnerabilities | ✅ Assembly validation |

### 4.3 Arbiter Entry Points

| Function | Access | Attack Vectors | Controls |
|----------|--------|----------------|----------|
| `handleCompact_NotarizedChain()` | Router only | Signature validation bypass, resource unlock manipulation | ✅ EIP-712 validation |
| `handlePermit2()` | Router only | Permit2 signature forgery | ✅ Permit2 validation |
| `_unlockNotarizedChain()` | Internal | TheCompact claim manipulation | ✅ Mandate validation |
| `_unlockPermit2()` | Internal | Permit2 transfer manipulation | ✅ Witness validation |

### 4.4 Executor Entry Points

| Function | Access | Attack Vectors | Controls |
|----------|--------|----------------|----------|
| `executeOpsWithoutSignature()` | Trusted only | Trusted contract bypass, unauthorized execution | 🔍 AddressBook whitelist |
| `executeCompactOps()` | Public + signature | Signature validation bypass | ✅ EIP-712 validation |
| `executePermit2Ops()` | Public + signature | Permit2 signature forgery | ✅ Permit2 validation |

### 4.5 Emissary Entry Points

| Function | Access | Attack Vectors | Controls |
|----------|--------|----------------|----------|
| `setConfig()` | Public + signatures | Nonce manipulation, signature forgery | ✅ Dual-sig validation |
| `verifyClaim()` | External | Validator bypass, configuration manipulation | ✅ Config validation |

---

## 5. Threat Analysis by Component

### 5.1 Router Layer

#### Threat R-1: Malicious Adapter Installation
- **Description**: Admin with ADD_ROLE installs malicious adapter that drains Router funds
- **Impact**: Critical - complete loss of Router funds and user assets
- **Likelihood**: Low (requires compromised admin)
- **Attack Vector**: `installFillAdapter()` with malicious contract
- **Mitigations**:
  - ✅ Role-based access control (ADD_ROLE required)
  - ✅ Interface validation (`supportsInterface` check)
  - ✅ Adapter validation (`isAdapter` delegatecall)
  - ✅ Major version compatibility check
- **🔍 AUDITOR INFO - Incomplete Controls**:
  - ⚠️ Multi-sig requirement for ADD_ROLE not enforced on-chain
  - ⚠️ No time-lock mechanism for adapter installation
  - ⚠️ Adapter code verification process is off-chain/manual
  - ⚠️ No on-chain adapter security attestation system

#### Threat R-2: Atomic Signature Forgery
- **Description**: Attacker forges atomic fill signature to execute unauthorized batch operations
- **Impact**: Critical - unauthorized user fund movements
- **Likelihood**: Very Low (requires ECDSA break or private key compromise)
- **Attack Vector**: `optimized_routeFill921336808()` with forged signature
- **Mitigations**:
  - ✅ ECDSA signature verification via `ECDSA.recoverCalldata`
  - ✅ Hash binds signature to specific calldata (replay protection)
  - ✅ Atomic signer stored in immutable storage
  - ✅ Can pause fills by setting signer to address(0)
- **🔍 AUDITOR INFO**:
  - ⚠️ No signature nonce/expiry (relies on order-level nonces)
  - ⚠️ Atomic signer private key management is operational control

#### Threat R-3: Adapter Cache Poisoning
- **Description**: Attacker manipulates adapter caching to route operations to wrong adapter
- **Impact**: High - operations execute with incorrect protocol logic
- **Likelihood**: Very Low (requires storage manipulation)
- **Attack Vector**: Manipulate `prevSelector` or `adapter` variables during batch execution
- **Mitigations**:
  - ✅ Cache variables are function-local (stack)
  - ✅ Storage reads from controlled RouterManagerStorageLib
  - ✅ Each operation validates selector matches returned value
  - ✅ Cache only used within single transaction scope

#### Threat R-4: Solver Context Length Mismatch
- **Description**: Mismatch between relayerContexts array and regular adapter calls
- **Impact**: Medium - transaction revert or wrong context consumption
- **Likelihood**: Medium (integration error)
- **Attack Vector**: Provide wrong number of solver contexts for batch
- **Mitigations**:
  - ✅ Length validation: `require(relayerContextsLength == relayerContextIndex)`
  - ✅ Index bounds checking: `require(relayerContextIndex < relayerContextsLength)`
  - ✅ Special selectors don't consume contexts

#### Threat R-5: Reentrancy During Batch Operations
- **Description**: Reentrant call during adapter execution manipulates Router state
- **Impact**: Low - reentrancy is not exploitable due to signature requirements
- **Likelihood**: Very Low (prevented by design)
- **Attack Vector**: Adapter makes external call that reenters Router
- **Mitigations**:
  - ✅ `ReentrancyGuardTransient` on all Router entry points (defense-in-depth)
  - ✅ **Fill reentrancy not exploitable**: Requires valid atomic fill signature for each call
  - ✅ **Claim reentrancy not a problem**: Each claim is independently atomic (batch only for gas savings)
  - ✅ Checks-effects-interactions pattern in adapters
  - ✅ Transient storage for gas efficiency

**Why Reentrancy is Not Exploitable**:
- **Fills**: `optimized_routeFill921336808()` requires atomic signature covering entire calldata
  - Reentrant call would need new valid signature (attacker cannot forge)
  - Each fill is independently validated and atomic
- **Claims**: `routeClaim()` has no signature requirement, but:
  - Each claim operation is independently atomic
  - Batch claiming only saves gas, doesn't change atomicity
  - Claim parameters come from original signed order (cannot be manipulated)
  - Reentering claim doesn't provide any advantage to attacker

**Conclusion**: ReentrancyGuard provides defense-in-depth, but reentrancy is not a viable attack vector due to signature requirements (fills) and atomic claim design (claims).

---

### 5.2 Adapter Layer

#### Threat A-1: Delegatecall Context Exploitation
- **Description**: Malicious adapter exploits delegatecall to access/modify Router storage
- **Impact**: Critical - complete compromise of Router (if adapter performs SSTORE)
- **Likelihood**: Very Low (requires malicious adapter installation + SSTORE operations)
- **Attack Vector**: Adapter writes to Router storage slots via SSTORE
- **Mitigations**:
  - ✅ `onlyViaRouter` modifier prevents direct calls
  - ✅ Adapter validation during installation
  - ✅ Interface enforcement via ERC165
  - ✅ **Adapters do not use SSTORE operations by design**
  - ✅ All adapter state is transient (function-local variables, calldata, memory)
  - ✅ Adapters are stateless - only orchestrate calls to external contracts
- **🔍 AUDITOR INFO - Design Pattern Verification**:
  - ✅ **Current Design**: Adapters are stateless and do not perform SSTORE
  - 📋 **Verification Required**: Verify no SSTORE opcodes in adapter bytecode
  - 📋 **Code Review**: Confirm all adapters follow stateless pattern
  - 📋 **Future Proofing**: Static analysis planned to enforce no-SSTORE rule in CI/CD

**Design Pattern**:
Adapters in Rhinestone Compact Utils are designed to be **stateless orchestrators**:
- Load context from calldata/memory (via `_loadrelayerContext`)
- Call external contracts (arbiters, settlement layers)
- Return execution status via function selector
- **Never write to storage** (no SSTORE operations)

**Security Through Design**:
- Since adapters don't use SSTORE, storage corruption is not possible (even with malicious adapter)
- This is a **design constraint** enforced through code review
- Planned: Automated bytecode analysis in CI/CD to prevent SSTORE in future updates

#### Threat A-2: Solver Context Manipulation
- **Description**: Attacker provides malicious solver context to exploit adapter logic
- **Impact**: Medium-High - depends on adapter's context usage
- **Likelihood**: Medium (attacker controls solver context)
- **Attack Vector**: Craft malicious solver context to manipulate tokenInRecipient or other parameters
- **Mitigations**:
  - ✅ Context extraction via assembly (_loadrelayerContext)
  - ✅ Atomic signature covers entire batch (context included in hash indirectly)
- **🔍 AUDITOR INFO**:
  - ⚠️ Solver context not explicitly validated against order data
  - ⚠️ Planned: Enhanced context validation in future adapter versions

#### Threat A-3: Return Value Manipulation
- **Description**: Adapter returns wrong selector to bypass Router validation
- **Impact**: High - could allow invalid operations to succeed
- **Likelihood**: Low (requires malicious adapter)
- **Attack Vector**: Return different selector than expected
- **Mitigations**:
  - ✅ Router validates returned selector: `require(selector == ...)`
  - ✅ All adapters must return `this.functionName.selector`
  - ✅ Enforced by Router validation logic

#### Threat A-4: Claim Adapter Retirement (Fill-First Flows)
- **Description**: RM_ROLE admin retires claim adapter while relayers have pending claims from fill-first flows
- **Impact**: High - relayers permanently lose access to funds locked in settlement layers
- **Likelihood**: Low (requires admin action during pending claims)
- **Attack Vector**: Call `retireClaimAdapter()` while unfulfilled claims exist
- **Attack Scenario**:
  1. Relayer fills order on target chain (pre-funds recipient)
  2. Relayer delays claiming user inputs from settlement layer
  3. RM_ROLE calls `retireClaimAdapter()`
  4. Claim route immediately removed
  5. Relayer's claim transaction reverts (adapter not found)
  6. Relayer's pre-funded assets are permanently lost
- **Mitigations Planned**:
  - 📋 RM_ROLE controlled by timelocked governor contract in production
  - 📋 Mandatory announcement period before claim adapter retirement
  - 📋 Timelock duration must exceed typical claim settlement time
- **🔍 AUDITOR INFO - CRITICAL CONTROL GAP**:
  - ⚠️ **No on-chain timelock enforcement** - currently relies on operational procedures
  - ⚠️ **No pending claim tracking** - no mechanism to detect if relayers have unfulfilled claims
  - ⚠️ **Immediate effect** - `retireClaimAdapter()` takes effect in same transaction
  - ⚠️ **Recommendation**: Implement 7-day minimum on-chain timelock for claim adapter retirement
  - ⚠️ **Recommendation**: Add on-chain registry tracking pending claims per adapter
  - ⚠️ **Recommendation**: Emergency override mechanism with relayer compensation process

---

### 5.3 Arbiter Layer

#### Threat AR-1: Signature Validation Bypass
- **Description**: Attacker bypasses signature validation to execute unauthorized operations
- **Impact**: Critical - unauthorized user fund movements
- **Likelihood**: Very Low (requires crypto break)
- **Attack Vector**: Forge user signatures for mandate validation
- **Mitigations**:
  - ✅ EIP-712 typed data hashing
  - ✅ Multi-signature validation (user + allocator where needed)
  - ✅ Nonce-based replay protection
  - ✅ Deadline/expiry enforcement
  - ✅ Chain ID validation

#### Threat AR-2: Pre-claim Operation Exploitation
- **Description**: Malicious pre-claim operations exploit user account or protocols
- **Impact**: High - could drain user funds or compromise account
- **Likelihood**: Medium (user signs malicious order)
- **Attack Vector**: Craft order with malicious preClaimOps
- **Mitigations**:
  - ✅ Pre-claim ops signature-validated by user
  - ✅ Gas stipend limits execution cost
  - ✅ minGas requirement prevents DOS
- **🔍 AUDITOR INFO**:
  - ⚠️ No on-chain validation of pre-claim operation safety (by design - flexibility vs safety tradeoff)
  - ⚠️ System relies on user signature as sole authorization for pre-claim ops
  - ⚠️ Gas stipend and minGas are only on-chain protections

#### Threat AR-3: TheCompact Claim Manipulation
- **Description**: Attacker manipulates TheCompact claim parameters to steal funds
- **Impact**: High - unauthorized resource unlock
- **Likelihood**: Low (requires TheCompact vulnerability)
- **Attack Vector**: Craft malicious claim parameters for `multichainClaim`
- **Mitigations**:
  - ✅ Mandate hash validation by TheCompact
  - ✅ Sponsor validation: `require(sponsor != address(this))`
  - ✅ Claim hash validation: `require(claimHash != bytes32(0))`
  - ✅ Signature validation by TheCompact
- **🔍 AUDITOR INFO**:
  - ⚠️ Security depends on TheCompact protocol correctness
  - ⚠️ External dependency risk

#### Threat AR-4: Permit2 Witness Manipulation
- **Description**: Attacker manipulates Permit2 witness data to bypass validation
- **Impact**: High - unauthorized token transfers
- **Likelihood**: Low (requires Permit2 vulnerability)
- **Attack Vector**: Forge mandate hash used as Permit2 witness
- **Mitigations**:
  - ✅ Mandate hash includes all order parameters
  - ✅ Permit2 validates witness typestring
  - ✅ Signature covers witness data
- **🔍 AUDITOR INFO**:
  - ⚠️ Security depends on Permit2 protocol correctness
  - ⚠️ External dependency risk

#### Threat AR-5: Target Operation Execution Bypass
- **Description**: Unauthorized execution of user target operations
- **Impact**: High - operations executed without proper authorization
- **Likelihood**: Low (requires trusted contract compromise)
- **Attack Vector**: Call `executeOpsWithoutSignature` from unauthorized contract
- **Mitigations**:
  - ✅ Trusted contract whitelist (AddressBook)
  - ✅ Only SameChainArbiter whitelisted
  - ✅ Executes only after successful mandate validation
  - ✅ Recipient == sponsor check for security
- **🔍 AUDITOR INFO**:
  - ⚠️ Trust model depends on AddressBook integrity
  - ⚠️ Single point of failure if AddressBook compromised
  - ⚠️ Planned: Multi-sig for AddressBook updates in production

---

### 5.4 Executor Layer

#### Threat E-1: Trusted Execution Privilege Escalation
- **Description**: Non-trusted contract executes operations without signature
- **Impact**: Critical - unauthorized operation execution
- **Likelihood**: Low (requires AddressBook compromise)
- **Attack Vector**: Call `executeOpsWithoutSignature` from malicious contract
- **Mitigations**:
  - ✅ AddressBook whitelist validation
  - ✅ Only trusted arbiters can use signature-less execution
  - ✅ ERC-1271 validation for smart accounts
- **🔍 AUDITOR INFO**:
  - ⚠️ **Single point of failure**: AddressBook compromise enables privilege escalation
  - ⚠️ No on-chain multi-sig requirement for AddressBook updates (operational control)
  - ⚠️ Planned: Multi-sig + timelock for AddressBook in production deployment

#### Threat E-2: Nonce Reuse/Replay
- **Description**: Attacker reuses signatures/nonces to replay operations
- **Impact**: High - duplicate execution of intents
- **Likelihood**: Low (nonce tracking prevents this)
- **Attack Vector**: Replay previously signed intent execution
- **Mitigations**:
  - ✅ Per-account nonce tracking in IntentExecutorNonceLib
  - ✅ Nonce incremented after successful execution
  - ✅ Nonce validation before execution
  - ✅ Separate nonce domains for different execution types

#### Threat E-3: ERC7579 Module Installation Attack
- **Description**: Faulty module compromises smart account
- **Impact**: Critical - full account compromise
- **Likelihood**: Low (requires account owner compromise)
- **Attack Vector**: Install malicious executor module
- **Mitigations**:
  - ✅ Installation requires account owner authorization
  - ✅ Initialization state tracked per account
  - ✅ Module type validation
- **🔍 AUDITOR INFO**:
  - ⚠️ Security depends on ERC7579 account implementation
  - ⚠️ External dependency risk

#### Threat E-4: Operation Execution Manipulation
- **Description**: Malicious operations in targetOps/preClaimOps
- **Impact**: High - could drain user account
- **Likelihood**: Medium (user signs malicious operation)
- **Attack Vector**: User signs order with malicious operation data
- **Mitigations**:
  - ✅ User signature required for all operations
  - ✅ Operations execute from user's account context
  - ✅ Gas stipend limits execution cost
- **🔍 AUDITOR INFO**:
  - ⚠️ No on-chain validation of operation safety (by design - user flexibility)
  - ⚠️ System relies on user understanding risks before signing
  - ⚠️ Gas stipend is only on-chain protection against malicious operations

---

### 5.5 Emissary Layer

#### Threat EM-1: Validator Configuration Manipulation
- **Description**: Attacker manipulates validator configs to bypass validation
- **Impact**: High - unauthorized claims could succeed
- **Likelihood**: Low (requires signature forgery)
- **Attack Vector**: Call `setConfig` with forged signatures
- **Mitigations**:
  - ✅ Dual signature validation (user + allocator)
  - ✅ Nonce-based replay protection per lockTag
  - ✅ Expiry validation
  - ✅ Chain ID validation
  - ✅ EIP-712 typed data hashing

#### Threat EM-2: Nonce Manipulation
- **Description**: Attacker bypasses nonce checks to replay configs
- **Impact**: Medium - could revert to old configuration
- **Likelihood**: Low (nonces must strictly increase)
- **Attack Vector**: Attempt to set config with old nonce
- **Mitigations**:
  - ✅ Strictly increasing nonce: `require(nonce > currentNonce)`
  - ✅ Per-sponsor, per-lockTag nonce tracking
  - ✅ Nonce updated before config storage

#### Threat EM-3: Validator Bypass
- **Description**: Attacker bypasses validator validation in claims
- **Impact**: Critical - unauthorized resource unlock
- **Likelihood**: Very Low (requires storage manipulation)
- **Attack Vector**: Manipulate validator config storage
- **Mitigations**:
  - ✅ Config stored in nested mapping (sponsor → configId → lockTag → validator)
  - ✅ Validator extracted from signed emissaryData
  - ✅ Validator validation returns magic value
- **🔍 AUDITOR INFO**:
  - ⚠️ Security depends on validator implementation
  - ⚠️ External dependency risk (custom validators)

## 6. Cross-Cutting Threats

### 6.1 Signature Replay Across Chains
- **Description**: Signatures valid on one chain replayed on another
- **Impact**: High - unauthorized cross-chain operations
- **Likelihood**: Low (chain ID in signatures)
- **Attack Vector**: Replay signature on different chain
- **Mitigations**:
  - ✅ Chain ID included in EIP-712 domain separator
  - ✅ NotarizedChainId and targetChainId in orders
  - ✅ Permit2 includes chain-specific validation
  - ✅ TheCompact includes chain validation

### 6.2 Front-Running Attacks
- **Description**: Attacker front-runs fill operations to gain advantage
- **Impact**: Medium - could steal MEV or manipulate prices
- **Likelihood**: High (public mempool)
- **Attack Vector**: Monitor mempool and front-run fills
- **Mitigations**:
  - ✅ Atomic fill signature prevents unauthorized execution
  - ✅ Pre-funding model reduces front-run impact
  - ✅ Deadline/expiry enforcement
- **🔍 AUDITOR INFO**:
  - ⚠️ No on-chain protection against solver competition in public mempool
  - ⚠️ Atomic signature prevents unauthorized fills, but not front-running between competing solvers

### 6.3 Gas Griefing
- **Description**: Attacker causes operations to consume maximum gas
- **Impact**: Medium - DOS and increased costs
- **Likelihood**: Medium (depends on operation complexity)
- **Attack Vector**: Craft operations with high gas consumption
- **Mitigations**:
  - ✅ Gas stipend limits for pre-claim operations
  - ✅ minGas requirement prevents insufficient gas attacks
  - ✅ Pre-funding fails fast if insufficient gas
- **🔍 AUDITOR INFO**:
  - ⚠️ No global gas limit per operation
  - ⚠️ Users could craft extremely gas-intensive targetOps

### 6.4 Token Compatibility Issues
- **Description**: Non-standard tokens cause unexpected behavior
- **Impact**: Medium-High - failed transfers or incorrect amounts
- **Likelihood**: Medium (many non-standard tokens exist)
- **Attack Vector**: Use fee-on-transfer, rebasing, or pausing tokens
- **Mitigations**:
  - ✅ SafeTransferLib handles most ERC20 edge cases
  - ✅ Native token handling (Constants.NATIVE_TOKEN)
  - ✅ assertTokenTransfer modifier for validation
- **🔍 AUDITOR INFO**:
  - ⚠️ Fee-on-transfer tokens not explicitly handled (may cause amount discrepancies)
  - ⚠️ Rebasing tokens could cause amount mismatches
  - ⚠️ No on-chain token whitelist or compatibility checks - relies on user token selection

### 6.5 Integer Overflow/Underflow
- **Description**: Arithmetic operations overflow or underflow
- **Impact**: High - could lead to incorrect amounts or DOS
- **Likelihood**: Very Low (Solidity 0.8+ has overflow checks)
- **Attack Vector**: Craft amounts that cause overflow
- **Mitigations**:
  - ✅ Solidity 0.8+ automatic overflow checks
  - ✅ Unchecked blocks only for loop counters and safe operations
  - ✅ Explicit validation for packed gas values

### 6.6 Delegatecall Security
- **Description**: Improper delegatecall usage leads to context confusion
- **Impact**: Critical - could corrupt Router state
- **Likelihood**: Low (strict delegatecall patterns)
- **Attack Vector**: Manipulate delegatecall targets or contexts
- **Mitigations**:
  - ✅ Adapters validated before registration
  - ✅ onlyViaRouter prevents direct adapter calls
  - ✅ Selector validation on returns
  - ✅ No user-controlled delegatecall targets

---

## 7. Data Flow Threats

### 7.1 Fill Operation Flow
```
User Signs Order → Solver Obtains Atomic Sig → Router validates sig →
Adapter pre-funds → Arbiter validates → TheCompact/Permit2 unlock →
Target ops execute → Emit events
```

**Threat Points:**
- Signature validation bypass (R-2, AR-1)
- Pre-funding manipulation (A-2)
- Resource unlock manipulation (AR-3, AR-4)
- Target operation exploitation (AR-2, E-4)

### 7.2 Claim Operation Flow
```
Solver Calls routeClaim → Router routes to adapter →
Adapter calls arbiter → Arbiter unlocks resources → Transfer to relayer
```

**Threat Points:**
- No atomic signature requirement (design choice - enables trustless claiming)
- Resource unlock manipulation (AR-3, AR-4)
- Relayer address manipulation (A-3)
- **🔍 Claim adapter retirement (A-4) - CRITICAL**

**Security Properties:**
- ✅ Claims never paused (by design) - relayers can always recover funds
- ✅ No signature requirement - anyone can trigger claim on behalf of relayer
- ✅ Funds always go to intended relayer (from order parameters)
- ⚠️ Vulnerable to adapter retirement before claim (A-4)

### 7.3 Adapter Installation Flow
```
Admin with ADD_ROLE → installFillAdapter → Validate adapter →
Check interface → Store in registry → Emit event
```

**Threat Points:**
- Compromised admin (R-1)
- Malicious adapter code (A-1)
- Version mismatch attacks
- **🔍 No multi-sig or timelock enforcement**

---

## 8. Threat Severity Matrix

| Threat ID | Component | Description | Impact | Likelihood | Risk | Control Status |
|-----------|-----------|-------------|--------|------------|------|----------------|
| R-1 | Router | Malicious adapter installation | Critical | Low | High | 🔍 Incomplete |
| R-2 | Router | Atomic signature forgery | Critical | Very Low | Medium | ✅ Strong |
| R-3 | Router | Adapter cache poisoning | High | Very Low | Low | ✅ Strong |
| R-4 | Router | Solver context length mismatch | Medium | Medium | Medium | ✅ Strong |
| R-5 | Router | Reentrancy during batch ops | Low | Very Low | Low | ✅ Not exploitable |
| A-1 | Adapter | Delegatecall exploitation | Critical (if SSTORE) | Very Low | Low | ✅ Stateless design |
| A-2 | Adapter | Solver context manipulation | Medium-High | Medium | Medium | 🔍 Incomplete |
| A-3 | Adapter | Return value manipulation | High | Low | Medium | ✅ Strong |
| A-4 | Adapter | **Claim adapter retirement** | **High** | **Low** | **High** | 🔍 Timelock needed |
| AR-1 | Arbiter | Signature validation bypass | Critical | Very Low | Medium | ✅ Strong |
| AR-2 | Arbiter | Pre-claim operation exploitation | High | Medium | High | 🔍 Incomplete |
| AR-3 | Arbiter | TheCompact claim manipulation | High | Low | Medium | ⚠️ External dep |
| AR-4 | Arbiter | Permit2 witness manipulation | High | Low | Medium | ⚠️ External dep |
| AR-5 | Arbiter | Target op execution bypass | High | Low | Medium | 🔍 Incomplete |
| E-1 | Executor | Trusted execution privilege esc | Critical | Low | High | 🔍 **Single point** |
| E-2 | Executor | Nonce reuse/replay | High | Low | Medium | ✅ Strong |
| E-3 | Executor | ERC7579 module attack | Critical | Low | High | ⚠️ External dep |
| E-4 | Executor | Operation execution manipulation | High | Medium | High | 🔍 Incomplete |
| EM-1 | Emissary | Validator config manipulation | High | Low | Medium | ✅ Strong |
| EM-2 | Emissary | Nonce manipulation | Medium | Low | Low | ✅ Strong |
| EM-3 | Emissary | Validator bypass | Critical | Very Low | Medium | ⚠️ External dep |
| EM-4 | Emissary | Compressed storage corruption | High | Very Low | Low | ✅ Strong |

---

## 9. Planned Production Controls

### 🔴 Priority 1 (Planned for Production Deployment)

#### 1. Multi-Sig and Timelock for Adapter Management
**Risk Addressed**: R-1, A-4 (Malicious adapter installation, Claim adapter retirement)

**Current State**:
- ⚠️ ADD_ROLE and RM_ROLE are simple role assignments
- ⚠️ No on-chain enforcement of multi-sig or timelock
- ⚠️ Relies on operational procedures

**Planned Implementation**:
- Multi-sig approval (minimum 3/5) for adapter installation/hotfix
- 24-48 hour timelock for fill adapter changes
- **CRITICAL**: 7-day minimum timelock for `retireClaimAdapter()`
- Public announcement requirement before claim adapter retirement
- On-chain tracking of pending claims per adapter

**Rationale for Claim Adapter Timelock**:
- Relayers in "fill first, claim later" flows need time to process claims
- Cross-chain settlements can take hours to days
- Immediate retirement can permanently lock relayer funds
- 7-day window provides adequate safety margin

**Implementation Approach**:
```solidity
// Pseudocode for claim adapter retirement with timelock
mapping(bytes4 => uint256) public claimAdapterRetirementInitiated;
uint256 public constant CLAIM_ADAPTER_RETIREMENT_DELAY = 7 days;

function initiateClaimAdapterRetirement(bytes4 selector) external onlyRole(RM_ROLE) {
    claimAdapterRetirementInitiated[selector] = block.timestamp;
    emit ClaimAdapterRetirementInitiated(selector, block.timestamp + CLAIM_ADAPTER_RETIREMENT_DELAY);
}

function executeClaimAdapterRetirement(bytes4 selector) external onlyRole(RM_ROLE) {
    require(claimAdapterRetirementInitiated[selector] != 0, "Not initiated");
    require(block.timestamp >= claimAdapterRetirementInitiated[selector] + CLAIM_ADAPTER_RETIREMENT_DELAY, "Timelock active");
    // Proceed with retirement
    _retireClaimAdapter(selector);
}
```

#### 2. Adapter Stateless Design Enforcement
**Risk Addressed**: A-1 (Delegatecall exploitation)

**Current State**:
- ✅ Adapters are designed to be stateless (no SSTORE operations)
- ✅ All adapter state is transient (function-local, calldata, memory)
- ⚠️ Stateless constraint enforced via code review only (no automated checks)

**Planned Implementation**:
- Automated bytecode analysis in CI/CD pipeline to verify no SSTORE opcodes
- Static analysis tooling to enforce stateless adapter pattern
- Formal verification of adapter bytecode to prove no storage writes
- Compiler plugins or custom linters to catch SSTORE at compile time

**Rationale**:
- Current design is secure (stateless adapters cannot corrupt Router storage)
- Automated enforcement prevents accidental introduction of SSTORE in future adapter updates
- Defense-in-depth: Even if malicious adapter is installed, cannot write storage
- Makes security properties verifiable and testable

#### 3. AddressBook Security Hardening
**Risk Addressed**: E-1, AR-5 (Trusted execution privilege escalation)

**Current State**:
- ⚠️ AddressBook is single point of failure for trusted contract whitelist
- ⚠️ No multi-sig or timelock on whitelist changes

**Planned Implementation**:
- Multi-sig (3/5) for trusted contract additions
- 24-hour timelock for whitelist changes
- Emergency pause mechanism if AddressBook compromised

---

## 10. Assumptions and Dependencies

### Security Assumptions

1. **Cryptographic Primitives**: ECDSA is secure, EIP-712 is correctly implemented
2. **Solidity Compiler**: Solidity 0.8+ overflow checks work correctly
3. **EVM Security**: No EVM-level exploits exist
4. **External Protocols**: TheCompact and Permit2 are secure and audited
5. **🔍 Admin Key Management**: Private keys for ADD_ROLE/RM_ROLE are secure (operational control)
6. **🔍 Atomic Fill Signer**: Private key for atomic fill signing is secure (operational control)

### Critical Design Assumption: TheCompact Claim Irrevocability

**🔍 AUDITOR INFO - Fundamental Security Property**

The Rhinestone Compact Utils system relies on a **critical assumption** about TheCompact protocol behavior:

#### Assumption Statement
Once a user signs a compact order, **the claim cannot be stopped or cancelled by the user** until the order expires. This irrevocability is essential for relayer security in "fill first, claim later" flows.

#### Why This Matters
In "fill first, claim later" flows:
1. Relayer pre-funds the recipient on the target chain (funds at risk)
2. User resources are locked in TheCompact settlement layer
3. **If user could cancel** the compact order after relayer pre-funds, relayer loses money
4. System relies on guarantee that user cannot revoke claim permission

#### How Irrevocability is Enforced

**TheCompact Protocol Guarantees**:
- ✅ **Emissary Configuration**: User must sign emissary configuration with allocator approval
- ✅ **Allocator Signature Required**: Both user and allocator must sign to change emissary config
- ✅ **Nonce Consumption**: `consumeNonce()` prevents nonce reuse across different emissary configs
- ✅ **Expiration-Based Validity**: Claims remain valid until order expires (cannot be cancelled early)
- ✅ **No User-Initiated Cancellation**: TheCompact has no mechanism for user to unilaterally cancel active compact

**Protection Mechanism Flow**:
```
1. User signs compact order with expiry time
2. User sets emissary configuration (requires allocator signature)
3. Emissary config includes validator that will approve claims
4. Once set, user cannot change emissary config without allocator approval
5. Allocator (controlled by Rhinestone) will not sign config changes that harm relayers
6. Therefore: claims remain valid until expiry, relayer can always claim
```

#### Security Dependencies

**What Must Be True** (Auditor Verification Points):
1. ✅ TheCompact does not allow user to unilaterally cancel compacts
2. ✅ Emissary config changes require both user + allocator signatures
3. ✅ `consumeNonce()` prevents nonce reuse to bypass emissary config
4. ✅ Validator cannot be changed without allocator approval
5. ✅ Allocator key is controlled by Rhinestone (not user)

**If These Fail**:
- ❌ User could cancel compact after relayer pre-funds
- ❌ Relayer loses pre-funded assets (no claim possible)
- ❌ "Fill first, claim later" flow becomes unsafe
- ❌ System trust model breaks

#### Auditor Action Items

1. **Verify TheCompact Implementation**:
   - Confirm no user-initiated cancellation mechanism exists
   - Verify emissary config changes require allocator signature
   - Check `consumeNonce()` prevents emissary config bypass

2. **Verify Allocator Control**:
   - Confirm allocator key is controlled by Rhinestone, not user
   - Verify allocator will not sign malicious config changes
   - Check key management procedures for allocator private key

3. **Test Claim Irrevocability**:
   - Attempt to cancel compact after signing (should fail)
   - Attempt to change emissary config without allocator (should fail)
   - Attempt nonce reuse to bypass config (should fail)

4. **Review Expiration Handling**:
   - Verify claims work until exact expiry time
   - Confirm no early expiration mechanisms
   - Check clock synchronization assumptions

#### Documentation References

For auditors reviewing this assumption, examine:
- TheCompact protocol: Emissary contract and configuration mechanism
- Allocator signature requirements in emissary `setConfig()`
- `consumeNonce()` implementation and nonce tracking
- Compact expiration validation logic

**Conclusion**: The entire "fill first, claim later" security model depends on TheCompact's guarantee that claims cannot be cancelled by users. This must be thoroughly verified during audit.

### External Dependencies

1. **Solady**: SafeTransferLib, ECDSA, SignatureCheckerLib
2. **TheCompact**: Resource locking and unlocking protocol
3. **Permit2**: Signature-based token approval protocol
4. **OpenZeppelin**: AccessControl
5. **ERC7579**: Smart account module standard

### Trust Dependencies (🔍 AUDITOR INFO)

1. **Adapter Developers**: Must write secure, non-malicious code
   - ⚠️ All adapters developed in-house by Rhinestone
   - ⚠️ No on-chain verification of adapter security

2. **Router Admin (ADD_ROLE)**: Must not install malicious adapters
   - ⚠️ No on-chain multi-sig enforcement
   - ⚠️ Operational control only

3. **RM_ROLE Admin**: Must not prematurely retire claim adapters
   - ⚠️ No on-chain timelock enforcement
   - ⚠️ Planned for production (timelocked governor)

4. **Atomic Fill Signer**: Must not sign malicious batches
   - ⚠️ Private key management is operational control
   - ⚠️ Key compromise enables unauthorized operations

5. **Solvers**: Pre-fund correctly, provide accurate contexts
   - ✅ Protected by atomic revert mechanism
   - ✅ Cannot steal user funds

6. **External Protocols**: Maintain their security properties
   - ⚠️ External dependency risk

---

## 11. Incident Response Considerations

### Emergency Procedures

#### 1. Pause Mechanism
**Trigger**: Suspected fill adapter compromise or atomic signer key compromise

**Actions**:
- `pauseRouter()` stops all fill operations immediately
- Implemented by setting atomic fill signer to address(0)
- **IMPORTANT**: Claim operations continue unaffected (allows relayer fund recovery)

**Design Rationale**:
- ✅ Fills require atomic signature validation (can be paused)
- ✅ Claims do not require atomic signature (cannot and should not be paused)
- ✅ Ensures relayers can always claim their funds even during emergency

**Limitations**:
- Only affects fill operations via `optimized_routeFill921336808()`
- Claims via `routeClaim()` are **never paused** (by design)
- Users can still execute intents via Executor directly
- Requires ADD_ROLE to execute

**Security Property**: Relayer funds are never locked, even during emergency pause

#### 2. Fill Adapter Retirement
**Trigger**: Malicious or faulty fill adapter detected

**Actions**:
- `retireFillAdapter()` removes compromised adapter
- Requires RM_ROLE
- Immediate effect (no pending state)

**Safe to Execute**: Fill adapters don't have pending claims

#### 3. Claim Adapter Retirement
**Trigger**: Malicious or faulty claim adapter detected

**🔴 CRITICAL RISK**: Cannot retire claim adapter immediately without stranding relayer funds

**Required Process** (Planned for Production):
1. **T-14 days**: Public disclosure of intent to retire claim adapter
2. **T-14 to T-7**: Monitor pending claims for adapter
3. **T-7**: Initiate retirement via timelocked governor
4. **T-7 to T-0**: Grace period for relayers to process claims
5. **T-0**: Adapter retirement takes effect

**Emergency Override** (If adapter is critically compromised):
- Emergency multisig can force immediate retirement
- Requires 4/5 signatures + documented justification
- Relayers with pending claims compensated from protocol treasury
- Post-mortem and compensation process documented

#### 4. Hotfix Process
**Trigger**: Non-critical bug or improvement needed

**Actions**:
- Semantic versioning ensures safe patches
- `hotfixFillAdapter()` for urgent fixes
- Limited to patch-level changes (0.0.X)
- Major/minor version changes require new installation

**Limitations**:
- Still requires ADD_ROLE
- No multi-sig enforcement (🔍 operational control)

---

### Monitoring Points

1. **Unexpected Adapter Installations**:
   - Alert on new adapter registrations
   - Verify adapter code matches audited version

2. **Failed Fill Operations**:
   - High failure rate may indicate attack or bug
   - Monitor for signature validation failures

3. **Large Value Transfers**:
   - Monitor for abnormal transfer amounts
   - Flag transfers above threshold for review

4. **Gas Anomalies**:
   - Detect gas griefing attempts
   - Monitor for unusually high gas consumption

5. **Nonce Gaps**:
   - Detect nonce manipulation attempts
   - Alert on unexpected nonce jumps

6. **Signature Failures**:
   - High rate may indicate attack attempts
   - Could signal atomic signer key rotation needed

7. **🔍 Pending Claims Per Adapter**:
   - Track unfulfilled claims for each claim adapter
   - Alert if retirement initiated while pending claims exist
   - Dashboard showing claim settlement rates

---

## 12. Summary for Auditors

### Overall Security Posture: **Strong with Identified Gaps**

The Rhinestone Compact Utils implements a sophisticated multi-layered security model with strong cryptographic foundations. The system demonstrates defense-in-depth with multiple security controls.

---

### ✅ Strong Security Controls

1. **Cryptographic Security**: EIP-712 signatures, nonce protection, replay prevention
2. **Atomic Execution**: Pre-funding model with atomic revert protects users and solvers
3. **Reentrancy Protection**: TransientReentrancyGuard on all entry points
4. **Access Control**: Role-based permissions for critical operations
5. **External Protocol Integration**: Uses battle-tested Compact and Permit2

---

### 🔍 Critical Gaps Requiring Auditor Focus

#### **Gap 1: Adapter Stateless Design Pattern**
- **Issue**: Adapters execute via delegatecall with technical ability to write Router storage
- **Impact**: Malicious adapter could corrupt Router state (if it performed SSTORE)
- **Current Control**: **Stateless adapter design pattern** - adapters do not use SSTORE operations
- **Verification Points**:
  - 📋 Verify all adapters follow stateless pattern (no SSTORE in bytecode)
  - 📋 Confirm code review process enforces stateless constraint
  - 📋 Planned: Automated bytecode analysis in CI/CD to enforce no-SSTORE rule

#### **Gap 2: Claim Adapter Retirement**
- **Issue**: No on-chain timelock for claim adapter retirement
- **Impact**: Relayers lose funds in fill-first flows if adapter retired before claim
- **Current Control**: Planned operational procedures (not enforced on-chain)
- **Planned**: 7-day minimum on-chain timelock with pending claim tracking for production

#### **Gap 3: AddressBook Single Point of Failure**
- **Issue**: Trusted execution depends on AddressBook integrity
- **Impact**: Compromised AddressBook enables privilege escalation
- **Current Control**: Access control only
- **Planned**: Multi-sig + timelock for whitelist changes in production

#### **Gap 4: Multi-Sig Not Enforced for Admin Roles**
- **Issue**: ADD_ROLE and RM_ROLE are simple role assignments
- **Impact**: Single key compromise enables malicious adapter installation
- **Current Control**: Operational procedures (off-chain)
- **Planned**: On-chain multi-sig requirement (3/5 minimum) for production

#### **Gap 5: Operational Controls for Critical Security**
- **Issue**: Atomic signer key management, admin multi-sig are operational controls
- **Impact**: Security depends on off-chain procedures
- **Current Control**: Internal operational security
- **Verification Points**: Auditors should review operational security documentation

---

### Key Auditor Questions

1. **Adapter Stateless Design**: Verify all adapters contain no SSTORE opcodes in bytecode. Is there automated enforcement?
2. **Claim Retirement**: What protects relayers from fund loss during claim adapter retirement? Is timelock implemented on-chain?
3. **Multi-Sig Enforcement**: Is multi-sig enforced on-chain for ADD_ROLE/RM_ROLE or only operational procedure?
4. **Timelock Implementation**: Is the planned timelock for RM_ROLE implemented and tested? What is the minimum delay?
5. **AddressBook Security**: What controls prevent AddressBook compromise? Is multi-sig required for whitelist changes?
6. **Atomic Signer Key**: How is the atomic signer private key secured and rotated? Is there a key rotation process?
7. **Adapter Vetting**: What is the formal process for vetting adapter code before installation? Who reviews?
8. **Pending Claim Tracking**: Is there a mechanism to track unfulfilled claims per adapter before retirement?
9. **Stateless Enforcement**: What prevents future adapter updates from introducing SSTORE operations?
10. **Pause Mechanism**: Confirm that `pauseRouter()` only affects fills and claims remain operational during pause.

---

### Production Deployment Readiness Checklist

Items planned for production deployment:

1. 📋 On-chain timelock for claim adapter retirement (minimum 7 days)
2. 📋 Multi-sig (3/5 minimum) for ADD_ROLE and RM_ROLE
3. 📋 Automated bytecode analysis to enforce adapter stateless design (no SSTORE)
4. 📋 Multi-sig + timelock for AddressBook updates
5. 📋 Documented atomic signer key management procedures
6. 📋 Pending claim tracking mechanism
7. 📋 Emergency response playbook with relayer compensation process
8. 📋 Comprehensive monitoring and alerting
9. 📋 Static analysis in CI/CD to prevent SSTORE in future adapter updates

Items under consideration:
10. Formal verification of critical paths
11. Token whitelist or enhanced UI warnings for non-standard tokens

---

## End of Threat Model

**Document Version**: 1.0 (Auditor Focused)
**Last Updated**: 2025-10-07
**Prepared By**: Rhinestone Security Team
**Intended Audience**: External Security Auditors
