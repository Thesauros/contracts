# Entry Event Model

Current as of **2026-04-03**.

## Purpose

This document defines the Sprint 4 event model for the product-facing entry layer when `CrossChainVault` remains the final entry vault.

## Product-Facing Events

### Deposit

Source:

- ERC4626 `Deposit`

Meaning:

- canonical user entry event;
- shares are minted on the entry/accounting chain.

### Instant Withdrawal

Source:

- ERC4626 `Withdraw`

Meaning:

- canonical instant redemption event;
- assets are paid locally from recognized home-side liquidity.

### Queued Withdrawal Request

Sources:

- `WithdrawalRequested` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalQueued` from [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)

Meaning:

- user intent moved from instant path to delayed path;
- shares are escrowed in the entry vault.

### Delayed Funding Lifecycle

Sources:

- `WithdrawalFundingStarted` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalFunded` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalStatusUpdated` from [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)

Meaning:

- backend and UI can track the movement from queued request to claimable obligation.

### Delayed Claim and Cancel

Sources:

- `WithdrawalClaimed` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalCancelled` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Meaning:

- the delayed redemption path closed either by payout or by queue cancellation.

### Entry Boundary Configuration

Source:

- `EntryBoundaryConfirmed` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Meaning:

- records that the deployed contract is both final entry vault and accounting core.

## UI / Backend Read Surface

The product-facing view surface is:

- `entryChainId()`
- `positionView(owner)`
- `instantWithdrawalCapacity()`
- `currentRedemptionMode()`
- `currentRedemptionSla()`

This read surface is defined in:

- [`ICrossChainEntryVault`](../contracts/interfaces/crosschain/ICrossChainEntryVault.sol)

## Interpretation Rule

For UI and backend product views:

- the user has one balance per vault product;
- the user-facing balance is read from accepted accounting state;
- current physical chain residency of capital does not fragment the user balance into multiple chain balances.
