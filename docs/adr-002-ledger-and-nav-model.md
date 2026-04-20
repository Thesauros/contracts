# ADR-002 Ledger and NAV Model

Current as of **2026-03-18**.

## Title

`ADR-002: Ledger and NAV Model`

## Status

`Proposed`

## Date

`2026-03-18`

## Related Documents

- [Hybrid Cross-Chain Vault Architecture](hybrid-crosschain-vault-architecture.md)
- [Cross-Chain Vault Spec](crosschain-vault-spec.md)

## Context

For a hybrid cross-chain vault, it is not enough to store only local ERC4626 state. A user can enter on one chain while capital is:

- partially in a local liquidity buffer;
- partially deployed in a remote strategy;
- partially in bridge transit;
- partially reserved for a pending withdrawal;
- partially represented by the last accepted strategy report rather than an immediately readable remote balance.

The core problem is:

- there is no reliable fully on-chain real-time valuation method across chains;
- at the same time the product must show the user a single balance and a single NAV.

We therefore need a model that separates:

- what is enforced on-chain;
- what is tracked off-chain;
- what is used for user-visible accounting;
- what is used for risk and operations.

## Decision

The chosen model is:

- the **on-chain vault** remains the place for custody, share accounting, and execution gating;
- the **off-chain ledger** becomes the source of truth for the global cross-chain position state;
- **NAV** is treated as a managed number based on on-chain balances, strategy reports, bridge states, and policy rules;
- the **user-visible balance** is derived from the ledger plus the latest accepted NAV snapshot, not from ad hoc raw remote polling;
- **bridge in-flight capital** is accounted for explicitly and preserved across source and destination phases;
- all valuation-critical updates flow through explicit report / settlement steps.

## Core Principles

### 1. Single Economic Position

The user has one economic position in the product even if capital is distributed across several chains.

### 2. Separation of Concerns

The on-chain layer is responsible for:

- custody;
- shares;
- permissions;
- withdrawal request ownership;
- settlement hooks.

The off-chain layer is responsible for:

- the global ledger;
- NAV calculation;
- bridge lifecycle tracking;
- historical chain residency;
- reconciliation.

### 3. Snapshot-Based Valuation

NAV is not calculated as a fully synchronous real-time on-chain truth across all chains. Instead, the system uses a snapshot/report model based on:

- strategy reports;
- bridge state updates;
- accepted settlement checkpoints;
- policy-driven staleness thresholds.

### 4. Explicit Staleness Handling

If strategy reports become stale, the system must degrade predictably:

- instant withdrawal capacity may be restricted;
- new rebalances may be restricted;
- sensitive actions may be paused until state is refreshed.

## Source of Truth Model

### On-Chain Source of Truth

On-chain is authoritative for:

- user share balances;
- vault asset custody on the entry / home side;
- queued withdrawal ownership;
- accepted strategy states after settlement;
- role-controlled execution rights.

### Off-Chain Source of Truth

The off-chain ledger is authoritative for:

- global user position history;
- chain residency history;
- pending bridge lifecycle;
- NAV composition by bucket;
- reporting and reconciliation state;
- product-level analytics and user-facing portfolio interpretation.

### Reconciliation Rule

If on-chain and off-chain data diverge:

- custody and shares are taken from on-chain;
- portfolio composition and historical attribution are reconstructed in the ledger;
- unresolved mismatch becomes an incident state;
- user-visible balances in degraded mode must use a conservative valuation policy.

## NAV Composition

Global NAV should consist of the following buckets:

1. `homeIdle`
2. `local buffers`
3. `lastReportedValue` for active strategies
4. `pendingBridgeIn`
5. `pendingBridgeOut`
6. `unrealizedLossBuffer`
7. `fees payable but not yet collected`
8. `withdrawal obligations already funded but not yet claimed`

Simplified formula:

```text
Global NAV =
    homeIdle
  + sum(localBuffers)
  + sum(lastReportedStrategyValue)
  + sum(pendingBridgeIn)
  + sum(pendingBridgeOut)
  - sum(unrealizedLossBuffers)
  - accruedFeesNotCollected
```

### Important Rule

`pendingBridgeIn` and `pendingBridgeOut` must not double-count the same capital. The ledger must maintain a bridge state machine and know when value has left the source side and when it is recognized on the destination side.

## User Accounting Model

### Share Model

For the first stage, we assume:

- one share class per product-facing vault entry contract;
- share price is determined from accepted NAV;
- user ownership on-chain is represented by shares;
- global portfolio attribution is built off-chain.

This means:

- shares live on-chain;
- global economic interpretation of shares lives in the ledger.

### User Position View

The user view should display:

- owned shares;
- current asset equivalent;
- pending withdrawal amount;
- delayed redemption status;
- optional informational breakdown by chain or strategy.

The canonical user balance for UX remains one product balance, not a raw list of balances by chain.

## Historical Attribution

The ledger should store at minimum the following events:

- deposit accepted;
- shares minted / burned;
- withdrawal requested / funded / claimed;
- operation created / sent / received / executed / settled;
- strategy report accepted;
- bridge asset sent;
- bridge asset received;
- recall completed;
- emergency state changes.

This is required for:

- reconstructing chain residency history;
- period-based yield attribution;
- explainable NAV;
- post-mortem analysis;
- audit trail generation.

## Strategy Report Model

For each strategy the ledger and vault use the latest accepted report:

- `totalValue`
- `freeLiquidity`
- `totalDebt`
- `reportTimestamp`
- `positionsHash`

### Report Acceptance Rules

- the report must belong to the expected chain and strategy;
- the timestamp must be monotonic;
- a stale report must not replace a fresher one;
- stale strategy state should degrade withdrawal and rebalance semantics.

## Bridge State Model

Each bridge operation should have a lifecycle state:

- `Created`
- `Sent`
- `Received`
- `Executed`
- `Settled`
- `Cancelled`
- `Failed`

For every operation the ledger stores:

- source chain;
- destination chain;
- strategy id;
- asset;
- nominal amount;
- minimum expected amount out;
- timestamps for each stage;
- fees and loss adjustments;
- correlation ids with the bridge provider.

## Conservative Valuation Policy

If the system is uncertain about exact remote value, valuation must be conservative:

- it must not overstate user-withdrawable value;
- it must not assume bridge completion before explicit receive/settle confirmation;
- it must apply stale report guardrails;
- it must account for unrealized loss buffers until explicitly cleared.

## Contract Implications

For the current `contracts` repository, this means:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol) should calculate `totalAssets()` only from local state plus settled strategy state;
- [`contracts/crosschain/ReportSettler.sol`](../contracts/crosschain/ReportSettler.sol) remains the entry point for accepted strategy reports;
- [`contracts/crosschain/StrategyRegistry.sol`](../contracts/crosschain/StrategyRegistry.sol) stores compact on-chain strategy state;
- the off-chain ledger must be a real system component, not just an event indexer.

## Non-Goals

This decision does not attempt to:

- create fully trustless instantaneous global valuation;
- store full historical analytics on-chain;
- build user-facing accounting solely from raw chain reads;
- support a multi-class cross-chain share token in the first stage.

## Risks

- a backend ledger bug can distort user-visible balances;
- incorrect bridge state mapping can produce double counting or missing accounting;
- stale report policy can either block UX too early or accept stale state too late;
- reconciliation complexity will grow quickly with chains and strategies.

## Consequences

Advantages:

- realistic valuation model for a hybrid product;
- explainable NAV;
- controlled degraded mode;
- direct compatibility with delayed redemption and routing.

Trade-offs:

- strong dependency on backend data quality;
- disciplined reporting and reconciliation become mandatory;
- accounting incidents become a first-class risk category.

## Open Questions

- Do we need explicit ledger snapshot versioning?
- What staleness threshold is acceptable per chain and strategy type?
- How should in-flight bridge capital be displayed in UI?
- Should the system separately track optimistic NAV and settled NAV?
- What audit format is required for ledger replay?

## Follow-up Work

- `ADR-003 Redemption SLA and Liquidity Buffers`
- `ADR-004 Rebalancing Policy and Risk Limits`
- detailed ledger event and snapshot schema
- reconciliation runbook
