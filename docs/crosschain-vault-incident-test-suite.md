# Cross-Chain Vault Incident Test Suite (Sprint 9)

Current as of **2026-04-06**.

This document enumerates incident scenarios that should be covered by tests and rehearsals.

## Bridge Incidents

- Replay on receive: duplicate `bridgeMessageId` must be rejected
- Timeout without ack: operation remains recoverable and observable
- Message failure/refund: escrowed assets are recoverable under governance/bridge role
- Peer misconfiguration: sends to unknown peers must be rejected

## Report / Visibility Incidents

- Stale report: system enters degraded mode (visibility degraded)
- Allocation blocked when stale/degraded (policy)
- Report settlement rejects outdated timestamps and liquidity inconsistencies

## Redemption Stress and Fairness

- Withdrawal spike: buffer/residual preserved, delayed queue works
- Funding cannot violate `minimumResidualLiquidity`
- Cancellation safety: pending/processing requests can be cancelled and shares returned
- Claim safety: only owner/receiver can claim; funded obligations remain consistent

## Routing / Execution Incidents

- Debt cap exceeded: allocation operation creation is rejected
- Emergency-only strategy: only recall/emergency operations allowed
- Deposits disabled: allocation rejected; withdrawals disabled: recall rejected
- Min-out too low: operation creation rejected based on `maxSlippageBps`

## Notes

- Fork-based incidents (real RPC, congestion, live protocol edge-cases) should be rehearsed separately.
- Foundry/macOS proxy panic for fork execution is an environment issue and is excluded from offline suites.

