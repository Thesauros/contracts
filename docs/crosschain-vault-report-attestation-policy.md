# Cross-Chain Vault Report Attestation Policy

Current as of **2026-04-10**.

## Purpose

Define who is allowed to attest strategy reports, how replay is prevented, and how governance manages signer rotation.

## Attestation Model

- Reports are accepted on the home chain via `ReportSettler.submitReportAttested(...)`.
- Each report is signed off-chain by a **REPORT_ATTESTOR_ROLE** address.
- The on-chain `ReportSettler` verifies the EIP-712 signature against the report payload.
- Non-attested reports (`submitReport(...)`) are allowed only when `attestationRequired == false`.

## Signed Payload

The report signature covers the following fields:

- `strategyId`
- `chainId`
- `totalValue`
- `freeLiquidity`
- `totalDebt`
- `pnl`
- `reportTimestamp`
- `positionsHash`

Domain parameters:

- name: `CrossChainVaultReport`
- version: `1`
- chainId: current chain id
- verifyingContract: `ReportSettler`

## Replay Protection

Replay protection is enforced by **strictly increasing `reportTimestamp` per strategy**:

- `ReportSettler` rejects reports with `reportTimestamp` <= last accepted report.
- EIP-712 domain includes `chainId` and `verifyingContract`, preventing cross-chain replay.

## Governance Workflow

1. Governance grants `REPORT_ATTESTOR_ROLE` to approved signer(s).
2. Governance can revoke a signer via role revocation.
3. Governance enables mandatory attestation by setting `attestationRequired = true`.
4. Emergency response:
   - revoke compromised signer
   - rotate to a new signer
   - verify test report acceptance before resuming normal operations

## Operational Notes

- Attestors must sign reports only after validating remote strategy state.
- Off-chain signer should log: report hash, strategy id, chain id, and report timestamp.
- Governance should maintain a signer rotation runbook and key custody policy.
