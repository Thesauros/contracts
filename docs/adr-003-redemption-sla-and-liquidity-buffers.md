# ADR-003 Redemption SLA and Liquidity Buffers

Current as of **2026-03-18**.

## Title

`ADR-003: Redemption SLA and Liquidity Buffers`

## Status

`Proposed`

## Date

`2026-03-18`

## Related Documents

- [Hybrid Cross-Chain Vault Architecture](hybrid-crosschain-vault-architecture.md)
- [ADR-002 Ledger and NAV Model](adr-002-ledger-and-nav-model.md)

## Context

In the new cross-chain product, strict instant withdrawal can no longer be guaranteed because capital may physically reside:

- on another chain;
- in a remote strategy;
- in bridge transit;
- in the middle of a recall / unwind flow.

At the same time UX must not degrade into a lockup product. Users need a short and predictable redemption window.

We therefore need an explicit policy for:

- withdrawal semantics;
- liquidity buffers;
- SLA;
- degraded modes;
- failure handling.

## Decision

The chosen model is:

- the product **does not promise strict instant liquidity** in all cases;
- the product **does promise fast redemption whenever local liquidity is sufficient**;
- otherwise redemption switches to **delayed mode** with a target SLA of about **15 minutes** in normal conditions;
- local liquidity buffers are explicit design objects, not accidental idle cash;
- redemption orchestration consumes the local buffer first and triggers remote recall only if needed;
- SLA is an operational target, not an absolute on-chain guarantee.

## Redemption Modes

### 1. Instant Mode

Used when enough local liquidity already exists on the home / entry side.

Characteristics:

- no cross-chain recall is needed;
- withdrawal can be funded immediately;
- the user receives assets without waiting for bridge completion.

### 2. Delayed Mode

Used when local liquidity is insufficient.

Characteristics:

- a withdrawal request is created;
- recall / pullback flow is started;
- payment happens after funding;
- the target SLA in normal mode is about 15 minutes.

### 3. Degraded Mode

Used during:

- bridge incidents;
- chain congestion;
- stale strategy reports;
- strategy pause;
- emergency liquidity stress.

Characteristics:

- SLA may become longer;
- some redemptions may be restricted or paused;
- UI and operational tooling must clearly indicate degraded status.

## Liquidity Buffer Policy

### Purpose of Buffers

Liquidity buffers are needed for:

- covering ordinary withdrawals without remote recall;
- smoothing over bridge latency;
- protecting UX from short withdrawal spikes;
- reducing load on the recall engine.

### Buffer Layers

At minimum two buffer types are recommended:

#### Home Entry Buffer

Liquidity held close to the user entry vault.

Used for:

- fast withdrawals;
- immediate funding of small and medium requests;
- short-term deposit staging.

#### Routing / Booster Buffer

Intermediate liquidity held in the booster layer.

Used for:

- bridge staging;
- rebalancing transitions;
- temporary funding smoothing between chains.

## Funding Order

When processing a withdrawal, the system should use this order:

1. `home idle liquidity`
2. `home liquidity buffer`
3. `booster / routing buffer available for recall`
4. `remote strategy free liquidity`
5. `remote strategy unwind`
6. `emergency liquidity procedures`

## SLA Model

### Normal Mode SLA

Target behavior:

- `instant` when enough home liquidity exists;
- otherwise `fund within ~15 minutes` under normal conditions.

### Degraded Mode SLA

In degraded mode SLA may worsen because of:

- bridge delays;
- gas spikes;
- paused remote strategy;
- stale reports;
- on-chain congestion.

In degraded mode the system must:

- switch to conservative funding decisions;
- avoid promising timelines it cannot maintain;
- escalate incidents to monitoring / operations.

## Withdrawal Lifecycle

1. User submits withdrawal intent.
2. System checks current instant capacity.
3. If enough liquidity exists, the withdrawal is funded immediately.
4. If not, the request moves into delayed queue.
5. Redemption orchestrator determines the recall plan.
6. Funds are pulled back from the remote chain if needed.
7. Request status changes to funded.
8. User claims or receives assets according to vault semantics.

## Funding Policies

### Small Withdrawals

Should usually be satisfied from local buffer.

### Medium Withdrawals

May be funded locally or through short recall depending on current utilization.

### Large Withdrawals

May require:

- explicit delayed mode;
- staged recall from multiple strategies;
- additional policy approval in early versions.

## Buffer Sizing Principles

Buffer size should not be defined by a single constant. It should depend on:

- recent withdrawal volumes;
- time-of-day patterns;
- active user concentration;
- chain bridge latency;
- strategy unwind speed;
- gas conditions;
- incident probability and risk appetite.

For the first stage, an acceptable policy model is:

- a minimum absolute buffer per chain;
- a percentage of chain TVL;
- a temporary emergency multiplier during stress.

## Contract Implications

For the current `contracts` repository, this means:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol) must support clear separation between `instant withdraw` and `requestWithdrawal`;
- [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol) is the basis of the delayed redemption flow;
- `homeIdle` and related local liquidity semantics must be treated as first-line redemption liquidity;
- a dedicated buffer contract or explicit buffer accounting layer may still be needed.

## Operational Implications

A dedicated off-chain redemption orchestrator is required. It is responsible for:

- funding source selection;
- launching remote recall;
- SLA tracking;
- prioritization of queued withdrawals;
- degraded mode switching.

Minimum monitoring should cover:

- queue age;
- funding latency;
- claim latency;
- recall success rate;
- stuck bridge operations;
- home buffer utilization.

## User Experience Rules

- The interface must not promise always-instant withdrawals.
- The interface must clearly show instant availability vs delayed request.
- When delayed mode is entered, the user must immediately see the expected processing window.
- In degraded mode the user must see incident status, not just an indefinite waiting spinner.

## Risk Controls

At minimum, the system should include:

- max instant withdrawal capacity per chain;
- minimum residual buffer after funding;
- pause of instant redemptions when reports are stale;
- emergency pause for delayed funding if bridge state is unreliable;
- optional queue prioritization rules.

## Non-Goals

This decision does not attempt to:

- guarantee instant redemption of any size;
- make every withdrawal fully synchronous on-chain;
- store the entire SLA logic on-chain;
- remove dependency on operational orchestration.

## Consequences

Advantages:

- realistic UX for a cross-chain vault;
- less bridge pressure for every withdrawal;
- ability to service ordinary withdrawals quickly;
- better fit with the hybrid architecture.

Trade-offs:

- buffer capital creates efficiency drag;
- active operational management becomes necessary;
- degraded-mode communication must be explicit;
- SLA becomes a product obligation that must be monitored.

## Open Questions

- What minimum buffer per chain is acceptable at launch?
- Should there be different SLA tiers by withdrawal size?
- Is an auto-claim flow needed after funding?
- What threshold moves the system from normal to degraded redemption mode?
- Should new allocations be temporarily restricted when the home buffer is too low?

## Follow-up Work

- `ADR-004 Rebalancing Policy and Risk Limits`
- buffer sizing methodology
- redemption queue prioritization policy
- ops runbook for bridge and recall incidents
