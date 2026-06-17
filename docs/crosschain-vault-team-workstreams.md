# Cross-Chain Vault: Workstreams for QA and Backend

Current as of: **2026-04-07**

This document translates the current cross-chain vault state into concrete workstreams for two roles:

- QA
- Backend

Target topology:

- home chain: **Base**
- remote chain: **Arbitrum**
- bridge: **Stargate only**

## 1. QA Workstream

### QA-01. Build the full E2E test matrix

Priority: **High**

Objective:

- define the full verification matrix for `Base -> Arbitrum -> Base`

Scope:

- deposit on Base
- allocation operation creation
- bridge dispatch
- remote receive
- remote execute allocate
- attested report on home chain
- recall flow
- delayed withdrawal path

Expected output:

- one table with:
  - scenario name
  - preconditions
  - steps
  - expected result
  - actual result
  - status

Definition of done:

- every core lifecycle step is covered by at least one explicit test case
- no critical lifecycle step remains undocumented

### QA-02. Run the core happy-path on testnet

Priority: **High**

Objective:

- verify the primary business flow works end-to-end on deployed contracts

Scope:

- deposit
- allocate
- report
- recall
- report refresh after recall

Expected output:

- test execution report with:
  - transaction hashes
  - timestamps
  - expected and actual state transitions
  - final status

Definition of done:

- the full happy-path passes without manual state repair
- all transaction hashes are recorded

### QA-03. Validate the role matrix

Priority: **High**

Objective:

- verify that privileged methods are callable only by expected roles

Scope:

- allocator permissions
- keeper permissions
- bridge permissions
- report attestor path
- governance-only config changes

Expected output:

- role matrix with:
  - role
  - address
  - permitted actions
  - forbidden actions

Definition of done:

- all critical methods are tested with authorized and unauthorized callers
- every unauthorized call reverts as expected

### QA-04. Run incident scenarios

Priority: **High**

Objective:

- verify degraded and failure paths before audit

Scope:

- stale report
- wrong peer configuration
- low local buffer
- delayed withdrawal
- unauthorized claim or cancellation
- report chain mismatch

Expected output:

- incident report with:
  - trigger
  - expected system behavior
  - actual system behavior
  - pass/fail
  - blocker or non-blocker

Definition of done:

- minimum incident pack is executed
- blockers are clearly identified

### QA-05. Build a regression checklist for every new deploy

Priority: **Medium**

Objective:

- reduce repeated mistakes during future testnet and pre-mainnet runs

Scope:

- env sanity
- role wiring
- peer wiring
- strategy configuration
- first deposit
- first report

Expected output:

- short reusable checklist for every new deployment

Definition of done:

- checklist is short enough to use operationally
- checklist catches the most common deployment/configuration failures

## 2. Backend Workstream

### BE-01. Implement report attestation service

Priority: **High**

Objective:

- support `submitReportAttested` with a controlled signing flow

Scope:

- generate report payload
- compute EIP-712 digest
- sign with the configured attestor key
- submit or hand off the signed payload

Expected output:

- service or CLI that:
  - builds payload
  - signs payload
  - stores version / signer metadata

Definition of done:

- a signed report can be produced deterministically
- payload format is versioned and auditable

### BE-02. Build an operation timeline indexer

Priority: **High**

Objective:

- reconstruct the lifecycle of each operation from chain events

Scope:

- ingest events from:
  - vault
  - allocator
  - settler
  - bridge
- group them by `opId`

Expected output:

- one operation timeline view with:
  - operation id
  - current status
  - transaction history
  - timestamps
  - chain context

Definition of done:

- for any `opId` the full history can be reconstructed without manual log digging

### BE-03. Implement accounting reconciliation

Priority: **High**

Objective:

- detect divergence between expected and actual accounting state

Scope:

- `homeIdle`
- `pendingBridgeIn`
- `pendingBridgeOut`
- `currentDebt`
- `lastReportedValue`
- funded withdrawal obligations

Expected output:

- reconciliation job or service
- mismatch report with severity

Definition of done:

- reconciliation runs on a schedule
- mismatches produce a clear error output

### BE-04. Add operational alerts

Priority: **High**

Objective:

- surface failures before they become hidden state drift

Scope:

- stale report
- stuck operation
- missing report after remote execution
- peer configuration drift
- delayed withdrawal taking too long

Expected output:

- alert rules
- threshold definitions
- notification targets

Definition of done:

- each critical alert has:
  - trigger condition
  - severity
  - owner

### BE-05. Build operator tooling

Priority: **Medium**

Objective:

- make operational actions repeatable and safe

Scope:

- create operation
- progress operation status
- send report
- inspect current state
- verify role/config readiness

Expected output:

- CLI or small operator service for repetitive operational actions

Definition of done:

- common manual actions can be performed with a controlled tool instead of ad hoc calls

### BE-06. Build an audit trail for critical actions

Priority: **Medium**

Objective:

- preserve accountability for all privileged and operational actions

Scope:

- who triggered the action
- which key or signer was used
- what payload was sent
- when the action happened

Expected output:

- structured audit log for:
  - report signing
  - operation creation
  - status progression
  - configuration changes

Definition of done:

- critical actions are traceable end-to-end
- logs are usable for incident review and audit preparation

## 3. Recommended Order

### First priority

- QA-01
- QA-02
- QA-03
- QA-04
- BE-01
- BE-02
- BE-03
- BE-04

### Second priority

- QA-05
- BE-05
- BE-06

## 4. Management Expectation

If both streams are executed properly, the result should be:

- repeatable testnet verification
- visible operation lifecycle
- auditable report signing
- clear alerting on drift and stuck states
- lower operational risk before audit and pre-mainnet rollout

