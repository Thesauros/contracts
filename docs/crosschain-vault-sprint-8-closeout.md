# Cross-Chain Vault Sprint 8 Closeout

Closeout date: **2026-04-06**

Status: **Completed**

## Objective

Sprint 8 was intended to define the rebalancing policy and risk limits so routing decisions become economically justified and operationally safe.

## Completed Deliverables

### 1. Rebalancing Policy ADR

Delivered in:

- [ADR-004 Rebalancing Policy and Risk Limits](adr-004-rebalancing-policy-and-risk-limits.md)

Result:

- net benefit routing decision formula v1 is defined;
- degraded-mode and emergency routing restrictions are explicitly defined;
- minimum risk limits set is enumerated.

### 2. Risk Limits Matrix

Delivered in:

- [Risk Limits Matrix](risk-limits-matrix.md)

Result:

- explicit hard vs soft limits are captured in one matrix and referenced by ADR-004.

### 3. On-Chain Guardrails (Allocator + Vault Surface)

Delivered in:

- [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)
- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol`](../contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol)

Result:

- `StrategyAllocator.createOperation` validates strategy existence and basic per-strategy limits (debt cap, slippage bound, deposits/withdrawals flags, emergency-only gating, stale-report gating when exposure exists);
- optional `routingPolicy` hook can block `Allocate Created -> Sent` when the system is stale/degraded or when allocation exceeds `maxAllocatableAssets`;
- `CrossChainVault` staleness detection is exposure-aware (registered-but-unused strategies do not degrade the whole system).

## Validation

Mock tests were updated and run with:

`forge test --offline --no-match-path test/forking/*`

Fork suites remain environment-dependent (RPC + Foundry/macOS proxy panic noted previously) and are excluded from this closeout.

## Deferred Beyond Sprint 8

- full chain-level caps enforced on-chain (per-chain config module);
- richer routing benefit models (latency penalty calibration, uncertainty bands, risk-based horizons);
- production report attestation/signer policy (explicitly deferred from Sprint 7 closeout).

