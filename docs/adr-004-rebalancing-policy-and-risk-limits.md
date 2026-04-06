# ADR-004 Rebalancing Policy and Risk Limits

Current as of **2026-04-06**.

## Title

`ADR-004: Rebalancing Policy and Risk Limits`

## Status

`Proposed`

## Date

`2026-04-06`

## Related Documents

- [ADR-002 Ledger and NAV Model](adr-002-ledger-and-nav-model.md)
- [ADR-003 Redemption SLA and Liquidity Buffers](adr-003-redemption-sla-and-liquidity-buffers.md)
- [Routing Operation Lifecycle](routing-operation-lifecycle.md)
- [Hybrid Cross-Chain Vault Architecture](hybrid-crosschain-vault-architecture.md)

## Context

After Sprint 6 (transfer/settlement) and Sprint 7 (remote execution + unified reporting), the product can move capital across chains and accept strategy reports back into home-side accounting.

The next missing piece is policy: deciding *when* to move capital and bounding that behavior with explicit risk limits.

Constraints:

- routing decisions must be economically justified (not "highest APR wins");
- decisions must preserve redemption semantics (buffers + delayed redemption model);
- the system must degrade predictably on stale reports or bridge incidents;
- we need clear hard caps (risk limits) and a decision formula (net benefit).

## Decision

We introduce a policy layer with:

1. **Net benefit routing**: a move is only proposed when expected benefit exceeds total costs plus a risk margin.
2. **Risk limits matrix**: explicit caps and guardrails applied per strategy and per chain (hard vs soft).
3. **Degraded-mode constraints**: when reports are stale or the system is in degraded mode, routing becomes conservative.
4. **Emergency routing restrictions**: emergency modes restrict the operation surface to recalls and emergency exits.

This ADR defines the decision formula and the minimum risk limits required for Sprint 8.

## Definitions

### Move

A move is an operation initiated by the allocator:

- `Allocate`: move assets from home-side idle/buffer into a remote strategy.
- `Recall`: pull assets back from a remote strategy to home-side liquidity.

These correspond to the lifecycle states in [Routing Operation Lifecycle](routing-operation-lifecycle.md).

### Hard vs Soft Limits

- **Hard limit**: must not be violated. Enforced on-chain where possible, otherwise enforced by off-chain routing + monitoring with a stop-the-world response on breach.
- **Soft limit**: can be exceeded under governance-approved or incident-handled conditions. Enforced off-chain with alerts and explicit override paths.

## Routing Decision Formula (v1)

### Goal

Only execute moves with positive expected net benefit after accounting for:

- strategy return deltas;
- on-chain gas;
- bridge costs (fees + latency cost);
- slippage/price impact;
- liquidity constraints (free liquidity vs unwind);
- risk margin for uncertainty and incident probability.

### Inputs (minimum set)

- `A`: assets to move
- `APR_from`, `APR_to`: expected APRs for current and target placement
- `H`: evaluation horizon in seconds (policy-defined; e.g. 1-7 days)
- `C_gas`: expected gas cost in asset units (or converted to asset units)
- `C_bridge`: bridge fees + expected relayer costs in asset units
- `C_slip`: worst-case slippage bound in asset units (from `maxSlippageBps`)
- `P_latency`: penalty for bridge latency / opportunity cost (optional in v1; can be 0 initially)
- `M_risk`: risk margin in asset units (policy-defined; function of staleness, utilization, incidents)

### Decision Rule

Propose a move only if:

```text
ExpectedBenefit(A) - (C_gas + C_bridge + C_slip + P_latency + M_risk) > 0
```

Where:

```text
ExpectedBenefit(A) = A * (APR_to - APR_from) * (H / 365 days)
```

Notes:

- `APR_*` is an *estimate* from off-chain pricing/yield sources, not on-chain truth.
- `H` is not a user promise; it is a routing control parameter.
- v1 may set `P_latency = 0` and model risk margin `M_risk` as a constant bps haircut until we have better calibration.

## Risk Limits (Minimum Set)

The system must enforce, at minimum:

### Strategy-Level Limits

1. `debtLimit` (hard): maximum total debt allocated to the strategy.
2. `maxSlippageBps` (hard): min-out constraints for allocate/recall where applicable.
3. `maxReportDelay` (hard for routing; hard/soft for redemption depending on mode):
   - stale reports trigger degraded mode and restrict allocations.
4. `depositsEnabled` / `withdrawalsEnabled` (hard): gating whether the strategy can receive new capital or allow recall.
5. `emergencyExitOnly` (hard): if true, only `Recall` / `EmergencyExit` operations are allowed.

These are already represented in `CrossChainTypes.StrategyConfig`.

### Chain-Level Limits

1. `chainCap` (soft->hard): maximum exposure to a chain (sum of strategy debts + pending bridge).
2. `bridgeCap` (soft): limit total in-flight bridge exposure to reduce incident blast radius.

These can be enforced off-chain in v1 with monitoring and governance-controlled overrides. A later iteration may move hard caps on-chain (per-chain config + checks).

### Liquidity and Buffer Limits

1. `minimumResidualLiquidity` (hard): must preserve home-side residual liquidity.
2. `targetLocalBufferAssets` (policy target): preferred buffer size.
3. `low-buffer behavior` (hard for allocations):
   - when `availableHomeLiquidity` is below buffer target (or below residual minimum), prohibit allocations.

These exist on-chain in `CrossChainVault` as accounting state; enforcement for routing is primarily off-chain by choosing not to dispatch allocate operations that would violate buffer constraints.

## Degraded Mode Policy

Degraded mode is active when:

- governance manually enables it, or
- any strategy report is stale relative to `maxReportDelay`.

Policy changes in degraded mode:

- new allocations are restricted (default: prohibited);
- recalls are allowed (and may be prioritized to restore liquidity);
- net benefit threshold increases via `M_risk` to avoid optional moves;
- emergency-only strategies remain emergency-only.

## Emergency Routing Restrictions

When a bridge incident or strategy incident is active (governance/ops flagged):

- prohibit new allocations across affected chains/strategies;
- allow only:
  - `Recall` if safe and supported,
  - `EmergencyExit` if necessary,
  - report acceptance/settlement to restore visibility.

## Consequences

### Pros

- routing becomes explainable and economically bounded;
- risk is made explicit via a matrix rather than implicit heuristics;
- degraded mode becomes deterministic rather than ad hoc.

### Cons / Tradeoffs

- most enforcement is off-chain in v1 (routing/orchestrator), which requires strong monitoring and incident response discipline;
- net benefit estimates rely on external data; errors must be absorbed by `M_risk` and conservative thresholds.

## Implementation Notes (Sprint 8)

Deliverables:

- this ADR;
- [Risk Limits Matrix](risk-limits-matrix.md);
- routing decision formula v1 (this ADR section) used by the routing/orchestrator.

Non-goals for Sprint 8:

- perfect cross-chain on-chain enforcement of chain caps;
- report attestation / signer policy (explicitly deferred from Sprint 7 closeout);
- multi-strategy report batching.

