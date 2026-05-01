# Cross-Chain Vault Audit Package

Current as of: **2026-04-06**

Branch: `crosschain`

## Scope

This package covers the cross-chain vault control plane and its mocked execution paths:

- home-side entry/accounting surface: `CrossChainVault`
- configuration registry: `StrategyRegistry`
- routing + operations state machine: `StrategyAllocator`
- reporting and settlement: `ReportSettler`
- delayed withdrawals: `WithdrawalQueue`
- mocked remote execution shell + adapters:
  - `RemoteStrategyAgent`
  - `MorphoStrategyAdapter`
  - `ERC4626StrategyAdapter`

## Primary Docs

- [Cross-Chain Vault Spec](crosschain-vault-spec.md)
- [ADR-004 Rebalancing Policy and Risk Limits](adr-004-rebalancing-policy-and-risk-limits.md)
- [Risk Limits Matrix](risk-limits-matrix.md)
- [Cross-Chain Vault Threat Model](crosschain-vault-threat-model.md)
- [Cross-Chain Vault Report Attestation Policy](crosschain-vault-report-attestation-policy.md)
- [Cross-Chain Vault RC Checklist](crosschain-vault-rc-checklist.md)
- [Cross-Chain Vault Incident Test Suite](crosschain-vault-incident-test-suite.md)
- [Cross-Chain Vault Testnet Rehearsal Runbook](crosschain-vault-testnet-rehearsal-runbook.md)
- [Cross-Chain Vault Development Plan](crosschain-vault-sprints.md)

## Critical Code Map

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/crosschain/StrategyRegistry.sol`](../contracts/crosschain/StrategyRegistry.sol)
- [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)
- [`contracts/crosschain/ReportSettler.sol`](../contracts/crosschain/ReportSettler.sol)
- [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)
- [`contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol`](../contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol)

Remote (mocked):

- [`contracts/crosschain/RemoteStrategyAgent.sol`](../contracts/crosschain/RemoteStrategyAgent.sol)
- [`contracts/crosschain/MorphoStrategyAdapter.sol`](../contracts/crosschain/MorphoStrategyAdapter.sol)
- [`contracts/crosschain/ERC4626StrategyAdapter.sol`](../contracts/crosschain/ERC4626StrategyAdapter.sol)

## Test Coverage Map

Invariants:

- [`test/invariants/CrossChainVault.invariant.t.sol`](../test/invariants/CrossChainVault.invariant.t.sol)
- [`test/invariants/CrossChainVaultAccounting.invariant.t.sol`](../test/invariants/CrossChainVaultAccounting.invariant.t.sol)

Fuzz:

- [`test/fuzz/StrategyAllocatorRisk.t.sol`](../test/fuzz/StrategyAllocatorRisk.t.sol)
- [`test/fuzz/CrossChainVaultSyncAccounting.t.sol`](../test/fuzz/CrossChainVaultSyncAccounting.t.sol)

Incident scenarios:

- [`test/incidents/RoutingPolicyIncidents.t.sol`](../test/incidents/RoutingPolicyIncidents.t.sol)
- [`test/incidents/RedemptionIncidents.t.sol`](../test/incidents/RedemptionIncidents.t.sol)
- [`test/incidents/StrategyAllocatorConfigIncidents.t.sol`](../test/incidents/StrategyAllocatorConfigIncidents.t.sol)

Role review:

- [`test/security/Roles.t.sol`](../test/security/Roles.t.sol)

## How To Run

Primary local suite (stable in this repo environment):

`forge test --offline --no-match-path 'test/forking/*'`

Fork suites:

- require RPC env vars (e.g. `ARBITRUM_RPC_URL`);
- may be environment-dependent in some macOS/Foundry setups (proxy panic); keep them separate from CI until resolved.

## Known Gaps / Explicitly Deferred

- testnet rehearsal and end-to-end bridging integration
- chain-level caps enforcement module (beyond per-strategy and vault-level limits)
