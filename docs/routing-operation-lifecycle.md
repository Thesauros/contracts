# Routing Operation Lifecycle

Date: **2026-04-03**

## Scope

This document fixes the operational lifecycle for routing-side actions initiated by the home-side allocator.

Covered operations:

- `Allocate`
- `Recall`
- `Harvest`
- `EmergencyExit`

## Lifecycle States

The canonical operation status enum is defined in:

- [`contracts/libraries/CrossChainTypes.sol`](../contracts/libraries/CrossChainTypes.sol)

States:

1. `Created`
2. `Sent`
3. `Received`
4. `Executed`
5. `Settled`
6. `Cancelled`
7. `Failed`

## Meaning of States

### `Created`

- operation exists on the home chain;
- no transport or accounting mutation is assumed yet.

### `Sent`

- outbound dispatch has been accepted by the routing layer;
- for `Allocate`, vault accounting may move capital from `homeIdle` into `pendingBridgeOut`;
- for `Recall`, this state is observable but does not yet move home-side assets.

### `Received`

- the remote side has accepted the command payload;
- command replay protection must already be in effect;
- the command becomes eligible for remote execution.

### `Executed`

- remote execution logic completed once;
- for `Allocate`, remote capital has been deployed into the strategy adapter;
- for `Recall`, remote capital has been freed and is ready to bridge home;
- for `Harvest` and `EmergencyExit`, the remote command has completed and the result is observable.

### `Settled`

- transport and accounting reached the stable post-execution state;
- for `Allocate`, `pendingBridgeOut` converges into `currentDebt`;
- for `Recall`, `pendingBridgeIn` converges back into `homeIdle`.

### `Cancelled`

- command is intentionally abandoned before stable completion;
- valid for earlier lifecycle windows defined by the allocator state machine.

### `Failed`

- command entered a terminal unsuccessful state;
- follow-up handling is expected from transport recovery or governance actions.

## Allowed Transitions

The allocator state machine permits:

- `Created -> Sent | Cancelled | Failed`
- `Sent -> Received | Cancelled | Failed`
- `Received -> Executed | Cancelled | Failed`
- `Executed -> Settled | Failed`

No terminal state may transition back into a non-terminal state.

## Idempotency Rules

Required idempotency properties:

- one `opId` represents one logical operation;
- one command payload hash maps to one remote command record;
- one received command can execute at most once;
- one executed recall/harvest/emergency command can bridge home at most once;
- one bridge message must not settle more than one operation.

## Routing Observability

Routing observability is exposed through:

- [`contracts/interfaces/crosschain/IStrategyAllocator.sol`](../contracts/interfaces/crosschain/IStrategyAllocator.sol)
- [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)

Observed fields include:

- `opId`
- `nonce`
- `strategyId`
- `opType`
- `status`
- `createdAt`
- `deadline`
- `lastUpdatedAt`
- dispatch timestamps:
  - `dispatchedAt`
  - `receivedAt`
  - `executedAt`
  - `settledAt`

## Relation to Redemption

`Recall` is explicitly tied to the delayed-redemption model:

- a queued withdrawal can remain pending while recall is in flight;
- once remote capital is executed and bridged home, vault-side accounting converts `pendingBridgeIn` back into home liquidity;
- the funding and claim path then proceeds through the existing queue lifecycle.

Relevant home-side logic:

- [`contracts/crosschain/CrossChainVault.sol`](../contracts/crosschain/CrossChainVault.sol)
- [`contracts/crosschain/WithdrawalQueue.sol`](../contracts/crosschain/WithdrawalQueue.sol)

## Validation

Mock validation of the lifecycle exists in:

- [`test/mocking/StrategyAllocator.t.sol`](../test/mocking/StrategyAllocator.t.sol)
- [`test/mocking/CrossChainVault.t.sol`](../test/mocking/CrossChainVault.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)
