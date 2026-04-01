# Cross-Chain Ledger Event Catalogue

Current as of **2026-04-01**.

## Purpose

This document defines the minimum on-chain event surface the backend ledger must consume during Sprint 2.

It is not a full reconciliation runbook. It is the event catalogue required to reconstruct:

- user position changes;
- accepted strategy state;
- queued and funded withdrawal obligations;
- operation lifecycle transitions;
- conservative NAV bucket composition.

## Event Groups

### 1. User Entry and Exit

Primary source:

- ERC4626 `Deposit`
- ERC4626 `Withdraw`

Interpretation:

- `Deposit` is the canonical on-chain entry event for shares minted against the home entry vault;
- `Withdraw` is the canonical exit event once assets are actually paid out.

### 2. Queued Withdrawal Lifecycle

Primary source:

- `WithdrawalQueued` from [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)
- `WithdrawalStatusUpdated` from [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)
- `WithdrawalRequested` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalFunded` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- `WithdrawalClaimed` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Interpretation:

- `WithdrawalQueued` creates the obligation record;
- `WithdrawalFunded` marks the point at which home-side liquidity becomes reserved and reduces available home liquidity;
- `WithdrawalClaimed` closes the obligation and burns the escrowed shares.

### 3. Strategy State and Accepted Value

Primary source:

- `StrategyConfigured` from [`contracts/crosschain/StrategyRegistry.sol`](../contracts/crosschain/StrategyRegistry.sol)
- `StrategyStateUpdated` from [`contracts/crosschain/StrategyRegistry.sol`](../contracts/crosschain/StrategyRegistry.sol)
- `StrategyAccountingUpdated` from [`contracts/crosschain/StrategyRegistry.sol`](../contracts/crosschain/StrategyRegistry.sol)
- `StrategyReportAccepted` from [`contracts/crosschain/ReportSettler.sol`](../contracts/crosschain/ReportSettler.sol)
- `StrategyReportSettled` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Interpretation:

- `StrategyReportAccepted` means a report passed chain/strategy/timestamp validation;
- `StrategyReportSettled` means the accepted report has been applied into vault-visible strategy state;
- `StrategyAccountingUpdated` is the compact bucket event used to reconstruct:
  - `pendingBridgeIn`
  - `pendingBridgeOut`
  - `freeLiquidity`
  - `unrealizedLossBuffer`
  - `lastReportTimestamp`

### 4. Operation Lifecycle

Primary source:

- `OperationCreated` from [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)
- `OperationStatusUpdated` from [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)

Interpretation:

- these events are required to map bridge and execution lifecycle states;
- the ledger must correlate them with bridge-provider records off-chain;
- on-chain operation state alone is not sufficient to value cross-chain transit safely.

### 5. Recall and Home Liquidity Restoration

Primary source:

- `RecallFundsReceived` from [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)

Interpretation:

- this is the on-chain signal that recalled assets were recognized into `homeIdle`;
- it must be linked to operation and bridge lifecycle records off-chain.

## Minimum NAV Reconstruction Inputs

The backend ledger should reconstruct these buckets from the on-chain surface plus internal orchestration records:

1. `homeIdle`
2. `settledStrategyValue`
3. `pendingBridgeIn`
4. `pendingBridgeOut`
5. `unrealizedLossBuffer`
6. `fundedWithdrawalObligations`
7. `availableHomeLiquidity`

## Current On-Chain Helper Surface

The vault now exposes [`navBuckets()`](../contracts/crosschain/CrossChainVault.sol) for compact on-chain bucket reads.

This helper is intended for:

- backend checkpoints;
- reconciliation tooling;
- integration tests;
- conservative monitoring.

It is not a replacement for the full off-chain ledger.
