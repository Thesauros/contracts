# Bridge Incident Baseline

Date: **2026-04-03**

## Purpose

This document defines the minimum incident baseline for bridge transport failures in the current MVP.

## Incident Classes

### 1. Unknown or Misconfigured Peer

Symptoms:

- dispatch or receive attempts revert with peer validation errors.

Operator action:

- stop new dispatches to the affected endpoint;
- verify `setPeer(eid, peer)` configuration;
- avoid retrying the same message until peer configuration is confirmed.

### 2. Inbound Replay Attempt

Symptoms:

- inbound delivery reverts as replayed.

Operator action:

- treat the original inbound message as the only valid delivery;
- classify the replay as transport duplication, not as a new settlement event.

### 3. Missing Acknowledgement

Symptoms:

- outbound message remains unacknowledged past `timeoutAt`.

Operator action:

- classify the message as recovery-eligible;
- confirm whether remote side has actually processed the message;
- if unresolved, use `failMessage(messageId, refundReceiver)` to move the message into a recoverable failed state.

### 4. Escrowed Asset Stuck in Transport

Symptoms:

- outbound asset remains in adapter escrow while the message is neither acknowledged nor failed.

Operator action:

- monitor timeout progression;
- after timeout, refund through the failure path;
- reconcile allocator and vault-side operation status accordingly.

## Baseline Operational Rules

- acknowledged messages must not be failed later;
- failed messages must not be acknowledged later;
- recovery requires timeout eligibility;
- bridge refunds are governance-controlled in the current MVP;
- backend incident classification must not mutate custody directly.

## MVP Recovery Path

The current recovery path is:

1. detect message timeout
2. confirm message is still unacknowledged
3. call `failMessage`
4. refund escrowed asset to the designated recovery receiver
5. continue higher-level operation handling through governance or keeper workflow

## Out of Scope

This baseline does not yet define:

- automated retry policies;
- multi-bridge failover;
- vendor-specific root cause codes;
- user-facing degraded-mode communication;
- backend-driven auto-recovery execution.
