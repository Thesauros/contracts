# Contracts MVP Execution Scope

## What must live on-chain

- Vault custody and ERC4626 accounting
- Provider adapter abstraction
- Rebalancing execution
- Role-gated execution rights
- Timelocked admin changes
- Event emission for monitoring and auditability
- Hard risk limits that block unsafe rebalances

## What must stay off-chain

- Yield monitoring across providers
- Selecting the best provider at a given moment
- Rebalance scheduling
- CRM and FOMO dashboard logic
- Sales assumptions and campaign personalization

## Guardrails implemented in `VaultManager`

- Vault allowlist via `approvedVaults`
- Rebalance amount floor via `minRebalanceAmount`
- Max per-call vault outflow via `maxVaultOutflowBps`
- Max rebalance fee via `maxFeeBps`
- Optional minimum APR improvement via `minAprImprovementRay`
- Explicit block on same-provider rebalances

## Why this split

The protocol should not decide strategy on-chain. It should only enforce whether a proposed move is permitted.

In short:

- off-chain decides
- on-chain enforces
