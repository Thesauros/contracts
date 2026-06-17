# Cross-Chain Vault Sprint 5 Closeout

Closeout date: **2026-04-03**

## Objective

Sprint 5 was intended to bring routing and operation handling to an observable, idempotent operational model.

## Completed Deliverables

### 1. Operation Lifecycle Spec

Delivered in:

- [Routing Operation Lifecycle](routing-operation-lifecycle.md)

Result:

- allocator-side states and transitions are explicit;
- `Allocate`, `Recall`, `Harvest`, and `EmergencyExit` share one canonical lifecycle model;
- recall is explicitly tied to the delayed-redemption path.

### 2. Allocator State Machine Updates

Delivered in:

- [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)
- [`contracts/interfaces/crosschain/IStrategyAllocator.sol`](../contracts/interfaces/crosschain/IStrategyAllocator.sol)
- [`contracts/libraries/CrossChainTypes.sol`](../contracts/libraries/CrossChainTypes.sol)

Result:

- operations now carry `nonce`, `deadline`, and `lastUpdatedAt`;
- dispatch metadata is tracked separately from core operation state;
- status transitions and timestamps are explicit and queryable.

### 3. Backend Correlation Model

Delivered in:

- [Backend Correlation Model](backend-correlation-model.md)

Result:

- `opId`, `nonce`, `bridgeMessageId`, and `payloadHash` are fixed as the canonical identifiers;
- dispatch timestamps define one observable transport/execution timeline.

### 4. Mock Routing and Recall Validation

Delivered in:

- [`contracts/crosschain/LayerZeroBridgeAdapter.sol`](../contracts/crosschain/LayerZeroBridgeAdapter.sol)
- [`contracts/crosschain/RemoteStrategyAgent.sol`](../contracts/crosschain/RemoteStrategyAgent.sol)
- [`contracts/crosschain/MorphoStrategyAdapter.sol`](../contracts/crosschain/MorphoStrategyAdapter.sol)
- [`test/mocking/StrategyAllocator.t.sol`](../test/mocking/StrategyAllocator.t.sol)
- [`test/mocking/LayerZeroBridgeAdapter.t.sol`](../test/mocking/LayerZeroBridgeAdapter.t.sol)
- [`test/mocking/RemoteStrategyAgent.t.sol`](../test/mocking/RemoteStrategyAgent.t.sol)
- [`test/mocking/MorphoStrategyAdapter.t.sol`](../test/mocking/MorphoStrategyAdapter.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)

Result:

- the repo now has a working mock path for `allocate` and `recall`;
- remote execution is idempotent and bridge-linked;
- settlement back into vault accounting is validated end to end.

## Exit Criteria Check

### allocator does not touch user shares

Met.

- allocator state mutation is isolated from ERC4626 share accounting;
- user balances remain represented only by the home-side vault.

### recall flow is tied to redemption model

Met.

- recall execution feeds `pendingBridgeIn`, `receiveRecallFunds`, and final home-side settlement;
- the queued withdrawal model remains the consumer of returned home liquidity.

### lifecycle is observable and idempotent

Met.

- operation status, nonce, dispatch metadata, and timestamps are queryable;
- remote command replay and duplicate bridge-home actions are prevented by stored command state.

## Pulled Forward for Validation

The following were implemented early to validate the Sprint 5 lifecycle model, but do not by themselves close the later roadmap items:

- first bridge adapter MVP;
- first remote execution agent path;
- first Morpho strategy adapter path;
- one end-to-end transport plus settlement mock pipeline.

## Deferred Beyond Sprint 5

The following remain outside this Sprint 5 closeout:

- production bridge vendor hardening and incident baseline, which belong to Sprint 6;
- broader settlement policy and recovery playbooks;
- second remote execution path and fork-based validation, which belong to Sprint 7;
- multi-strategy remote reporting standardization beyond the first adapter path.
