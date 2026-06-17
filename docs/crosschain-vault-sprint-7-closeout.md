# Cross-Chain Vault Sprint 7 Closeout

Closeout date: **2026-04-03**

Status: **Completed**

## Objective

Sprint 7 was intended to make remote execution modular, strategy-agnostic, and reportable back into home-side NAV semantics.

## Completed Deliverables

### 1. Remote Execution Layer

Delivered in:

- [Remote Execution MVP](remote-execution-mvp.md)
- [`contracts/crosschain/RemoteStrategyAgent.sol`](../contracts/crosschain/RemoteStrategyAgent.sol)

Result:

- remote execution remains isolated from user-facing share accounting;
- the remote agent now exposes one canonical shell for command handling and report preparation.

### 2. Two Strategy Execution Paths

Delivered in:

- [`contracts/crosschain/MorphoStrategyAdapter.sol`](../contracts/crosschain/MorphoStrategyAdapter.sol)
- [`contracts/crosschain/ERC4626StrategyAdapter.sol`](../contracts/crosschain/ERC4626StrategyAdapter.sol)
- [`test/mocking/MorphoStrategyAdapter.t.sol`](../test/mocking/MorphoStrategyAdapter.t.sol)
- [`test/mocking/ERC4626StrategyAdapter.t.sol`](../test/mocking/ERC4626StrategyAdapter.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)
- [`test/mocking/CrossChainERC4626Pipeline.t.sol`](../test/mocking/CrossChainERC4626Pipeline.t.sol)

Result:

- the repo now has one protocol-specific remote path and one generic ERC4626-compatible path;
- both paths pass the allocate/recall lifecycle in mocked validation;
- remote execution remains adapter-driven rather than protocol-hardcoded.

### 3. Unified Reporting and Risk Checks

Delivered in:

- [Unified Strategy Reporting](unified-strategy-reporting.md)
- [`contracts/crosschain/ReportSettler.sol`](../contracts/crosschain/ReportSettler.sol)
- [`test/mocking/ReportSettler.t.sol`](../test/mocking/ReportSettler.t.sol)
- [`test/mocking/RemoteStrategyAgent.t.sol`](../test/mocking/RemoteStrategyAgent.t.sol)

Result:

- strategy reports now follow one canonical shape across adapters;
- invalid remote liquidity reports are rejected before settlement;
- stale reports are rejected on the home side using per-strategy freshness limits.

## Exit Criteria Check

### at least 2 strategies pass the full lifecycle

Met.

- `MorphoStrategyAdapter` and `ERC4626StrategyAdapter` both pass deploy/recall style lifecycle tests in mocked validation;
- live fork validation for both suites was also confirmed manually against Arbitrum RPC.

### remote execution does not mutate user shares

Met.

- remote execution stays behind the home-side vault boundary;
- pipeline tests confirm user share balances are unchanged while strategy state and NAV update.

### reports feed NAV and redemption correctly

Met in mocked validation.

- accepted reports feed `lastReportedValue`, `freeLiquidity`, and `totalAssets()`;
- redemption previews reflect updated reported value without mixing in remote idle awaiting bridge-home settlement.

## Live Fork Validation

- [`test/forking/MorphoStrategyAdapter.t.sol`](../test/forking/MorphoStrategyAdapter.t.sol)
- [`test/forking/ERC4626StrategyAdapter.t.sol`](../test/forking/ERC4626StrategyAdapter.t.sol)

These tests require `ARBITRUM_RPC_URL`.

Result:

- both suites were validated manually in a local environment with live Arbitrum RPC;
- the current Codex runtime still exhibits a Foundry/macOS proxy panic during fork execution, but that no longer blocks Sprint 7 closeout.

## Deferred Beyond Sprint 7

The following remain outside this Sprint 7 closeout:

- production report attestation/signer policy;
- richer remote risk modules beyond current liquidity/freshness checks;
- multi-strategy report batching;
- full Sprint 8 routing policy and risk-limit logic.
