# Cross-Chain Vault Sprint 4 Closeout

Closeout date: **2026-04-03**

## Objective

Sprint 4 was intended to bring the entry layer to the correct product shape.

## Completed Deliverables

### 1. Entry Boundary Decision

Delivered in:

- [Entry Boundary Decision](entry-boundary-decision.md)

Result:

- `CrossChainVault` remains the final entry vault;
- no `EntryVault` wrapper is introduced in this stage.

### 2. Product-Facing Contract Interface

Delivered in:

- [`contracts/interfaces/crosschain/ICrossChainEntryVault.sol`](../contracts/interfaces/crosschain/ICrossChainEntryVault.sol)
- [`contracts/interfaces/crosschain/ICrossChainControlPlane.sol`](../contracts/interfaces/crosschain/ICrossChainControlPlane.sol)
- [`contracts/interfaces/crosschain/ICrossChainVault.sol`](../contracts/interfaces/crosschain/ICrossChainVault.sol)

Result:

- product-facing entry semantics are separated from operational semantics by interface boundary;
- the full vault interface remains available for system integrations.

### 3. Updated Event Model

Delivered in:

- [Entry Event Model](entry-event-model.md)

Result:

- the product-facing event surface for deposits, instant withdrawals, delayed withdrawals, and entry-boundary semantics is explicit.

### 4. Product Position View

Delivered in:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Result:

- `entryChainId()` explicitly identifies the entry/accounting chain;
- `positionView(owner)` exposes one user balance view derived from accepted accounting state.

## Exit Criteria Check

### deposit path does not depend on remote execution availability

Met.

- deposit still lands first in local `homeIdle`;
- remote execution remains asynchronous and optional after deposit.

### entry layer semantics match the architecture docs

Met for the chosen no-wrapper path.

- user-facing and control-plane semantics are now separated through interfaces;
- user balance interpretation is explicit and not tied to remote capital location.

## Deferred Beyond Sprint 4

The following remain outside this sprint:

- multi-entry-vault topology;
- partner-specific entry wrappers;
- per-chain distribution shells;
- full routing lifecycle completion, which belongs to Sprint 5.
