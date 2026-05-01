# Remote Execution MVP

Date: **2026-04-03**

## Objective

Define the minimum modular execution layer for remote strategy operation without moving user-facing semantics away from the home-side vault.

## Delivered Components

- [`RemoteStrategyAgent`](../contracts/crosschain/RemoteStrategyAgent.sol) as the remote execution shell;
- [`MorphoStrategyAdapter`](../contracts/crosschain/MorphoStrategyAdapter.sol) as the first protocol-specific execution path;
- [`ERC4626StrategyAdapter`](../contracts/crosschain/ERC4626StrategyAdapter.sol) as the second generic execution path.

## Resulting Execution Model

The current remote execution path is:

`CrossChainVault(home) -> BridgeAdapter -> RemoteStrategyAgent(remote) -> StrategyAdapter(remote strategy)`

This keeps:

- user shares and redemption semantics on the home chain;
- bridge and command handling inside the remote agent;
- protocol-specific logic inside replaceable strategy adapters.

## Current Adapter Set

### 1. Morpho-specific path

- optimized for MetaMorpho-style ERC4626 vaults;
- tracks deployed principal separately from current strategy value;
- supports deploy, free capital, harvest, and emergency exit.

### 2. Generic ERC4626 path

- validates the same lifecycle against any ERC4626-compatible yield vault;
- gives the execution layer one reusable adapter interface beyond Morpho-specific wiring;
- confirms that the agent model is not coupled to one protocol family.

## Validation

Mock validation is covered in:

- [`test/mocking/RemoteStrategyAgent.t.sol`](../test/mocking/RemoteStrategyAgent.t.sol)
- [`test/mocking/MorphoStrategyAdapter.t.sol`](../test/mocking/MorphoStrategyAdapter.t.sol)
- [`test/mocking/ERC4626StrategyAdapter.t.sol`](../test/mocking/ERC4626StrategyAdapter.t.sol)
- [`test/mocking/CrossChainMorphoPipeline.t.sol`](../test/mocking/CrossChainMorphoPipeline.t.sol)
- [`test/mocking/CrossChainERC4626Pipeline.t.sol`](../test/mocking/CrossChainERC4626Pipeline.t.sol)

Fork validation entrypoints are prepared in:

- [`test/forking/MorphoStrategyAdapter.t.sol`](../test/forking/MorphoStrategyAdapter.t.sol)
- [`test/forking/ERC4626StrategyAdapter.t.sol`](../test/forking/ERC4626StrategyAdapter.t.sol)

These fork tests require `ARBITRUM_RPC_URL`.
