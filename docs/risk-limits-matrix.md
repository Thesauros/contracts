# Risk Limits Matrix (v1)

Current as of **2026-04-06**.

This document is the v1 risk limits matrix referenced by:

- [ADR-004 Rebalancing Policy and Risk Limits](adr-004-rebalancing-policy-and-risk-limits.md)

## Matrix

| Limit | Scope | Type | Default (v1) | Enforced By | On Breach |
| --- | --- | --- | --- | --- | --- |
| `debtLimit` | per strategy | Hard | set per strategy | Off-chain routing, plus governance review of config | Do not allocate; incident if exceeded |
| `maxSlippageBps` | per strategy | Hard | set per strategy | Off-chain quoting; `minAssetsOut` in operation payload | Reject/skip move; tighten size |
| `maxReportDelay` | per strategy | Hard for routing | set per strategy | On-chain staleness detection for mode; off-chain routing | Enter degraded mode; stop allocations |
| `depositsEnabled` | per strategy | Hard | true | Off-chain routing; governance config | Do not allocate |
| `withdrawalsEnabled` | per strategy | Hard | true | Off-chain routing; governance config | Prefer emergency paths; block recall only if explicitly disabled |
| `emergencyExitOnly` | per strategy | Hard | false | Off-chain routing; governance config | Only allow `Recall`/`EmergencyExit` |
| Strategy health | per strategy | Hard | `Active` | Off-chain routing; governance state updates | Do not allocate; allow recall depending on state |
| `chainCap` | per chain | Soft (v1) | set per chain | Off-chain routing + monitoring | Alert; block new allocations if persistent |
| `bridgeCap` | global/per chain | Soft (v1) | set per chain | Off-chain routing + monitoring | Alert; block allocations; prioritize settle/recall |
| `minimumResidualLiquidity` | home vault | Hard | set per vault | On-chain withdraw path; off-chain routing must respect | Block allocations when low |
| `targetLocalBufferAssets` | home vault | Policy target | set per vault | Off-chain routing | Stop allocations; prioritize recall to refill |
| Low buffer threshold | home vault | Hard for allocate | `targetLocalBufferAssets` | Off-chain routing | Prohibit allocate; allow recall |
| Stale reports in rebalance | product | Hard | no allocation when stale | Off-chain routing | Prohibit allocate; require report refresh/settle |
| Emergency routing restrictions | product | Hard | incident-driven | Governance/ops flagging | Only recalls / emergency exits |

## Notes

- In v1, most limits are enforced by routing/orchestrator logic, because allocations are initiated off-chain via the allocator lifecycle.
- The on-chain system already exposes primitives needed for enforcement and observability (strategy configs/state, staleness checks, operation lifecycle).
- A later iteration can migrate selected hard limits on-chain once per-chain config and explicit policy modules are introduced.

