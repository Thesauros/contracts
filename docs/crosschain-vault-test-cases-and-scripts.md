# Cross-Chain Vault: Test Cases and Scripts

Current as of: **2026-04-07**

Target topology for this runbook:

- home chain: **Base**
- remote chain: **Arbitrum**
- bridge: **Stargate only**

This document is the single operational reference for:

- deployment scripts
- environment variables
- local rehearsal
- testnet smoke / E2E cases
- incident and regression cases

## 1. Scripts

### Local rehearsal

- [`scripts/LocalRehearsal.s.sol`](../scripts/LocalRehearsal.s.sol)

Purpose:

- deploy local mock stack
- run `deposit -> allocate -> attested report -> recall -> attested report`
- validate the accounting lifecycle without external RPC dependencies

### Home deployment (Base)

- [`scripts/deploy/DeployCrossChainHome.s.sol`](../scripts/deploy/DeployCrossChainHome.s.sol)

Deploys:

- `StrategyRegistry`
- `StrategyAllocator`
- `WithdrawalQueue`
- `ReportSettler`
- `StargateBridgeAdapter`
- `CrossChainVault`

Also configures:

- internal vault/queue wiring
- allocator roles
- vault roles
- report attestor role
- routing policy hook (`allocator.setRoutingPolicy(vault)`)
- optional initial strategy upsert

### Remote deployment (Arbitrum)

- [`scripts/deploy/DeployCrossChainRemote.s.sol`](../scripts/deploy/DeployCrossChainRemote.s.sol)

Deploys:

- optional `MockERC20`
- optional `MockERC4626Vault`
- `ERC4626StrategyAdapter`
- `RemoteStrategyAgent`
- `StargateBridgeAdapter`

Also configures:

- `KEEPER_ROLE` on remote agent
- `BRIDGE_ROLE` on remote agent
- `BRIDGE_ROLE` on remote bridge for the remote agent
- asset and adapter on the remote agent

### Peer wiring

- [`scripts/deploy/ConfigureStargatePeers.s.sol`](../scripts/deploy/ConfigureStargatePeers.s.sol)

Purpose:

- configure `eid -> peer` mapping on each `StargateBridgeAdapter`

Important:

- `PEER` must be the remote bridge adapter `localPeer()` value
- `PEER_EID` must be the official Stargate/LayerZero endpoint id for the remote chain

## 2. Environment

Template:

- [`.env.crosschain.example`](../.env.crosschain.example)

Meaning of key env vars:

- `BASE_RPC_URL`: RPC for Base
- `ARBITRUM_RPC_URL`: RPC for Arbitrum
- `PRIVATE_KEY`: deployer / operator key used by `forge script`
- `GOVERNANCE`: governance owner for contracts
- `KEEPER`: operator allowed to advance lifecycle and execute remote commands
- `ALLOCATOR`: address allowed to create operations on the home chain
- `REPORT_ATTESTOR`: signer granted `REPORT_ATTESTOR_ROLE`
- `DEPLOY_MOCK_ASSET`: when `true`, deploys `MockERC20` instead of using existing token
- `ASSET`: asset address for the chain where the script runs
- `UPSERT_STRATEGY`: when `true`, `DeployCrossChainHome.s.sol` inserts one initial strategy
- `REMOTE_CHAIN_ID`: remote EVM chain id used in `StrategyRegistry`
- `REMOTE_AGENT`: deployed `RemoteStrategyAgent` address
- `DEPLOY_MOCK_ERC4626`: when `true`, deploys a mock ERC4626 vault on Arbitrum for rehearsal
- `BASE_EID` / `ARBITRUM_EID`: Stargate/LayerZero endpoint ids
- `HOME_BRIDGE_ADAPTER` / `REMOTE_BRIDGE_ADAPTER`: deployed bridge adapters
- `HOME_PEER` / `REMOTE_PEER`: `localPeer()` values of each deployed bridge adapter

## 3. Commands

### 3.1 Local rehearsal

Run local Anvil:

```bash
anvil
```

Run the local lifecycle:

```bash
cd /Users/ivanborisov/Desktop/thesauros/contracts
PRIVATE_KEY=<anvil_private_key> forge script --offline scripts/LocalRehearsal.s.sol:LocalRehearsal -vv
```

Expected checkpoints:

- `homeIdle after deposit`
- `homeIdle after allocate`
- `totalAssets after report`
- `homeIdle after recall settlement`
- `totalAssets after recall settlement`

### 3.2 Base deployment

Example:

```bash
cd /Users/ivanborisov/Desktop/thesauros/contracts
export PRIVATE_KEY=...
export GOVERNANCE=...
export KEEPER=...
export ALLOCATOR=...
export REPORT_ATTESTOR=...
export ASSET=...

forge script --offline scripts/deploy/DeployCrossChainHome.s.sol:DeployCrossChainHome \
  --rpc-url "$BASE_RPC_URL" \
  --broadcast -vv
```

### 3.3 Arbitrum deployment

Example:

```bash
cd /Users/ivanborisov/Desktop/thesauros/contracts
export PRIVATE_KEY=...
export GOVERNANCE=...
export KEEPER=...
export STRATEGY_ID=1
export ASSET=...
export DEPLOY_MOCK_ERC4626=true

forge script --offline scripts/deploy/DeployCrossChainRemote.s.sol:DeployCrossChainRemote \
  --rpc-url "$ARBITRUM_RPC_URL" \
  --broadcast -vv
```

### 3.4 Stargate peer wiring

On Base:

```bash
export BRIDGE_ADAPTER=<home_bridge_adapter>
export PEER_EID=<arbitrum_eid>
export PEER=<remote_bridge_local_peer>

forge script --offline scripts/deploy/ConfigureStargatePeers.s.sol:ConfigureStargatePeers \
  --rpc-url "$BASE_RPC_URL" \
  --broadcast -vv
```

On Arbitrum:

```bash
export BRIDGE_ADAPTER=<remote_bridge_adapter>
export PEER_EID=<base_eid>
export PEER=<home_bridge_local_peer>

forge script --offline scripts/deploy/ConfigureStargatePeers.s.sol:ConfigureStargatePeers \
  --rpc-url "$ARBITRUM_RPC_URL" \
  --broadcast -vv
```

## 4. Post-Deploy Verification

Before any E2E flow, verify:

- `allocator.routingPolicy() == vault`
- `registry` granted `VAULT_ROLE` to `vault`
- `queue` granted `VAULT_ROLE` to `vault`
- `allocator` granted:
  - `ALLOCATOR_ROLE` to the chosen operator
  - `KEEPER_ROLE` to the chosen keeper
  - `BRIDGE_ROLE` to the home bridge adapter
- `vault` granted:
  - `KEEPER_ROLE` to the keeper
  - `BRIDGE_ROLE` to the home bridge adapter
- `settler` granted `REPORT_ATTESTOR_ROLE`
- `remoteAgent` granted:
  - `KEEPER_ROLE`
  - `BRIDGE_ROLE` to the remote bridge adapter
- remote bridge granted `BRIDGE_ROLE` to `remoteAgent`
- peers are configured both directions
- if `UPSERT_STRATEGY=true`, `StrategyRegistry.getStrategyConfig(strategyId)` points to:
  - `chainId = Arbitrum chain id`
  - `agent = remoteAgent`
  - `asset = expected asset`

## 5. Core Test Cases

### TC-01: Home deploy succeeds

Objective:

- validate the Base stack deploys and roles are wired

Expected result:

- all home contracts deploy
- no zero addresses
- vault/allocator/settler/queue/bridge addresses recorded

### TC-02: Remote deploy succeeds

Objective:

- validate the Arbitrum stack deploys and remote agent is executable

Expected result:

- adapter, agent, bridge deploy
- asset and strategy adapter are configured on the remote agent

### TC-03: Stargate peer configuration succeeds

Objective:

- validate each bridge recognizes the other chain peer

Expected result:

- `setPeer` succeeds on both chains
- `localPeer()` values are recorded in artifacts

### TC-04: Strategy registry configuration is correct

Objective:

- validate the home strategy points to the right remote chain/agent

Expected result:

- `StrategyRegistry.getStrategyConfig(strategyId)` returns correct `chainId`, `agent`, `asset`

### TC-05: Deposit updates home-side accounting

Objective:

- validate user deposit increases `homeIdle` and `totalAssets`

Expected result:

- `vault.deposit(...)` succeeds
- `homeIdle` increases
- `totalAssets()` reflects the deposit

### TC-06: Allocate operation lifecycle

Objective:

- validate `createOperation(Allocate)` and status transitions are consistent

Expected result:

- operation moves `Created -> Sent -> Received -> Executed -> Settled`
- `syncOperationAccounting` updates:
  - on `Sent`: `homeIdle` decreases, `pendingBridgeOut` increases
  - on `Settled`: `pendingBridgeOut` decreases, `currentDebt` increases

### TC-07: Remote receive + execute allocate

Objective:

- validate remote agent can receive bridged payload and deploy capital

Expected result:

- `receiveBridgeAsset(...)` accepts the command
- `executeAllocate(...)` succeeds
- remote `idleAssets` decreases
- remote `deployedAssets` increases

### TC-08: Attested report accepted on home chain

Objective:

- validate EIP-712 attestation path works

Expected result:

- `submitReportAttested(...)` succeeds for authorized signer
- `vault.settleStrategyReport(strategyId)` succeeds
- `lastReportedValue`, `freeLiquidity`, `currentDebt`, `lastReportTimestamp` update

### TC-09: Recall lifecycle

Objective:

- validate recall accounting and asset return path

Expected result:

- recall operation moves through statuses
- on `Executed`: `currentDebt` decreases, `pendingBridgeIn` increases
- `receiveRecallFunds(...)` increases `homeIdle`
- on `Settled`: `pendingBridgeIn` decreases

### TC-10: Post-recall report refresh

Objective:

- validate `totalAssets()` is refreshed after strategy TVL changes

Expected result:

- second attested report after recall is accepted
- `lastReportedValue` reflects reduced remote TVL
- `totalAssets()` reconciles correctly

## 6. Redemption and Buffer Cases

### TC-11: Instant withdrawal when liquidity is sufficient

Expected result:

- `maxWithdraw(owner) > 0`
- withdraw/redeem succeeds immediately

### TC-12: Delayed withdrawal when buffer would be violated

Expected result:

- request is queued
- status moves through `Pending -> Processing -> Funded -> Claimed`
- `minimumResidualLiquidity` is preserved

### TC-13: Cancellation returns shares

Expected result:

- pending/processing withdrawal can be cancelled by the authorized path
- user shares are returned

### TC-14: Claim authorization is enforced

Expected result:

- unauthorized caller cannot claim someone else’s funded withdrawal

### TC-15: Funding does not exceed available liquidity

Expected result:

- `fundedWithdrawalObligations` stays bounded by available home liquidity

## 7. Risk and Incident Cases

Reference source:

- [Cross-Chain Vault Incident Test Suite](crosschain-vault-incident-test-suite.md)

### TC-16: Stale report blocks allocation

Expected result:

- stale strategy visibility causes degraded mode
- new allocation is blocked by routing policy / allocator checks

### TC-17: Outdated report timestamp is rejected

Expected result:

- `ReportSettler` rejects report with timestamp older than last accepted report

### TC-18: Chain mismatch is rejected

Expected result:

- `ReportSettler` rejects report whose `chainId` does not match the strategy config

### TC-19: Unauthorized report attestation is rejected

Expected result:

- `submitReportAttested(...)` reverts for signer without `REPORT_ATTESTOR_ROLE`

### TC-20: Unknown peer is rejected

Expected result:

- send/receive against an unconfigured peer reverts

### TC-21: Replay receive is rejected

Expected result:

- duplicate receive of the same bridge message / command is rejected

### TC-22: Debt cap exceeded blocks allocation

Expected result:

- `createOperation(Allocate, ...)` reverts when resulting debt exceeds cap

### TC-23: Emergency-only strategy blocks allocate

Expected result:

- allocation is rejected when strategy is emergency-only / not active for deposits

### TC-24: Withdrawals disabled blocks recall

Expected result:

- `createOperation(Recall, ...)` reverts if withdrawals are disabled

### TC-25: Slippage bound blocks too-low minOut

Expected result:

- operation creation reverts when `minAssetsOut` is below allowed threshold

## 8. Security / Role Cases

### TC-26: Allocator role required for operation creation

Expected result:

- non-allocator cannot create operations

### TC-27: Keeper role required for status transitions

Expected result:

- non-keeper cannot move operation status

### TC-28: Bridge role required for bridge registration / receive

Expected result:

- non-bridge caller cannot call bridge-restricted functions

### TC-29: Governance role required for config setters

Expected result:

- non-governance caller cannot change vault/allocator/registry configuration

### TC-30: Queue actions are authorization-bound

Expected result:

- queue mutation is only available to vault/keeper roles

## 9. Recommended Execution Order

1. Local rehearsal on Anvil
2. Base deploy
3. Arbitrum deploy
4. Peer wiring
5. Role verification
6. Deposit smoke test
7. Allocate E2E
8. Attested report acceptance
9. Recall E2E
10. Withdrawal/buffer tests
11. Incident/security tests
12. Capture artifacts

## 10. Exit Artifacts

Record the following after the run:

- Base addresses:
  - registry
  - allocator
  - settler
  - queue
  - vault
  - bridge
- Arbitrum addresses:
  - asset
  - ERC4626 vault
  - strategy adapter
  - remote agent
  - bridge
- `localPeer()` values and EIDs
- strategy config used on Base
- governance/keeper/allocator/report-attestor addresses
- tx hashes for:
  - deploys
  - peer config
  - first deposit
  - first allocate
  - first attested report
  - first recall
- any deviations, failures, or required config changes before mainnet/audit

