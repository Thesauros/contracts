# Bridge Settlement MVP

Date: **2026-04-03**

## Goal

Define the minimum transport and settlement flow used by the current bridge layer.

## Implemented Transport Surface

Bridge transport is implemented in:

- [`contracts/interfaces/crosschain/IBridgeAdapter.sol`](../contracts/interfaces/crosschain/IBridgeAdapter.sol)
- [`contracts/crosschain/LayerZeroBridgeAdapter.sol`](../contracts/crosschain/LayerZeroBridgeAdapter.sol)

The current MVP surface includes:

- peer configuration per destination endpoint;
- outbound asset plus payload dispatch;
- inbound asset plus payload receipt;
- outbound acknowledgement;
- timeout-based recovery eligibility;
- governance-triggered failure handling with refund.

## Message Lifecycle

### 1. `sendAssetAndMessage`

The home side:

- validates the remote peer;
- escrows the settlement asset;
- records `messageId`, `nonce`, `payloadHash`, and `timeoutAt`;
- emits:
  - `MessageSent`
  - `AssetBridged`

### 2. `receiveAssetAndMessage`

The destination side:

- validates the source peer;
- rejects replayed inbound messages;
- records inbound delivery metadata;
- transfers bridged asset to the configured receiver;
- emits `MessageReceived`.

### 3. `acknowledgeMessage`

The source side:

- records remote acknowledgement for the outbound message;
- marks the message as `delivered` and `acknowledged`;
- records `ackHash` and `acknowledgedAt`;
- emits `MessageAcknowledged`.

### 4. `failMessage`

The source side:

- becomes eligible only after timeout if the message is still unacknowledged;
- marks the message as failed;
- refunds escrowed assets to the specified recovery receiver;
- emits `MessageFailed`.

## Settlement Meaning

For the current MVP, transport settlement means:

- the bridge message has either been acknowledged or failed after timeout;
- the bridge layer no longer treats the message as in-flight;
- higher-level accounting may continue with allocator and vault-side settlement.

This bridge settlement is intentionally separate from:

- allocator status progression;
- vault NAV synchronization;
- strategy reporting.

## Recovery Eligibility

Recovery is considered eligible when all of the following are true:

- the message exists;
- the message originated as an outbound dispatch;
- the message is not yet acknowledged;
- the message is not already failed;
- `block.timestamp >= timeoutAt`.

## Event Surface

The minimum event surface for bridge settlement is:

- `PeerConfigured`
- `MessageSent`
- `AssetBridged`
- `MessageReceived`
- `MessageAcknowledged`
- `MessageFailed`
- `MessageTimeoutUpdated`

## Validation

Validation exists in:

- [`test/mocking/LayerZeroBridgeAdapter.t.sol`](../test/mocking/LayerZeroBridgeAdapter.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)
