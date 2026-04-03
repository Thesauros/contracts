# Cross-Chain Vault: Development Plan

Current as of **2026-04-02**.

This plan is based on the target hybrid architecture:

- chain-specific user entry;
- global accounting and NAV;
- routing / booster / buffer layer;
- hybrid transfer and settlement;
- modular remote execution;
- delayed redemption with liquidity buffers.

## 1. Plan Objective

Build not just a bridge-enabled vault, but **a unified cross-chain yield product** where:

- the user enters through their local entry point;
- the system decides the execution path internally;
- NAV is calculated centrally and remains explainable;
- withdrawals use instant-or-delayed semantics;
- the execution layer is modular and replaceable.

## 2. What Is Already Done

The previous iteration remains the foundation:

- `CrossChainVault`
- `StrategyRegistry`
- `StrategyAllocator`
- `ReportSettler`
- `WithdrawalQueue`
- `CrossChainAccessControl`
- `CrossChainTypes`
- basic unit and mock tests for accounting / reports / queued withdrawal

How this is interpreted now:

- it is **not a complete product**;
- it is **foundation for the accounting and control plane**;
- it is **not a bridge-first implementation**, but a reusable base for the correct architecture.

## 3. Main Planning Shift

The old implicit order was closer to:

1. accounting core
2. bridge messaging
3. asset transport
4. remote strategy integration

The correct order is now:

1. architecture and semantics
2. ledger and NAV
3. redemption and liquidity buffers
4. entry layer
5. routing and operation lifecycle
6. transfer and settlement
7. remote execution
8. rebalancing policy and risk limits
9. hardening and production readiness

This means:

- first define **what the product promises**;
- then define **how it calculates and pays out**;
- only then finish transport and execution details.

## 4. Delivery Format

The plan assumes `9 sprints` of `2 weeks` each.

Assumptions:

- 2 smart contract engineers;
- 1 backend engineer;
- 1 architect / protocol reviewer;
- 1 QA/SDET part-time from the integration stage onward;
- optional DevOps support starting at testnet rollout.

## 5. Workstreams

Work proceeds in four parallel streams:

### Stream A. Product and Semantics

- architecture docs;
- ADRs;
- user-facing semantics;
- redemption promises;
- risk boundaries.

### Stream B. On-Chain Control Plane

- vault entry logic;
- accounting state;
- registry;
- allocator;
- withdrawal queue;
- bridge adapters;
- remote agents.

### Stream C. Backend and Ledger

- ledger schema;
- NAV calculation;
- reconciliation;
- redemption orchestration;
- operations state tracking.

### Stream D. Risk, QA, and Release

- invariants;
- replay and incident scenarios;
- testnet rehearsal;
- audit preparation;
- release controls.

## 6. Milestones

### Milestone A. Semantics Locked

Done when:

- architecture package is approved;
- source of truth is fixed;
- withdrawal semantics are agreed;
- glossary is stable.

### Milestone B. Accounting Core Locked

Done when:

- NAV buckets are fixed;
- report staleness policy is fixed;
- bridge in-flight accounting is fixed;
- backend ledger schema is approved.

### Milestone C. Redemption Model Locked

Done when:

- instant vs delayed semantics are fixed;
- funding order is fixed;
- buffer policy is fixed;
- degraded mode is fixed.

### Milestone D. Routing and Transfer MVP

Done when:

- operation lifecycle works;
- bridge settlement is integrated;
- transfer state is reflected in accounting;
- failure states are visible and recoverable.

### Milestone E. Execution MVP

Done when:

- at least 2 strategies complete the full lifecycle;
- remote execution does not mutate user shares;
- strategy reporting feeds NAV correctly.

### Milestone F. Release Candidate

Done when:

- end-to-end flows pass;
- hardening is complete;
- audit package is ready;
- testnet rehearsal is passed.

## 7. Sprint Plan

## Sprint 1. Architecture Freeze

### Status

`Completed on 2026-04-01`

### Goal

Lock product semantics and eliminate conflict between the old and new architectures.

### Scope

- approve `ADR-001`, `ADR-002`, `ADR-003`;
- align terminology:
  - `EntryVault`
  - `LiquidityBuffer`
  - `Booster / Routing layer`
  - `Transfer and Settlement layer`
  - `Execution layer`
  - `Delayed redemption`;
- define MVP chains;
- define MVP strategies;
- define target redemption promise;
- define on-chain vs off-chain ownership boundaries.

### Deliverables

- signed architecture package;
- architecture glossary;
- MVP scope memo.

### Exit Criteria

- no open contradictions remain around source of truth;
- the product is explicitly not promising strict instant withdrawal;
- `contracts/crosschain` is explicitly recorded as foundation, not final shape.

### Closeout Record

- [Sprint 1 Closeout](crosschain-vault-sprint-1-closeout.md)

## Sprint 2. Ledger and NAV Foundation

### Status

`Completed on 2026-04-02`

### Goal

Make the accounting model suitable for the real hybrid product.

### Scope

- revise `CrossChainVault` for entry/accounting semantics;
- revise `StrategyRegistry` and `ReportSettler`;
- fix NAV buckets:
  - home idle
  - local buffers
  - settled strategy value
  - pending bridge in
  - pending bridge out
  - unrealized loss buffer
  - funded withdrawal obligations;
- define stale report policy;
- define backend ledger event schema;
- define reconciliation boundaries.

### Deliverables

- updated accounting interfaces;
- ledger event catalogue;
- NAV bucket model.

### Exit Criteria

- `totalAssets()` does not double-count transit state;
- stale strategy state has explicit policy;
- backend ledger can reconstruct product NAV from approved inputs.

### Closeout Record

- [Sprint 2 Closeout](crosschain-vault-sprint-2-closeout.md)

## Sprint 3. Redemption and Buffer Semantics

### Status

`Completed on 2026-04-02`

### Goal

Make withdrawal behavior a first-class product component.

### Scope

- revise `WithdrawalQueue`;
- define `instant vs delayed` rules;
- define funding order;
- define minimum residual liquidity rules;
- define normal vs degraded mode;
- define `fund` and `claim` hooks;
- define requirements for the redemption orchestrator.

### Deliverables

- redemption flow spec;
- buffer policy v1;
- queue lifecycle matrix.

### Exit Criteria

- withdrawal semantics match `ADR-003`;
- queue covers required statuses;
- target SLA is defined for normal and degraded mode;
- MVP buffer policy is approved.

### Closeout Record

- [Sprint 3 Closeout](crosschain-vault-sprint-3-closeout.md)

## Sprint 4. Entry Layer Refactor

### Goal

Bring the on-chain entry layer to the correct product shape.

### Scope

- decide whether `CrossChainVault` stays the final entry vault or becomes the accounting core behind an `EntryVault` wrapper;
- separate entry semantics from routing and execution concerns;
- define the `entry -> local buffer -> routing` relation;
- fix share semantics:
  - one product
  - one user balance
  - user-facing balance not tied to current chain location of capital;
- define event model for UI/backend.

### Deliverables

- entry boundary decision;
- product-facing contract interface;
- updated event model.

### Exit Criteria

- deposit path does not depend on remote execution availability;
- entry layer semantics match the architecture docs.

## Sprint 5. Routing and Operation Lifecycle

### Goal

Bring the routing layer to a controlled operational model.

### Scope

- revise `StrategyAllocator`;
- define operation lifecycle for:
  - allocate
  - recall
  - harvest
  - emergency exit;
- define correlation ids for contracts and backend;
- define idempotency rules;
- define timeout / retry / fail states;
- add hooks for booster / routing semantics;
- run mock allocation and recall scenarios.

### Deliverables

- operation lifecycle spec;
- allocator state machine updates;
- backend correlation model.

### Exit Criteria

- allocator does not touch user shares;
- recall flow is tied to redemption model;
- lifecycle is observable and idempotent.

## Sprint 6. Transfer and Settlement MVP

### Goal

Integrate transport without breaking product semantics.

### Scope

- implement `LayerZeroBridgeAdapter` path;
- configure peers;
- implement send / receive / ack flow;
- emit settlement events;
- update pending bridge accounting;
- define timeout and recovery baseline.

### Deliverables

- bridge adapter MVP;
- settlement integration path;
- bridge incident baseline.

### Exit Criteria

- bridge lifecycle is integrated into the operation model;
- `pendingBridgeIn / pendingBridgeOut` match NAV assumptions;
- transport failures become recoverable states.

## Sprint 7. Remote Execution MVP

### Goal

Build the execution layer as a modular layer, not the product core.

### Scope

- implement `RemoteStrategyAgent`;
- implement first strategy adapter MVP;
- implement second strategy adapter MVP;
- define unified strategy reporting:
  - totalValue
  - freeLiquidity
  - debt
  - report freshness;
- add remote risk checks;
- run fork tests for at least 2 strategies.

### Deliverables

- 2 remote execution paths;
- unified reporting behavior;
- fork-based validation.

### Exit Criteria

- at least 2 strategies pass the full lifecycle;
- remote execution does not mutate user shares;
- reports feed NAV and redemption correctly.

## Sprint 8. Rebalancing Policy and Risk Limits

### Goal

Make routing economically correct and operationally safe.

### Scope

- write `ADR-004 Rebalancing Policy and Risk Limits`;
- define net benefit calculation;
- add gas + bridge + slippage + liquidity-aware routing;
- define chain caps;
- define strategy caps;
- define low-buffer behavior;
- define stale-report behavior during rebalance;
- define emergency routing restrictions.

### Deliverables

- rebalance policy ADR;
- risk limits matrix;
- routing decision formula v1.

### Exit Criteria

- move decisions are based on net benefit, not raw APR;
- risk guardrails are integrated into operations and backend flows.

## Sprint 9. Hardening and Release Candidate

### Goal

Prepare the system for audit handoff and production-style testnet rehearsal.

### Scope

- invariants;
- fuzzing;
- storage review;
- role review;
- threat model;
- buffer stress scenarios;
- bridge incident scenarios;
- redemption fairness scenarios;
- testnet rehearsal;
- audit handoff package.

### Deliverables

- RC checklist;
- incident test suite;
- audit package.

### Exit Criteria

- critical invariants are covered;
- delayed redemption and bridge incidents are rehearsed;
- end-to-end testnet flow passes;
- audit package is ready.

## 8. Dependencies

### Hard Dependencies

- Sprint 2 depends on Sprint 1
- Sprint 3 depends on Sprint 2
- Sprint 4 depends on Sprint 2 and Sprint 3
- Sprint 5 depends on Sprint 4
- Sprint 6 depends on Sprint 5
- Sprint 7 depends on Sprint 6
- Sprint 8 depends on Sprint 6 and Sprint 7
- Sprint 9 depends on all previous phases

### Parallelizable Work

- backend ledger schema can start during Sprint 2;
- redemption orchestrator design can start during Sprint 3;
- strategy research can run in parallel with Sprint 5;
- QA scenario design can begin before full bridge integration.

## 9. Critical Path

1. semantics freeze
2. ledger / NAV
3. redemption and buffers
4. entry boundary
5. routing lifecycle
6. transfer and settlement
7. remote execution
8. risk limits
9. hardening

## 10. What Is Not in MVP

- fully trustless real-time cross-chain valuation;
- permissionless strategy onboarding;
- multi-asset product;
- cross-chain user shares;
- more than 2-3 production strategy types;
- full autonomy without operational controls;
- an “always instant withdrawal” promise.

## 11. Immediate Next Actions

Before the next implementation iteration starts:

1. approve this plan as the delivery baseline;
2. write `ADR-004 Rebalancing Policy and Risk Limits`;
3. make the `CrossChainVault vs EntryVault wrapper` decision;
4. freeze backend ledger event schema;
5. freeze redemption orchestrator responsibilities.
