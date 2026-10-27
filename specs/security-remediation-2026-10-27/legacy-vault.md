---
title: Legacy vault security remediation design
date: 2026-10-27
status: approved-for-local-implementation
project: thesauros-legacy-contracts
author: product-cto-security
---

# Change: security-remediation-2026-10-27

Applies only to selected SC-005/006/007/008/009, with SC-006 only in contracts master/dev.
Product outcome: a holder can use known healthy alternative liquidity without forfeiting an unknown funded claim; provider configuration cannot double count or silently hide backing; every positive exit charges the final upward-rounded shares. This is deterministic security remediation of reviewed defects; new product discovery is not applicable. User authorized local fixes/branches/commits and forbids push/deployment.

## Required behavior and chosen design

- Strict totalAssets reads every listed funded position. A failed NAV view aborts pricing and settlement; no catch-to-zero or deferred-claim product is introduced. Include idle underlying assets in NAV and withdrawal liquidity.
- Withdraw across all listed providers, isolate individual action reverts, measure actual underlying balance deltas, and stop only after enough assets have arrived. Revert the entire transaction on aggregate shortfall; shares/allowance/fees cannot survive an unsuccessful exit. A provider returning true without paying contributes zero receipts.
- Reject any request above owner asset/share limits rather than proportional clamping. Withdraw uses original ceil preview against unchanged complete NAV; redeem burns the explicitly requested shares after enforcing owner limits. Final positive assets/shares required, allowance spent for exactly final shares.
- At constructor and timelocked setProviders reject empty lists, zero/non-contract adapters, duplicate adapter addresses and duplicate resolved economic source addresses. Existing mocks model independent positions using distinct deterministic source identities.
- Capture approval source for each listed adapter. Reject a retained adapter whose source has changed. Check source identity before NAV views/actions. Removed adapters must have a successfully read zero position, then revoke their recorded old allowance. An active adapter cannot be silently removed; a valid remaining adapter becomes active through the existing event path.
- If an approval source exposes ERC20 balanceOf, a nonzero receipt-token position also blocks removal even when recoverable NAV rounds to zero. This preserves known recovery claims after total loss. Non-token approval sources continue to use the provider's strict balance view.
- Registry setYieldToken/setMarket keep existing signatures but bind each nonzero mapping once; identical writes are idempotent, zero/retarget attempts revert. Migration uses a distinct registry identifier/new adapter, zeroes the old position through the existing rebalance path, and changes the list through vault timelock. No overwrite API is added. This also makes the registry owner unable to hide a funded position immediately.
- contracts Morpho valuation caps book value by recoverable expected market supply, excludes skimmable idle assets in supported MetaMorpho V1/V1.1, accounts for pending performance-fee shares with upstream floor rounding and virtual-share offset, and uses the same effective asset basis consistently. Missing required upstream accounting fields revert rather than assume a favorable value. Tests cover V1 and V1.1 semantics, losses, pending fees and zero positions.

## Compatibility and rollout

Legacy vaults are constructor deployments, not upgraded proxies. New code requires deployment and a separately reviewed migration; this task performs neither. Registry mappings become immutable after initial configuration: integrations which previously overwrite entries must use a distinct identifier/adapter. Source pinning intentionally rejects changing a listed source behind the vault. Withdraw/redeem over-limit requests now revert. Strict source uniqueness is conservative for adapters sharing an approval source and asset; such multi-position integration needs a reviewed canonical position-identity API before admission.

No unselected fee/HWM/roles issue is changed. Existing unrelated source, repository refs and untracked files are preserved using separate worktrees. Native exact0.8.23 compiler may be unusable on ARM: portable solcjs exact0.8.23 and local Foundry EVM are used without fork, dotenv or production RPC.

## Acceptance

Actual-contract local EVM checks must prove: empty active provider/later liquidity succeeds; first action revert later liquidity succeeds with full NAV; unknown funded NAV reverts without share burn; insufficient/zero/partial receipts cannot settle unpaid assets; duplicate/alias/list-removal and source retarget rejection; zero-balance migration revokes historic approvals; oversized/dust/zero-allowance exits reject and exact share rounding holds; MetaMorpho recoverable assets, fee dilution and virtual shares match upstream model. Compile all production sources, run selected existing local suites as compatibility permits, document deliberate changes to old clamp/mutable-registry expectations. Root QA independently checks the written requirements.

## Reproduce local verification

Use Foundry with exact solc0.8.23. Portable testing requires solc@0.8.23 and @openzeppelin/contracts@5.4.0 available in node_modules; existing tracked forge-std and morpho-blue submodules must be present at their pinned commits. They were populated from existing local copies; no version changes are committed. Run SECURITY_FORGE=/path/to/forge node scripts/test-security.cjs for selected regressions. Run the same command with --compat for existing local mocking suites (applicable in four legacy main repos). The runner records compact actual-EVM results in changes/security-remediation-2026-10-27/ and never loads the Hardhat config or a production .env. Fork suites are outside this local validation.

MetaMorpho reference semantics: https://github.com/morpho-org/metamorpho/blob/main/src/MetaMorpho.sol and https://github.com/morpho-org/metamorpho-v1.1/blob/main/src/MetaMorphoV1_1.sol. Both use virtual shares/assets and floor-rounded pending performance fee shares; V1.1 may retain lostAssets in book NAV. The adapter reconstructs recoverable market supply and caps the upstream quote accordingly. No live deployment/version was queried.
