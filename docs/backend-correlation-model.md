# Backend Correlation Model

Date: **2026-04-03**

## Goal

Define the identifiers and timestamps required to correlate home-side operations, bridge transport, remote execution, and final settlement.

## Primary Identifiers

### `opId`

The canonical business identifier for a routing operation.

Properties:

- unique per created operation;
- deterministic from allocator-side creation inputs plus nonce and timestamp;
- stable across transport and execution stages.

Defined in:

- [`contracts/crosschain/StrategyAllocator.sol`](../contracts/crosschain/StrategyAllocator.sol)

### `nonce`

Monotonic allocator-side sequence number.

Purpose:

- gives operators and backend systems an ordered sequence independent of event indexing;
- prevents ambiguity across otherwise similar operations.

### `bridgeMessageId`

Transport-layer identifier returned by the bridge adapter.

Purpose:

- ties one allocator operation dispatch to one transport emission;
- distinguishes multiple bridge events around the same strategy and asset.

### `payloadHash`

Hash of the encoded command payload used for transport and remote replay protection.

Purpose:

- confirms that dispatch registration, remote receipt, and remote execution all refer to the same command body;
- detects mismatched payload / `opId` combinations.

## Dispatch Record

The canonical correlation record is:

- [`CrossChainTypes.OperationDispatch`](../contracts/libraries/CrossChainTypes.sol)

Fields:

- `opId`
- `dstEid`
- `remoteAgent`
- `bridgeMessageId`
- `payloadHash`
- `dispatchedAt`
- `receivedAt`
- `executedAt`
- `settledAt`

## Timestamp Semantics

### `dispatchedAt`

- set when the bridge dispatch is registered on the allocator side.

### `receivedAt`

- set when the allocator operation is advanced into `Received`.

### `executedAt`

- set when the allocator operation is advanced into `Executed`.

### `settledAt`

- set when the allocator operation is advanced into `Settled`.

## Remote Correlation

Remote execution additionally keeps:

- command payload hash;
- command type;
- executed assets;
- remote `bridgeMessageId` for homeward transport after recall / harvest / emergency flows.

Implemented in:

- [`contracts/crosschain/RemoteStrategyAgent.sol`](../contracts/crosschain/RemoteStrategyAgent.sol)

## Correlation Rules

Backend consumers should treat the following as invariant:

- `opId` is the top-level business key;
- `bridgeMessageId` is the transport key;
- `payloadHash` is the content-integrity key;
- `strategyId + opType` are classification fields, not unique identifiers.

## Validation Surface

Mock validation exists in:

- [`test/mocking/StrategyAllocator.t.sol`](../test/mocking/StrategyAllocator.t.sol)
- [`test/mocking/LayerZeroBridgeAdapter.t.sol`](../test/mocking/LayerZeroBridgeAdapter.t.sol)
- [`test/mocking/RemoteStrategyAgent.t.sol`](../test/mocking/RemoteStrategyAgent.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)
