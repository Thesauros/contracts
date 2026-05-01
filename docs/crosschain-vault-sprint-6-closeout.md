# Cross-Chain Vault Sprint 6 Closeout

Closeout date: **2026-04-03**

## Objective

Sprint 6 was intended to integrate transport and settlement without breaking product accounting semantics.

## Completed Deliverables

### 1. Bridge Adapter MVP

Delivered in:

- [Bridge Settlement MVP](bridge-settlement-mvp.md)
- [`contracts/interfaces/crosschain/IBridgeAdapter.sol`](../contracts/interfaces/crosschain/IBridgeAdapter.sol)
- [`contracts/crosschain/LayerZeroBridgeAdapter.sol`](../contracts/crosschain/LayerZeroBridgeAdapter.sol)

Result:

- the bridge layer now supports send, receive, acknowledgement, timeout configuration, and timeout-based failure recovery;
- peer configuration and replay protection remain explicit.

### 2. Settlement Integration Path

Delivered in:

- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)

Result:

- the mock end-to-end path now includes bridge acknowledgement in addition to send and receive;
- recall settlement still reconciles home-side `pendingBridgeIn` back into vault liquidity.

### 3. Bridge Incident Baseline

Delivered in:

- [Bridge Incident Baseline](bridge-incident-baseline.md)

Result:

- the repo now defines the minimum timeout and recovery behavior for unacknowledged bridge messages;
- governance-driven refund is the current recovery baseline.

## Exit Criteria Check

### bridge lifecycle is integrated into the operation model

Met for the current MVP.

- bridge send, receive, acknowledgement, and failure states are explicit;
- the end-to-end mock pipeline exercises bridge acknowledgement alongside allocator and vault settlement.

### `pendingBridgeIn / pendingBridgeOut` match NAV assumptions

Met in the current mocked transport path.

- allocate transitions still move `homeIdle -> pendingBridgeOut -> currentDebt`;
- recall transitions still move `currentDebt -> pendingBridgeIn -> homeIdle`.

### transport failures become recoverable states

Met for the timeout-based MVP path.

- unacknowledged outbound messages become recovery-eligible after timeout;
- governance can fail and refund the message instead of leaving it indefinitely in escrow.

## Deferred Beyond Sprint 6

The following remain outside this Sprint 6 closeout:

- production LayerZero/Stargate vendor wiring;
- automatic retry orchestration;
- richer settlement acknowledgements tied directly into allocator state updates;
- incident dashboards and user-facing degraded-mode handling;
- multi-bridge or vendor failover logic.
