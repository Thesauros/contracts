# Entry Boundary Decision

Current as of **2026-04-03**.

## Decision

For the current product shape, [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol) remains the final entry vault.

No separate `EntryVault` wrapper is introduced in Sprint 4.

## Why

This choice is intentional for the current stage:

- there is one product-facing accounting chain;
- shares already exist only in `CrossChainVault`;
- deposit and withdrawal semantics are already anchored there;
- introducing a wrapper now would add interface indirection without solving a concrete release blocker.

## Architectural Interpretation

`CrossChainVault` now plays two roles at once:

1. final product-facing entry vault
2. accounting core

This is acceptable for the current rollout because:

- user accounting remains on one chain;
- routing and execution are still internal;
- remote contracts do not mint or burn shares.

The boundary is expressed through interface separation rather than wrapper separation:

- [`ICrossChainEntryVault`](../contracts/interfaces/crosschain/ICrossChainEntryVault.sol) defines the product-facing entry surface;
- [`ICrossChainControlPlane`](../contracts/interfaces/crosschain/ICrossChainControlPlane.sol) defines operational and accounting controls;
- [`ICrossChainVault`](../contracts/interfaces/crosschain/ICrossChainVault.sol) combines both for the full contract surface.

## Entry -> Buffer -> Routing Relation

For the current implementation the asset path is:

1. user enters through `CrossChainVault`
2. capital becomes `homeIdle`
3. part of `homeIdle` is tagged as `localBufferAssets`
4. remaining capacity may be routed out through allocator and bridge flow

Interpretation:

- `homeIdle` is the first physical custody point;
- `localBufferAssets` is the home-side liquidity intended for entry-side redemption smoothing;
- routing begins only after capital has already entered the accounting vault.

## Consequence

Future refactoring may still introduce a wrapper if:

- there are multiple user-facing entry contracts;
- per-chain UX semantics diverge;
- compliance or distribution partners need a thinner product-facing shell.

That is not required for the current Base-first release profile.
