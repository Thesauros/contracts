# Cross-Chain Vault Sprint 2 Closeout

Closeout date: **2026-04-02**

## Objective

Sprint 2 was intended to make the accounting model usable for the hybrid cross-chain product.

The target outcome was:

- explicit NAV composition;
- explicit stale-report behavior;
- explicit backend ledger ingestion surface;
- explicit reconciliation boundary between operation lifecycle and vault-visible accounting.

## Completed Deliverables

### 1. Updated Accounting Interfaces

Delivered in:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/interfaces/crosschain/ICrossChainVault.sol`](../contracts/interfaces/crosschain/ICrossChainVault.sol)
- [`contracts/libraries/CrossChainTypes.sol`](../contracts/libraries/CrossChainTypes.sol)

Result:

- `navBuckets()` exposes the current Sprint 2 accounting view;
- `syncOperationAccounting(opId)` makes vault-visible accounting updates explicit;
- `setTargetLocalBufferAssets(assets)` exposes the home-side local buffer target.

### 2. Ledger Event Catalogue

Delivered in:

- [Cross-Chain Ledger Event Catalogue](crosschain-ledger-event-catalogue.md)

Result:

- backend-required event surface is enumerated;
- local buffer target changes are part of the catalogue;
- home-side funding and strategy-state transitions are reconstruction-safe.

### 3. Reconciliation Boundary

Delivered in:

- [Cross-Chain Reconciliation Boundaries](crosschain-reconciliation-boundaries.md)

Result:

- `StrategyAllocator` lifecycle state is separated from vault accounting state;
- accounting changes require explicit synchronization;
- recall ordering is documented to avoid conservative NAV mismatches.

### 4. Test Coverage

Delivered in:

- [`test/mocking/CrossChainVault.t.sol`](../test/mocking/CrossChainVault.t.sol)

Covered areas:

- deposit and `homeIdle`;
- settled strategy value and transit buckets;
- queued withdrawal funding and claim flow;
- allocate and recall operation accounting synchronization;
- stale report gating;
- local buffer bucket exposure and capping.

## Final Sprint 2 Accounting Model

The Sprint 2 vault-visible bucket model is:

1. `homeIdle`
2. `localBufferAssets`
3. `settledStrategyValue`
4. `pendingBridgeIn`
5. `pendingBridgeOut`
6. `unrealizedLossBuffer`
7. `fundedWithdrawalObligations`
8. `availableHomeLiquidity`

Important interpretation:

- `localBufferAssets` is currently a tagged subset of `homeIdle`;
- it is exposed for accounting and reconciliation visibility;
- it is not additive on top of `homeIdle` in `totalAssets()`.

This preserves the Sprint 2 exit criterion that transit and home-side state are not double-counted.

## Exit Criteria Check

### `totalAssets()` does not double-count transit state

Met.

- `pendingBridgeIn` and `pendingBridgeOut` are applied through explicit operation synchronization;
- `localBufferAssets` is exposed as a subset of `homeIdle`, not an additive duplicate.

### stale strategy state has explicit policy

Met.

- stale reports force conservative withdrawal behavior through vault checks;
- `maxWithdraw()` and `maxRedeem()` collapse to zero while reports are stale.

### backend ledger can reconstruct product NAV from approved inputs

Met for Sprint 2 scope.

- event catalogue is defined;
- reconciliation boundary is defined;
- `navBuckets()` exposes the compact on-chain checkpoint surface.

## What Remains Deferred

The following items remain outside Sprint 2 and belong to later delivery stages:

- bridge failure recovery playbooks;
- cancelled / failed operation unwind rules;
- multi-bridge reconciliation;
- user-facing degraded-mode semantics;
- dedicated booster / routing buffer custody layer.
