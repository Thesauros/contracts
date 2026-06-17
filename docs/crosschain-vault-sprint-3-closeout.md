# Cross-Chain Vault Sprint 3 Closeout

Closeout date: **2026-04-02**

## Objective

Sprint 3 was intended to make redemption semantics explicit and enforceable in the current contract layer.

## Completed Deliverables

### 1. Redemption Flow Spec

Delivered in:

- [Redemption Flow Spec](redemption-flow-spec.md)

Result:

- instant vs delayed decision rule is explicit;
- funding and claim hooks are defined;
- normal and degraded mode behavior is documented.

### 2. Buffer Policy v1

Delivered in:

- [Buffer Policy v1](buffer-policy-v1.md)

Result:

- home-side buffer target and residual floor are separated;
- MVP residual-liquidity enforcement is defined.

### 3. Queue Lifecycle Matrix

Delivered in:

- [Queue Lifecycle Matrix](queue-lifecycle-matrix.md)

Result:

- queue statuses and transitions are explicit;
- timestamp semantics for monitoring are fixed.

### 4. Contract Updates

Delivered in:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)
- [`contracts/interfaces/crosschain/ICrossChainVault.sol`](../contracts/interfaces/crosschain/ICrossChainVault.sol)
- [`contracts/interfaces/crosschain/IWithdrawalQueue.sol`](../contracts/interfaces/crosschain/IWithdrawalQueue.sol)
- [`contracts/libraries/CrossChainTypes.sol`](../contracts/libraries/CrossChainTypes.sol)

Result:

- queue lifecycle now includes `Processing`;
- queue requests now record `updatedAt`, `fundedAt`, and `claimedAt`;
- instant capacity respects `minimumResidualLiquidity`;
- manual degraded mode and delayed-funding pause are exposed;
- orchestrator start/fund hooks are explicit.

## Exit Criteria Check

### withdrawal semantics match `ADR-003`

Met for current contract scope.

- instant vs delayed behavior is explicit;
- home-side liquidity is the first funding source;
- residual-liquidity protection is enforced.

### queue covers required statuses

Met.

- `Pending`, `Processing`, `Funded`, `Claimed`, and `Cancelled` are represented and transition-checked.

### target SLA is defined for normal and degraded mode

Met.

- current defaults are `15 minutes` for normal mode and `60 minutes` for degraded mode;
- both are governance-configurable.

### MVP buffer policy is approved

Met for the current repo.

- accounting target and residual execution floor are both defined.

## Deferred Beyond Sprint 3

The following remain outside the current Sprint 3 contract closeout:

- automatic degraded-mode switching from bridge incidents;
- dynamic buffer sizing formulas;
- queue prioritization rules;
- full remote recall funding-order automation;
- user-facing messaging and UI semantics.
