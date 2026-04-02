# Cross-Chain Reconciliation Boundaries

Current as of **2026-04-01**.

## Purpose

This document defines the minimum reconciliation boundary for Sprint 2.

It answers a practical question:

- which accounting facts must match on-chain state exactly;
- which facts are reconstructed off-chain;
- which transitions require explicit synchronization to keep NAV conservative.

## On-Chain Authoritative State

The on-chain control plane is authoritative for:

1. share balances
2. `homeIdle`
3. `fundedWithdrawalObligations`
4. accepted strategy state stored in `StrategyRegistry`
5. withdrawal request ownership and status
6. operation status stored in `StrategyAllocator`

If these values differ from the backend ledger, the ledger must reconcile to chain state.

## Off-Chain Authoritative State

The backend ledger remains authoritative for:

1. chain residency history
2. bridge provider correlation ids
3. exact transport timing across bridge stages
4. historical yield attribution by period
5. incident and mismatch classification

The backend may not override custody or shares. It may only interpret and reconcile them.

## Synchronization Boundary

For Sprint 2, the accounting boundary between `StrategyAllocator` and `CrossChainVault` is explicit:

- `StrategyAllocator` stores operation lifecycle state;
- `CrossChainVault` applies NAV-affecting accounting through `syncOperationAccounting(opId)`.

This means operation status changes alone are not enough for vault NAV changes.

The vault-visible accounting changes only after explicit synchronization.

## Conservative Lifecycle Rules

### Allocate

When an `Allocate` operation reaches `Sent` and is synchronized:

- `homeIdle` decreases;
- `pendingBridgeOut` increases.

When the same operation reaches `Settled` and is synchronized:

- `pendingBridgeOut` decreases;
- `currentDebt` increases.

### Recall

When a `Recall` operation reaches `Executed` and is synchronized:

- `currentDebt` decreases;
- `pendingBridgeIn` increases.

When recalled assets are physically received:

- `receiveRecallFunds(assets)` increases `homeIdle`.

When the same recall operation reaches `Settled` and is synchronized:

- `pendingBridgeIn` decreases.

## Required Ordering Assumption

For recall operations, `Settled` must only be acknowledged after home-side funds are actually recognized.

In practical terms:

1. remote recall executes
2. funds bridge home
3. `receiveRecallFunds` is called
4. operation status moves to `Settled`
5. `syncOperationAccounting(opId)` clears `pendingBridgeIn`

If this order is violated, NAV can temporarily understate or overstate transit state.

## Reconciliation Checks

The backend ledger should continuously verify:

1. `navBuckets().totalManagedAssets == totalAssets()`
2. `availableHomeLiquidity == homeIdle - fundedWithdrawalObligations`
3. `pendingBridgeOut` and `pendingBridgeIn` never go negative
4. settled allocate operations do not retain `pendingBridgeOut`
5. settled recall operations do not retain `pendingBridgeIn`
6. funded withdrawals do not exceed available home liquidity at funding time

## Incident Conditions

The system should enter reconciliation incident mode when:

1. an operation is final in the allocator but its accounting sync is missing
2. `pendingBridgeIn` or `pendingBridgeOut` cannot be cleared at settlement
3. `currentDebt` would become negative during recall accounting
4. funded withdrawal obligations exceed home-side asset reality

## Sprint 2 Scope Limit

This document does not define:

1. bridge failure recovery playbooks
2. cancelled or failed operation unwind rules
3. multi-bridge reconciliation
4. user-facing degraded-mode messaging

Those belong to later delivery stages.
