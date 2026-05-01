# Cross-Chain Vault Sprint 1 Closeout

Closeout date: **2026-04-01**

## Status

`Completed`

Sprint 1 is closed as the **architecture freeze and semantic alignment** phase.

## What Was Closed

Sprint 1 closed the following architectural decisions:

- target architecture is fixed as a `hybrid cross-chain vault`;
- source of truth is split between on-chain contracts and the off-chain ledger;
- delayed redemption is recognized as part of the target UX;
- liquidity buffers are recognized as explicit design objects;
- old bridge-first sequencing is replaced with product-first sequencing;
- the previous `contracts/crosschain` iteration is recorded as foundation, not as final architecture.

## Approved Baseline Documents

Sprint 1 is based on the following approved document package:

- [Hybrid Cross-Chain Vault Architecture](hybrid-crosschain-vault-architecture.md)
- [ADR-002 Ledger and NAV Model](adr-002-ledger-and-nav-model.md)
- [ADR-003 Redemption SLA and Liquidity Buffers](adr-003-redemption-sla-and-liquidity-buffers.md)
- [Cross-Chain Vault Development Plan](crosschain-vault-sprints.md)

## Locked MVP Decisions

### Settlement Asset

The MVP uses a single settlement asset:

- `USDC`

Reasoning:

- the clearest user-facing stable asset for the first version;
- minimizes accounting and bridge complexity;
- aligns with current provider and routing assumptions.

### MVP Deployment Profile

The MVP rollout profile is:

- **product-facing entry chain**: `Arbitrum`
- **execution chains**: `Arbitrum` and `Base`
- **additional chains**: after MVP

This means:

- the first version does not have to launch as a full multi-entry deployment;
- the architecture is still designed as chain-specific entry architecture;
- the first production-style rollout may start with one entry vault and two execution environments.

### MVP Strategies

The MVP strategy families are:

- `Aave`
- `Morpho`

Additionally:

- `Compound` remains the closest post-MVP extension candidate;
- more complex execution venues are excluded from the first delivery wave.

Reasoning:

- a lending-first profile better matches early-stage risk posture;
- the repository already contains provider integrations and tests for these families;
- explainable NAV and redemption behavior are easier to build on top of lending strategies.

## On-Chain vs Off-Chain Ownership Boundaries

### On-Chain Owns

On-chain contracts are the source of truth for:

- user shares;
- asset custody on the entry / home side;
- withdrawal request ownership and status;
- accepted strategy states after settlement;
- role-based execution permissions;
- operation identifiers and state transitions required for settlement safety.

### Off-Chain Owns

Off-chain services are the source of truth for:

- the global ledger;
- historical chain residency;
- NAV composition and user-facing portfolio interpretation;
- bridge lifecycle tracking;
- routing decisions;
- redemption orchestration;
- reconciliation;
- degraded mode and incident operations.

### Explicit Constraint

No off-chain actor may:

- mint or burn user shares directly;
- unilaterally change on-chain ownership;
- fabricate user balances outside accepted report / settlement flow.

## Semantic Decisions Locked in Sprint 1

### Entry Layer

- The entry vault is an interface layer and the point where user ownership is represented.
- The entry vault does not have to be where capital physically remains at all times.

### Accounting Layer

- The user-facing balance must be one product balance.
- NAV must be derived from accepted state and the ledger, not from ad hoc remote polling.

### Routing Layer

- Routing decisions must be based on `net benefit`, not raw APR.
- The booster / buffer layer is a service layer, not a separate user-facing product.

### Redemption Layer

- The product does not promise strict instant withdrawal.
- The product promises fast withdrawal when local liquidity exists and delayed redemption otherwise.
- Target normal-mode SLA: about `15 minutes`.

## What Is Explicitly Deferred to Sprint 2+

- final `CrossChainVault vs EntryVault wrapper` decision;
- detailed ledger event schema;
- exact buffer sizing formula;
- exact rebalance threshold formula;
- full bridge implementation;
- remote execution implementation;
- final post-MVP multi-entry rollout.

## Consequences for Sprint 2

The next phase begins without architectural ambiguity.

Sprint 2 must assume that:

- `CrossChainVault` and related contracts are the accounting/control-plane foundation;
- older single-home-chain wording in existing docs must be interpreted through the new ADRs;
- implementation work now starts from ledger/NAV revision, not from bridge integration.
