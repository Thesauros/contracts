# Cross-Chain Vault: Implementation Specification

## Note

This document predates the current hybrid architecture package.
If it conflicts with:

- `Hybrid Cross-Chain Vault Architecture`
- `ADR-002 Ledger and NAV Model`
- `ADR-003 Redemption SLA and Liquidity Buffers`
- `Cross-Chain Vault Development Plan`

then the newer ADRs and the development plan take precedence.

In particular, wording about a `single-home-chain vault` should be interpreted as an early accounting anchor / implementation profile, not as the final product architecture.

## 1. Goal

Implement a `single-accounting-anchor vault` for one base asset where:

- the canonical user shares ledger exists only on the accounting side;
- vault liquidity may move across supported chains;
- positions and strategies may be opened, managed, and closed on remote chains;
- user accounting, mint/burn of shares, NAV, and withdrawal settlement remain tied to the accounting side;
- remote contracts never become the source of truth for user balances.

## 2. Context and Constraints

- First version supports a single settlement asset.
- The accounting-side vault must remain ERC4626-compatible.
- Cross-chain execution is asynchronous.
- Withdrawals do not have to be instant if liquidity is remote.
- Remote contracts must not mutate user balances or share price directly.
- Cross-chain transport must remain a replaceable module rather than core vault business logic.

### 2.1 Transport Stack for v1

For the first implementation, the transport stack is fixed as:

- `LayerZero V2` for messaging
- `Stargate V2` for settlement asset transfer

The transport abstraction is preserved so the transport implementation can be replaced later without migrating the accounting core.

## 3. Problems to Solve

### 3.1 Problems in the Current `contracts` Layer

The current single-chain vault stack solves:

- ERC4626 accounting;
- on-chain shares;
- fee/governance logic;
- single-chain rebalance.

But it does not solve:

- asynchronous capital movement between chains;
- accounting of `assets in transit`;
- remote execution and delayed settlement;
- stale NAV for remote strategies.

### 3.2 Problems in Legacy Router-Based Designs

Legacy router-based designs tend to:

- use relayer-supplied TVL to calculate shares;
- use relayer-supplied price for withdrawals;
- mix user ledger, bridge orchestration, and liquidity routing;
- make relayers a critical trust anchor for accounting;
- break ERC4626 accounting discipline.

These assumptions must not be carried forward into the target system as-is.

## 4. Target System Structure

The system is divided into two high-level planes:

1. `Accounting Plane`
2. `Execution Plane`

### 4.1 Accounting Plane

Consists of:

- `CrossChainVault` as accounting core / share source of truth
- `StrategyAllocator`
- `StrategyRegistry`
- `WithdrawalQueue`
- `ReportSettler`
- `BridgeAdapter`

### 4.2 Execution Plane

Consists of:

- `RemoteStrategyAgent`
- `StrategyAdapter`
- optional `RemoteEscrow`
- optional remote risk modules

### 4.3 Architectural Principle

- `CrossChainVault` knows only aggregate strategy state.
- `RemoteStrategyAgent` knows only local execution state.
- Users never interact with remote contracts directly.
- Remote execution never mints or burns shares.
- Any user accounting change happens only in the accounting-side vault.

## 5. Contract Set

### 5.1 `CrossChainVault`

Responsibilities:

- accept deposits;
- mint / redeem shares;
- calculate `totalAssets()`;
- hold idle liquidity on the accounting side;
- initiate allocate / recall through the allocator;
- execute instant withdrawals or enqueue delayed requests.

Required properties:

- ERC4626 inheritance;
- pause controls;
- fee model;
- timelock / governance support;
- support for assets in transit;
- stale report protection.

Must not:

- directly manage remote protocols;
- directly read remote state;
- depend on a relayer for share calculation.

### 5.2 `StrategyRegistry`

Responsibilities:

- register strategies;
- map `strategyId -> metadata`;
- store limits and statuses;
- store chain and routing configuration.

Required config fields:

- `strategyId`
- `chainId`
- `agent`
- `asset`
- `debtLimit`
- `maxSlippageBps`
- `maxReportDelay`
- `depositsEnabled`
- `withdrawalsEnabled`
- `emergencyExitOnly`
- `kind`

Required state fields:

- `currentDebt`
- `lastReportedValue`
- `pendingBridgeIn`
- `pendingBridgeOut`
- `freeLiquidity`
- `unrealizedLossBuffer`
- `lastReportTimestamp`
- `lastAckTimestamp`
- `health`

### 5.3 `StrategyAllocator`

Responsibilities:

- allocate funds from vault to remote strategy;
- recall funds back;
- track operation lifecycle;
- reconcile bridge and report confirmations.

Rules:

- allocator never mints/burns shares;
- allocator must not modify user balances;
- allocator must update `pendingBridgeOut`, `pendingBridgeIn`, and debt state;
- allocator must work through explicit `operationId`.

### 5.4 `WithdrawalQueue`

Responsibilities:

- store withdrawal requests that cannot be executed instantly;
- reserve withdrawal intent and state;
- allow funded requests to be claimed after liquidity returns home.

Required request fields:

- `requestId`
- `owner`
- `receiver`
- `shares`
- `assetsPreview`
- `createdAt`
- `status`

### 5.5 `ReportSettler`

Responsibilities:

- accept reports from remote strategies;
- validate freshness;
- update strategy state;
- feed `totalAssets()` through settled reporting.

Required report fields:

- `strategyId`
- `chainId`
- `totalValue`
- `freeLiquidity`
- `totalDebt`
- `pnl`
- `reportTimestamp`
- `positionsHash`

Report requirements:

- reject reports older than `maxReportDelay`;
- reject reports with invalid `strategyId / chainId`;
- use a signer / attestation policy;
- keep report application idempotent.

### 5.6 `BridgeAdapter`

Responsibilities:

- abstract cross-chain transport;
- send asset and payload;
- accept acks / settlement updates;
- isolate the bridge vendor from accounting logic.

For v1:

- one bridge provider is acceptable;
- transport replacement must not require vault migration.

### 5.7 `RemoteStrategyAgent`

Responsibilities:

- receive bridged capital;
- execute allocator commands;
- hold local idle balance if needed;
- call the local strategy adapter;
- produce reports and acknowledgements;
- return liquidity home.

Required properties:

- only authorized messenger / bridge / governance flows;
- idempotent command handling;
- local slippage and execution limits.

### 5.8 `StrategyAdapter`

Responsibilities:

- protocol-specific execution logic for strategies such as Aave, Morpho, Compound, and later others;
- a unified adapter interface for the remote agent.

Current provider implementations in the repo should be treated as references for this layer.

## 6. Asset Accounting Model

### 6.1 Source of Truth

The single source of truth for user balances remains:

- the accounting-side vault shares ledger

Users are never accounted for in remote contracts.

### 6.2 `totalAssets()` Requirements

`totalAssets()` should include:

- idle asset on the accounting side;
- accepted `lastReportedValue` from strategies;
- `pendingBridgeIn` when value is confirmed in transit home;
- `pendingBridgeOut` when value has left idle but not yet settled at destination;
- minus known fees and realized losses.

The main rule:

- `pendingBridgeOut` and `pendingBridgeIn` must be counted exactly once;
- double counting is forbidden;
- operation state transitions must preserve conservation of capital.

### 6.3 Debt Model

For each strategy:

- `currentDebt` = capital allocated to the strategy
- `lastReportedValue` = actual value according to latest accepted report
- strategy-level `PnL = lastReportedValue - currentDebt`

This debt model replaces legacy relayer-driven share accounting approaches.

## 7. User Flows

### 7.1 Deposit

1. User calls `deposit(assets, receiver)` in the accounting-side vault.
2. Vault calculates shares from accepted `totalAssets`.
3. User receives shares immediately.
4. Funds remain in local idle liquidity initially.
5. Allocator later sends part of idle liquidity into remote strategies.

Requirements:

- deposit must not wait for bridge completion;
- deposit must not depend on remote finality.

### 7.2 Instant Withdrawal

1. User calls `withdraw` or `redeem`.
2. If local idle liquidity is enough, withdrawal executes immediately.
3. Share burn occurs only on the accounting side.

### 7.3 Queued Withdrawal

1. If local idle liquidity is not enough, request enters `WithdrawalQueue`.
2. Shares are reserved / locked according to vault logic.
3. Allocator initiates recall from one or more strategies.
4. Once capital returns home, request becomes `Funded`.
5. User or keeper completes claim.

### 7.4 Allocate to Remote Strategy

1. Governance / allocator chooses the strategy.
2. Caps, slippage, health, and report freshness are checked.
3. Idle asset is reserved.
4. `Operation` is created.
5. Bridge sends asset plus command.
6. Agent confirms receipt.
7. Agent deploys capital through strategy adapter.
8. After ack / deploy, operation becomes `Settled`.

### 7.5 Recall from Remote Strategy

1. Allocator initiates recall.
2. Agent unwinds part of the position or extracts idle liquidity.
3. Agent bridges asset back home.
4. Home side receives funds and settles the operation.
5. Capital becomes local idle liquidity again.

### 7.6 Emergency Exit

1. Governance / guardian switches strategy to `emergencyExitOnly`.
2. New allocations are forbidden.
3. Agent closes allowed positions.
4. Available funds are sent home.
5. Strategy moves to `Paused` or `Deprecated`.

## 8. Roles

Required roles include:

- `GOVERNANCE_ROLE`
- `KEEPER_ROLE`
- `REPORTER_ROLE`
- `GUARDIAN_ROLE`
- `VAULT_ROLE`
- `BRIDGE_ROLE` or equivalent trusted messenger role

Role rights should cover:

- adding / removing strategies;
- changing caps;
- changing bridge adapter;
- changing report policy;
- emergency pause / exit behavior.

## 9. Invariants

Mandatory invariants for implementation and testing:

- shares exist only on the accounting side;
- remote contracts never mint / burn shares;
- `totalAssets()` must not double-count bridge state;
- accepted reports must not increase assets without a valid source of truth;
- withdrawals cannot pay out more than allowed by user shares;
- each `opId` executes at most once;
- one bridge ack cannot settle more than one operation;
- `pendingBridgeOut` and `pendingBridgeIn` converge to zero after settlement;
- final state operations cannot return to non-final states;
- stale reports cannot silently distort NAV;
- unauthorized callers cannot trigger allocate / recall / report updates;
- replayed commands must not mutate state;
- emergency pause must block risky new actions.

## 10. Reporting and NAV Requirements

Each strategy must define:

- report freshness threshold;
- acceptable valuation source;
- allowed variance policy;
- stale behavior policy.

If a report is stale:

- new allocations into that strategy are forbidden;
- large withdrawals may be forced into queue;
- governance / guardian should receive an alert;
- product behavior should follow conservative valuation assumptions.

Report acceptance requirements:

- signer is authorized;
- `reportTimestamp` is monotonic;
- deviation stays within acceptable bounds or requires explicit override;
- strategy is not hard-paused.

## 11. Bridge Layer Requirements

- Bridge logic must not be hard-coded into `CrossChainVault`.
- Bridge logic must be implemented through an adapter.
- Each cross-chain command must include:
  - version
  - `opId`
  - `strategyId`
  - command type
  - amount
  - timestamp
  - params
- replay protection is required;
- failure path for unsuccessful delivery is required.

For v1:

- LayerZero V2 handles messaging;
- Stargate V2 handles settlement asset transfer;
- `LayerZeroBridgeAdapter` maps internal chain identifiers to transport-specific ids;
- only explicit trusted peers are allowed.

## 12. Remote Adapter Requirements

Adapters should support, where relevant:

- deposit / supply;
- withdraw / recall;
- harvest;
- reporting of `totalValue` and `freeLiquidity`;
- debt-aware execution constraints;
- emergency unwind hooks.

The first-stage strategy profile should remain lending-first.

## 13. Upgradeability

Upgradeable components may include:

- remote agents;
- strategy adapters;
- bridge adapters;
- some registry / control modules if needed.

`CrossChainVault` may be:

- immutable core plus mutable modules;
- or upgradeable proxy, but only if storage layout discipline and governance process are mature enough.

For all upgradeable contracts:

- storage gaps / disciplined layouts are required;
- upgrade authorization must be explicit;
- layout review is required before each upgrade.

## 14. Events

Minimum event set should cover:

- operation creation / status changes;
- withdrawal queued / funded / claimed;
- strategy report accepted;
- bridge asset sent / received;
- command sent / received / acknowledged;
- emergency status changes.

## 15. Trust Assumptions

The system must be designed so that:

- bridge / operator does not control shares;
- reporter cannot arbitrarily fabricate NAV;
- remote agent cannot create vault obligations on its own;
- governance can stop the system and bring capital home.

Allowed in the first stage:

- operational trust in backend orchestration;
- explicit governance / guardian controls;
- trusted reporting policy.

Not allowed in the first stage:

- permissionless strategy listing;
- remote user accounting;
- uncontrolled bridge-driven state changes.

## 16. Test Plan

### Unit Tests

Cover:

- deposit / redeem / withdraw with idle liquidity;
- queued withdrawal behavior;
- report acceptance and staleness;
- operation state transitions;
- pending bridge accounting.

### Integration Tests

Cover:

- allocate to remote agent and recall back;
- settlement lifecycle;
- queued withdrawal during illiquid home vault state;
- bridge failure path.

### Invariant Tests

Check:

- assets do not disappear without explicit loss;
- shares never change outside deposit/mint/withdraw/redeem flows;
- final operations do not re-execute;
- `totalAssets()` does not double-count transit balances.

### Fork Tests

Needed for:

- Aave;
- Morpho;
- Compound where relevant;
- other EVM strategies as they enter scope.

## 17. Implementation Stages

### Stage 1. Accounting Core

Build:

- base `CrossChainVault`;
- `StrategyRegistry`;
- `WithdrawalQueue`;
- `ReportSettler`;
- unit tests without real bridge.

Ready when:

- debt accounting works;
- queue works;
- instant and queued withdrawal are covered by tests.

### Stage 2. Bridge and Settlement

Build:

- bridge adapter;
- remote agent baseline;
- allocate / recall lifecycle;
- pending transit accounting.

Ready when:

- allocate / recall completes the full cycle;
- transit accounting does not break `totalAssets()`.

### Stage 3. Strategy Adapters

Build:

- first adapters;
- unified reporting surface;
- fork-tested execution.

Ready when:

- strategies can be called through one agent interface;
- each strategy returns `totalValue / freeLiquidity`.

### Stage 4. Hardening

Build:

- risk controls;
- stale NAV policy;
- incident handling;
- audit package.

## 18. Non-Goals for v1

First version does not include:

- fully trustless real-time NAV proofs;
- cross-chain user share tokens;
- direct remote-chain user deposits with instant mint on the accounting side;
- permissionless strategy onboarding;
- fully autonomous cross-chain orchestration;
- an always-instant withdrawal promise.

## 19. Delivery Artifacts

The implementation should produce:

- accounting plane contract set;
- execution plane contract set;
- bridge / reporting interfaces;
- test suite;
- deployment and incident runbooks.

## 20. Acceptance Criteria

The implementation is compliant with the specification if:

- one accounting-side vault remains the sole source of truth for shares;
- remote strategies do not maintain user accounting;
- `totalAssets()` correctly accounts for idle, reported debt/value, and transit state;
- queued withdrawal executes correctly under home-side liquidity shortage;
- allocate / recall use an idempotent operation state machine;
- stale / invalid report cannot distort NAV;
- emergency exit can unwind remote exposure and bring capital home.
