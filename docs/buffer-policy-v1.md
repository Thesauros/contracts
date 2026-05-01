# Buffer Policy v1

Current as of **2026-04-02**.

## Purpose

This document defines the Sprint 3 MVP buffer policy for the current contract layer.

## Policy Objects

The policy uses two home-side controls:

1. `targetLocalBufferAssets`
2. `minimumResidualLiquidity`

## Interpretation

`targetLocalBufferAssets`:

- expresses the governance target for the tagged home-side local buffer;
- is exposed through `navBuckets().localBufferAssets`;
- is capped by actual `homeIdle`.

`minimumResidualLiquidity`:

- is the enforceable residual liquidity floor for instant withdrawals and delayed funding;
- prevents the vault from draining all recognized home-side liquidity into redemptions;
- is applied after subtracting funded but unclaimed obligations.

## Enforcement Rule

The enforceable funding rule is:

```text
instant or delayed funding is allowed only if:
requestedAssets <= availableHomeLiquidity - minimumResidualLiquidity
```

With the expected floor behavior:

```text
if availableHomeLiquidity <= minimumResidualLiquidity
then fundable capacity = 0
```

## Why Two Controls Exist

The controls serve different purposes:

- `targetLocalBufferAssets` is an accounting and monitoring target;
- `minimumResidualLiquidity` is an execution guard.

The target may be larger than the enforced minimum.

## Approved MVP Policy

For Sprint 3, the approved MVP shape is:

- keep explicit home-side buffer accounting visible;
- enforce a governance-controlled residual floor;
- treat remote recall ordering as orchestrator policy, not vault business logic.

## Deferred Items

Still deferred beyond Sprint 3:

- dynamic percentage-of-TVL sizing;
- time-of-day or utilization-based sizing;
- dedicated booster / routing custody layer;
- automatic emergency multipliers.
