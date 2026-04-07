# Cross-Chain Vault Testnet Rehearsal Runbook

Current as of: **2026-04-06**

Goal: run an end-to-end rehearsal on testnet(s) that exercises the operational lifecycle, accounting sync, reporting, and redemption under normal and degraded modes.

## Preconditions

- deployment wallets and governance/guardian/keeper keys are prepared
- RPC endpoints are configured
- Base + Arbitrum are the default target chains in this project
- Stargate is the only supported bridge choice (peer config uses Stargate/LayerZero eids)
- chosen bridge adapter is deployed and peers are configured
- at least one remote strategy agent is deployed on the remote chain
- a backend ledger is ready to ingest events and reconcile NAV buckets

## Rehearsal Tracks

### Track 0: Local Dry Run (Anvil)

Before testnet, validate the lifecycle locally with the Foundry script:

- [`scripts/LocalRehearsal.s.sol`](../scripts/LocalRehearsal.s.sol)

Example commands:

`anvil`

`PRIVATE_KEY=<anvil_private_key> forge script scripts/LocalRehearsal.s.sol:LocalRehearsal --rpc-url http://127.0.0.1:8545 --broadcast`

### Track 0b: Deploy Scripts (Base/Arbitrum)

Home chain (Base) stack:

- [`scripts/deploy/DeployCrossChainHome.s.sol`](../scripts/deploy/DeployCrossChainHome.s.sol)

Remote chain (Arbitrum) agent + bridge + mock ERC4626 path:

- [`scripts/deploy/DeployCrossChainRemote.s.sol`](../scripts/deploy/DeployCrossChainRemote.s.sol)

Peer wiring (Stargate/LayerZero EIDs):

- [`scripts/deploy/ConfigureStargatePeers.s.sol`](../scripts/deploy/ConfigureStargatePeers.s.sol)

Environment template:

- [`.env.crosschain.example`](../.env.crosschain.example)

Notes:

- run `forge script` with `--offline` to avoid Foundry/macOS proxy crashes during signature identification;
- peer configuration requires `PEER_EID` and `PEER` (`bytes32`) values for the target chain.
  - `PEER` should be the remote bridge adapter `localPeer()` value.
  - do not guess EIDs: use the Stargate/LayerZero official values for Base/Arbitrum.

### Track A: Happy Path Lifecycle

1. Deploy:
   - `StrategyRegistry`, `StrategyAllocator`, `ReportSettler`, `WithdrawalQueue`, `CrossChainVault`
2. Configure roles:
   - `GOVERNANCE_ROLE` and `GUARDIAN_ROLE` to multisig (or timelock)
   - `KEEPER_ROLE` to keeper bot(s)
   - `BRIDGE_ROLE` to bridge adapter(s)
   - `REPORT_ATTESTOR_ROLE` (or `REPORTER_ROLE`) to the reporting authority
3. Configure one strategy in the registry:
   - chainId, agent address, asset address, debt limit, report delay, slippage
4. Deposit and confirm accounting:
   - deposit assets
   - verify `totalAssets()` and NAV buckets
5. Allocate:
   - `createOperation(Allocate)`
   - send bridge payload
   - `registerBridgeDispatch`
   - remote: execute allocate, prepare report
6. Report and settle:
   - home: submit report (prefer `submitReportAttested`)
   - verify `totalAssets()` updates and staleness windows behave as expected
7. Recall:
   - `createOperation(Recall)`
   - bridge home, `syncOperationAccounting`
   - confirm NAV buckets clear pending state

### Track B: Redemption Fairness and Buffer Stress

1. Create multiple withdrawal requests across multiple users.
2. Force low-buffer mode and verify:
   - instant vs delayed selection is correct
   - funding does not violate `minimumResidualLiquidity`
3. Verify cancellation and claim paths preserve user fairness and do not leak liquidity.

### Track C: Incident Rehearsal (Tabletop + On-Chain)

Run the scenarios enumerated in:

- [Cross-Chain Vault Incident Test Suite](crosschain-vault-incident-test-suite.md)

Minimum set:

- stale routing policy blocks new allocations
- chain mismatch and stale report rejection in `ReportSettler`
- unauthorized redemption actions revert

## Exit Artifacts

- deployed addresses per chain
- role assignment matrix used on testnet
- bridge peer config snapshot
- incident rehearsal notes and postmortems
- list of any required on-chain parameter changes before audit or mainnet
