# Redemption Flow Spec

Current as of **2026-04-02**.

## Purpose

This document defines the Sprint 3 redemption flow for the current `contracts` repository.

It focuses on:

- instant vs delayed behavior;
- keeper/orchestrator hooks;
- residual-liquidity protection;
- normal vs degraded mode interpretation.

## Current On-Chain Components

The flow is currently implemented through:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)

## Instant vs Delayed Decision

The current instant capacity is:

```text
instantWithdrawalCapacity =
    max(0, availableHomeLiquidity - minimumResidualLiquidity)
```

Interpretation:

- `availableHomeLiquidity` already excludes funded but unclaimed withdrawal obligations;
- `minimumResidualLiquidity` preserves the MVP home-side residual buffer;
- a withdrawal is instant only if the requested asset amount fits inside `instantWithdrawalCapacity`.

## Normal Mode

Normal mode applies when:

- there is no manual degraded-mode switch;
- strategy reports are not stale.

Current target SLA:

- instant when local capacity is sufficient;
- otherwise keeper/orchestrator funding target is `15 minutes`.

## Degraded Mode

Degraded mode applies when:

- governance explicitly enables degraded redemption mode; or
- strategy report staleness is detected.

Current target SLA:

- delayed requests use the degraded target of `60 minutes` by default.

Current Sprint 3 conservative behavior:

- `maxWithdraw()` and `maxRedeem()` return zero when reports are stale;
- `requestWithdrawal()` also remains blocked while report staleness is unresolved;
- delayed funding can additionally be paused through governance if bridge or operational state is unreliable.

## Lifecycle

### 1. Instant path

1. user calls standard ERC4626 `withdraw` / `redeem`
2. vault checks staleness guards
3. vault checks `instantWithdrawalCapacity`
4. assets are transferred immediately

### 2. Delayed path

1. user calls `requestWithdrawal(shares, receiver, owner)`
2. vault previews assets and verifies the request does not fit in instant capacity
3. shares move into vault escrow
4. queue creates a request in `Pending`
5. keeper/orchestrator calls `startWithdrawalFunding(requestId)`
6. queue moves the request to `Processing`
7. orchestrator sources liquidity according to the funding order
8. keeper/governance calls `fundWithdrawal(requestId)`
9. queue moves the request to `Funded`
10. user calls `claimWithdrawal(requestId)`
11. queue moves the request to `Claimed`
12. escrowed shares are burned and assets are paid out

### 3. Cancel path

Before funding, the request may be cancelled:

- by the owner; or
- by keeper/governance.

Effect:

- queue moves the request to `Cancelled`;
- escrowed shares are returned to the owner.

## Funding Order

The current Sprint 3 contracts define only the home-side enforceable order:

1. home liquidity already recognized in `homeIdle`
2. residual buffer guard via `minimumResidualLiquidity`

Remote funding order remains an orchestrator responsibility documented in policy, not encoded fully on-chain.

## Orchestrator Hooks

The minimum orchestrator hooks are:

- `startWithdrawalFunding(requestId)` to mark the queue item as actively being funded;
- `fundWithdrawal(requestId)` to reserve home-side assets once liquidity is available;
- `setDelayedFundingPaused(bool)` to block funding during incidents;
- `setDegradedRedemptionMode(bool)` to expose degraded-mode state explicitly.

## Monitoring Fields

The queue now records:

- `createdAt`
- `updatedAt`
- `fundedAt`
- `claimedAt`

These fields support:

- queue age tracking;
- funding latency tracking;
- claim latency tracking.
