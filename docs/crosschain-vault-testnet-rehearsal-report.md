# Cross-Chain Vault Testnet Rehearsal Report

Rehearsal date: **2026-05-01**

Status: **Preflight Passed, Track A Pending**

## Environment

- Home chain: Base (`8453`)
- Remote chain: Arbitrum (`42161`)
- Bridge vendor: Stargate / LayerZero transport configured and confirmed on-chain
- RPC endpoints: configured and reachable during preflight
- Deployed addresses (home): `StrategyRegistry` `0xCaFaF5f72235B1F10C92d57Db512C802ec1D9ad2`, `StrategyAllocator` `0x0dB5b3401f526E3dFE46dFCA2297745AA16D2884`, `ReportSettler` `0xA663142A0202A751f21B3122b7611d4B3E35d004`, `WithdrawalQueue` `0x17f223ae2BdE86dbC32574d12578e2A6F8380724`, bridge `0x6dD4a38b2Ad0482A5232c9030926dEB4845f7729`, `CrossChainVault` `0x8AD87BB0FE973A48e5C027E1C27A708BBe78a8Ae`
- Deployed addresses (remote): `AaveV3StrategyAdapter` `0xfAc846b296DA830A041217F32387763d31cE6998`, `RemoteStrategyAgent` `0xf04D182F9990040A395E65D0151A30dB6957a9Ed`, bridge `0xC1DDF8be4537875eC51e37BC560D991D1c809F81`

## Role Matrix

- Governance: configured on deployed contracts and confirmed on home bridge
- Guardian: configured in local env, not exercised in this preflight
- Keeper: granted on remote agent and new home vault
- Bridge: peer wiring, Stargate transport, send options, and bridge-role grants confirmed for allocator, vault, remote agent, and both new bridges
- Report attestors: granted on `ReportSettler`
- Reporter: granted on `RemoteStrategyAgent` as of tx `0xa5b7f34e9ba225817bcf09f9fb13b83f1bab769b1a912b7865ab9879d29d9667`

## Track A: Happy Path Lifecycle

- Deposit executed: not started
- Allocate executed: pending live rehearsal
- Report attested and accepted: pending live rehearsal
- Settle executed: not started
- Recall executed: not started
- Redemption executed: not started

## Track B: Redemption and Buffer Stress

- Instant vs delayed selection validated: not started
- Minimum residual liquidity enforced: not started
- Queue lifecycle validated: not started

## Track C: Incident Drill

- Bridge timeout scenario: not started
- Stale report scenario: not started
- Degraded mode scenario: not started

## Metrics

- Allocate end-to-end latency: n/a
- Report-to-settle latency: n/a
- Recall end-to-end latency: n/a
- Withdrawal SLA timing: n/a

## Issues Found

- `ReportSettler.getLastReport(1)` is still empty, confirming no accepted production-style report exists yet for the configured strategy.
- Full happy-path rehearsal is still not executed end-to-end; only deployment and preflight boundaries are closed.

## Severity

- Severity: medium
- Impact: the stack is now transport-ready, but operational validation of the full lifecycle still remains.

## Mitigations / Fixes

- After the fixes, rerun preflight before any broadcasted rehearsal transaction sequence.
- Execute the live rehearsal and capture timings, reports, and recovery behavior.

## Next Actions

- Execute Track A on the new bridge/vault addresses and record tx hashes for allocate, report, settle, and recall.
- Capture end-to-end timings and confirm `submitReportAttested(...)` plus `settleStrategyReport(...)` on the new vault path.
- Run the minimum incident drill set after the happy path succeeds.
