---
title: Legacy remediation implementation and local EVM verification
date: 2026-10-27
status: ready-for-independent-qa
project: contracts-master
author: cto-agent
---

Change: security-remediation-2026-10-27

Specification: specs/security-remediation-2026-10-27/legacy-vault.md.

Implemented SC-005/007/008/009 in actual Vault and ProviderManager paths. Implemented SC-006 in MorphoProvider and its MetaMorpho accounting interface.

Local EVM: 27/27 selected security regressions pass, including128 rounding fuzz cases. Tests compile production sources with exact solc0.8.23+f704f362 and OpenZeppelin5.4.0, use a local Shanghai EVM and fake assets/providers. Unknown NAV, action failures, short/zero receipts, alternate/idle liquidity, duplicate exposure, nonzero receipt claims at zero NAV, source retarget, migration approvals and final rounding/allowance are covered. No pre-existing non-fork mocking suite exists on this baseline; live fork tests were not run.

Evidence: evm-security.json in this directory. Run SECURITY_FORGE=/path/to/forge node scripts/test-security.cjs.

Registry targets are now write-once. Migrate through a distinct identifier/adapter (or new ProviderManager) and a timelocked list expansion, rebalance to the new position, then remove the successfully emptied old position and revoke its recorded approval. Existing constructor vaults cannot be patched in place; deployment/migration requires a separately reviewed operational change. No proxy storage compatibility or live deployment has been asserted.

Independent root QA/Security review remains pending. No unselected finding was implemented. Original checkouts, deployment assets, branch refs and user changes were preserved. No pushes, deployment, production .env or live RPC.
