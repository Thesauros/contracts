# Unified Strategy Reporting

Date: **2026-04-03**

## Objective

Standardize what a remote strategy reports back so that home-side NAV and redemption policy consume one consistent shape regardless of protocol adapter.

## Canonical Report Fields

Each remote strategy report uses:

- `strategyId`
- `chainId`
- `totalValue`
- `freeLiquidity`
- `totalDebt`
- `pnl`
- `reportTimestamp`
- `positionsHash`

## Current Semantics

Implemented in:

- [`RemoteStrategyAgent`](../contracts/crosschain/RemoteStrategyAgent.sol)
- [`ReportSettler`](../contracts/crosschain/ReportSettler.sol)

The current semantics are:

- `totalValue` is the strategy adapter's current remote deployed value;
- `freeLiquidity` is the adapter's immediately withdrawable liquidity;
- `totalDebt` is the home-side notion of deployed principal tracked by the remote agent;
- `pnl` is computed as `totalValue - totalDebt`;
- remote idle assets awaiting bridge-home are not mixed into `totalDebt` or `totalValue`.

This keeps remote reports aligned with home-side `pendingBridgeIn` accounting and avoids double-counting liquidity that has already been released from the strategy.

## Risk Checks

The current reporting path enforces:

- `chainId != 0` on report preparation;
- `freeLiquidity <= totalValue` on the remote side;
- `strategyId / chainId` validation on the home-side settler;
- monotonic `reportTimestamp`;
- stale-report rejection based on per-strategy `maxReportDelay`.

## Validation

Covered in:

- [`test/mocking/RemoteStrategyAgent.t.sol`](../test/mocking/RemoteStrategyAgent.t.sol)
- [`test/mocking/ReportSettler.t.sol`](../test/mocking/ReportSettler.t.sol)
- [`test/mocking/CrossChainERC4626Pipeline.t.sol`](../test/mocking/CrossChainERC4626Pipeline.t.sol)

Current validation confirms that:

- bad liquidity reports are rejected before settlement;
- stale reports are rejected by the home-side settler;
- accepted reports feed back into home-side strategy state, `totalAssets()`, and redemption previews.
