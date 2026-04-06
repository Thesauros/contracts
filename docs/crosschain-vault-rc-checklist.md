# Cross-Chain Vault RC Checklist (Sprint 9)

Current as of **2026-04-06**.

This checklist is intended to drive Sprint 9 hardening to an audit-ready, rehearsal-ready state.

## Build and Tests

- [ ] `forge build` passes cleanly
- [ ] `forge test --offline --no-match-path test/forking/*` passes
- [ ] Core fuzz suites added and passing
- [ ] Invariant suites added and passing

## Accounting and NAV

- [ ] `NavBuckets.totalManagedAssets` formula is covered by tests
- [ ] `syncOperationAccounting` transitions are covered (allocate + recall, including idempotency)
- [ ] No underflow/negative accounting on any bucket in all tested scenarios

## Redemption and Buffers

- [ ] Instant withdraw capacity respects `minimumResidualLiquidity`
- [ ] Delayed funding lifecycle works end-to-end (request -> processing -> funded -> claimed)
- [ ] Degraded mode behavior is tested and documented

## Routing Policy and Risk Limits

- [ ] Strategy gating is enforced (deposits/withdrawals flags, emergency-only mode)
- [ ] `debtLimit` and `maxSlippageBps` checks are fuzz-tested
- [ ] Allocation is blocked in degraded/stale visibility mode (via routing policy)
- [ ] Allocation respects `maxAllocatableAssets` buffer/residual guardrail

## Roles and Controls

- [ ] Role surface reviewed (governance/guardian/keeper/bridge/reporter/vault)
- [ ] Emergency controls documented (pause delayed funding, degraded mode toggle, emergency-only strategies)
- [ ] Privileged actions have explicit owners and runbook steps

## Storage and Upgrade Safety

- [ ] Storage layout reviewed for all crosschain contracts
- [ ] No accidental storage collisions introduced
- [ ] Upgrade plan clarified (if proxying is in scope) or explicitly out of scope for MVP

## Incident Scenarios

- [ ] Bridge failure scenarios rehearsed (timeout, ack failure, replay protection)
- [ ] Stale report scenarios rehearsed (degraded mode, allocation blocked)
- [ ] Buffer stress scenarios rehearsed (withdrawal spikes, forced recalls)
- [ ] Recovery actions documented (manual steps, roles required)

## Audit Package

- [ ] Threat model doc updated
- [ ] Spec + ADRs + closeouts linked and consistent
- [ ] Known limitations and deferred items enumerated

