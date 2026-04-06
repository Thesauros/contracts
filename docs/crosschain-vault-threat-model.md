# Cross-Chain Vault Threat Model (Sprint 9)

Current as of **2026-04-06**.

## Assets to Protect

- user shares (ownership and redemption correctness)
- vault asset custody on entry/home side
- accounting integrity (`homeIdle`, NAV buckets, funded obligations)
- operation correlation integrity (`opId`, `bridgeMessageId`, payload hash)

## Trust and Roles

- governance: config changes, emergency actions
- keeper: operational state transitions, funding actions, settlement sync
- bridge: asset + message transport and acknowledgements
- reporter: strategy reports (in MVP this is trusted; signer policy is deferred)

## Major Attack Surfaces

- bridge message replay, spoofing, or peer misconfiguration
- stale/incorrect reports used for NAV and redemption previews
- unsafe routing decisions (moving capital for negative net benefit, or breaking buffers)
- role misuse (keeper/bridge/reporter acting outside policy)
- accounting drift between on-chain and off-chain ledgers

## Key Mitigations in Current MVP

- explicit operation lifecycle + replay checks in bridge adapter layer
- report acceptance rejects stale/outdated reports (per-strategy freshness)
- allocation/recall accounting sync is gated and observable on-chain
- delayed redemption queue isolates funding lifecycle from immediate withdrawals
- Sprint 8 policy/risk guardrails enforce basic per-strategy limits and buffer-aware allocation caps

## Open Items / Deferred

- production report attestation/signer policy
- chain-level exposure caps enforced on-chain (per-chain config module)
- full incident runbooks integrated with backend/orchestrator and monitoring

