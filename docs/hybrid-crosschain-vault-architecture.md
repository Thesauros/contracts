# Hybrid Cross-Chain Vault Architecture

Current as of **2026-03-18**.

## Status

This document describes the **target product architecture**, not the currently deployed system. It captures the working architectural concept approved for future implementation.

Core idea:

- the user enters the yield product from their local chain;
- capital may be moved to another chain if net yield is better there;
- from the user's perspective this remains one product, not a set of isolated vaults by chain;
- routing, valuation, and redemption are handled through a hybrid model: on-chain execution plus off-chain orchestration and accounting;
- withdrawals may use a short execution window instead of strict instant liquidity.

## Short Definition

The proposed architecture is:

**a unified user-facing yield product with chain-specific entry, an internal cross-chain booster/buffer vault layer, backend-coordinated capital movements, and delayed redemption instead of strict instant withdrawal.**

## Block Scheme

```text
User / Wallet / Fintech
          |
          v
+---------------------------+
| Entry Vault (per chain)   |
| Arbitrum / Base / Eth     |
| user-facing deposit UX    |
+---------------------------+
          |
          v
+---------------------------+
| Local Liquidity Buffer    |
| fast-path withdrawals     |
| short-term idle capital   |
+---------------------------+
          |
          v
+---------------------------+        +---------------------------+
| Booster / Routing Layer   |<------>| Cross-chain Bridge       |
| decides where capital     |        | Stargate / bridge adapter|
| should live next          |        +---------------------------+
+---------------------------+
          |
          v
+---------------------------+
| Strategy Vaults by Chain  |
| Morpho / Aave / Compound  |
| execution on destination  |
+---------------------------+
          |
          v
+---------------------------+
| Yield / NAV / PnL Feeds   |
| realized + estimated NAV  |
+---------------------------+
          |
          v
+---------------------------+
| Accounting & Ledger       |
| user positions, chain     |
| history, share pricing    |
+---------------------------+
          |
          v
+---------------------------+
| Redemption Orchestrator   |
| local buffer or pullback  |
| target SLA ~15 min        |
+---------------------------+
          |
          v
       User receives funds
```

## Logical View

At a logical level the product should behave as follows:

- the user enters through one chain;
- the entry vault acts as the interface layer and the point where user ownership is represented;
- the system decides internally where capital should work most efficiently;
- capital can be kept local or moved to a different chain-specific execution vault;
- for the user this remains a single yield product rather than a set of separate vaults by network.

This means the product must not remain `network-bound`. Its core value is not simply a collection of execution vaults, but rather:

- chain abstraction;
- allocation logic;
- liquidity routing;
- valuation and redemption coordination.

## Architectural Layers

### 1. Interface Layer

The user interacts with an `Entry Vault` on their chain, for example on Arbitrum.

For the user this looks like a normal vault:

- deposit;
- request withdrawal;
- view balance / accrued yield.

The user should **not need to know** which chain currently holds the capital.

### 2. Accounting Layer

The system must account for:

- where capital was located historically;
- when it moved between chains;
- what yield was earned in each period;
- how user NAV and share price are calculated at any moment.

This is the most important layer because valuation across chains is the hardest part of the product.

### 3. Routing / Booster Layer

An internal `Booster Vault` or `Routing Vault` accepts capital from chain-specific entry vaults and:

- temporarily holds liquidity;
- initiates movement to another chain;
- acts as an intermediate buffer during allocation and rebalancing.

This is not a user-facing component. Its job is cross-chain capital routing.

### 4. Strategy Execution Layer

On the destination chain, capital is deployed into strategy vaults / adapters such as:

- Morpho;
- Aave;
- Compound;
- other execution venues over time.

This layer generates yield, but it must not become the source of truth for the full cross-chain user position.

### 5. Cross-Chain Transfer and Settlement Layer

This is the layer that actually moves assets across chains.

It may be implemented using:

- bridge adapters;
- stablecoin transfer infrastructure;
- routing services;
- hybrid settlement flows.

Key principle:

- the system should not pretend to be fully decentralized where the technology does not support it;
- capital transfer and settlement may rely on backend-driven orchestration;
- the transfer lifecycle must be explicitly represented as system state.

### 6. Redemption / Liquidity Buffer Layer

To preserve a usable UX, the system must:

- use local liquidity buffers for fast withdrawals;
- pull liquidity back from another chain when the local buffer is insufficient;
- complete redemption within a short, predictable window, with a target of about 15 minutes.

This is **not a lockup**, but it is also not strict instant withdrawal.

## ADR

### Title

`ADR-001: Hybrid Cross-Chain Yield Vault`

### Status

`Proposed`

### Date

`2026-03-18`

### Context

- users should not manually choose the best chain;
- yield can be higher on a chain different from the entry chain;
- there is no reliable fully on-chain synchronous way to value positions across chains in real time;
- isolated vaults per chain are simpler, but weaker as a product abstraction;
- strict instant withdrawal is not required if a short redemption window is preserved.

### Decision

The target architectural direction is:

- use `chain-specific entry vaults` as the user-facing access point;
- use `backend orchestration` for allocation, valuation, accounting, and redemption coordination;
- use a dedicated `booster / buffer layer` for cross-chain capital movement;
- treat the product as a single vault experience with internal chain abstraction;
- replace strict instant liquidity with `delayed redemption` and a target SLA of about 15 minutes.

### Consequences

Advantages:

- users no longer need to choose the chain themselves;
- the product can capture the best yield across chains;
- the narrative is stronger for fintechs, wallets, and banks;
- the architecture scales better to additional chains and strategies.

Trade-offs:

- accounting and valuation become much more complex;
- the system depends on backend correctness and availability;
- instant liquidity is no longer guaranteed in the old sense;
- rebalance rules, liquidity buffers, and reconciliation all need explicit design.

## Product Requirements

### Core Requirements

- One user-facing product even if capital is physically allocated across multiple chains.
- Chain-specific entry points for simple UX.
- Yield optimization across chains.
- Unified user accounting despite capital migration.
- Delayed redemption instead of strict instant withdrawal.

### User Experience Requirements

- The user sees one product balance from their entry vault.
- The user does not choose the destination chain manually.
- The UI must explain that liquidity is usually fast, but may take up to the target SLA.
- Displayed balances must remain understandable even when capital is on a remote chain.

### Operational Requirements

- The system must account for bridge fees, gas spikes, and strategy-specific constraints.
- The system must be able to pause routing into specific chains.
- Chain caps, strategy caps, and emergency routing rules must exist.
- A reconciliation process between on-chain balances and the off-chain ledger must exist.

## Why This Architecture Exists

Without this architecture, the product is just a set of separate chain-specific vaults. That limits both UX and the market story.

With this architecture, the product gains stronger properties:

- the client does not need to think about chains;
- yield is searched globally, not only locally;
- wallets, fintechs, and banks get an abstraction layer;
- new chains and strategies can be added modularly;
- the execution layer becomes a replaceable part of the system instead of the system core.

Architecturally, the important point is:

- **the core product is chain abstraction and allocation logic**;
- the strategy adapters are replaceable execution modules.

## Modules

### On-Chain Modules

#### EntryVault

Responsible for:

- accepting user deposits;
- minting shares or representing user claims;
- accepting withdrawal requests;
- connecting to the local liquidity buffer.

#### LiquidityBuffer

Responsible for:

- local liquidity for fast withdrawals;
- short-term idle capital;
- the first funding source for redemption.

#### BoosterVault / RoutingVault

Responsible for:

- temporary capital staging before moves;
- sending funds to another chain;
- bringing liquidity back when needed.

#### BridgeAdapter

Responsible for:

- abstracting the bridge provider;
- sending bridge transactions;
- bridge status hooks / events;
- eventual replacement of the bridge provider without changing the product core.

#### StrategyVaultAdapters

Responsible for:

- deploying capital into Morpho / Aave / Compound;
- gathering protocol-specific balances;
- local execution and unwind.

### Off-Chain Services

#### Ledger Service

Source of truth for:

- user positions;
- chain residency history;
- share accounting interpretation;
- in-flight bridge states;
- redemption obligations.

#### Valuation Service

Responsible for:

- NAV;
- accrued yield;
- valuation of capital in remote chains;
- bridge-in-flight accounting;
- fees and deductions.

#### Allocation Engine

Responsible for:

- choosing the chain and strategy with the best risk-adjusted net yield;
- accounting for gas, bridge cost, slippage, caps, and policy rules;
- deciding when rebalancing is worthwhile.

#### Rebalancing Engine

Responsible for:

- executing capital movements across chains;
- orchestrating booster -> bridge -> destination strategy flow;
- retries / fallback rules.

#### Redemption Orchestrator

Responsible for:

- choosing the funding source for a withdrawal;
- deciding `local buffer vs pullback`;
- meeting the target SLA;
- controlling stuck redemptions.

#### Risk Engine

Responsible for:

- chain limits;
- strategy limits;
- bridge health;
- emergency pause rules;
- restricted routing policies.

#### Monitoring and Reconciliation

Responsible for:

- reconciling on-chain and off-chain state;
- alerts;
- stuck bridge backlog;
- SLA breaches;
- incident support.

## Boundaries of Responsibility

### Entry Vault

Must not:

- choose the global destination chain on its own;
- calculate global cross-chain NAV on its own;
- make strategic rebalance decisions.

### Booster / Routing Layer

Must not:

- become the user-facing interface;
- become the user accounting system;
- become the only source of truth for shares.

### Strategy Execution Layer

Must not:

- store the global user ledger;
- know the user's full cross-chain history;
- define redemption semantics for the whole product.

### Off-Chain Ledger / Valuation

Must not:

- directly custody funds;
- replace on-chain ownership controls;
- replace the execution layer.

### Redemption Orchestrator

Is specifically responsible for:

- fulfilling withdrawal promises;
- choosing the liquidity source;
- enforcing the target execution window.

## Core Flows

### Deposit Flow

1. The user deposits into the `EntryVault` on their chain.
2. The entry layer records the entry chain and amount.
3. The user receives shares or an equivalent product claim.
4. Part of the capital may remain in `LiquidityBuffer`.
5. The rest moves into `BoosterVault / RoutingVault`.
6. The `Allocation Engine` decides where the best net yield exists.
7. The `Rebalancing Engine` initiates bridge transfer to the destination chain.
8. On the destination chain the capital is deployed via a `StrategyVaultAdapter`.
9. The `Ledger Service` records chain residency, fees, transfer lifecycle, and accounting basis.

### Yield Accrual Flow

1. The execution vault on the destination chain generates yield.
2. `ReportSettler` / the reporting layer updates accepted strategy state.
3. `Ledger Service` and `Valuation Service` update user-visible value.
4. If a better opportunity appears on another chain later, a new rebalance may be initiated.

### Rebalance Flow

1. `Valuation Service` and `Allocation Engine` compare net yield across chains.
2. They account for bridge fees, gas, capacity, strategy risk, liquidity availability, and current exposure.
3. A move is initiated only if net benefit after frictions is positive.
4. If needed, the move proceeds as:
   - source strategy unwind;
   - capital into booster;
   - bridge transfer;
   - destination deployment.
5. `Ledger Service` updates state and in-flight markers.

### Redemption Flow

1. The user creates a withdrawal request in `EntryVault`.
2. `Redemption Orchestrator` checks the local `LiquidityBuffer`.
3. If enough liquidity exists, payout happens locally.
4. If not, the system launches a pullback from the remote chain through booster and bridge flow.
5. If bridge conditions or gas environment are poor, execution may be delayed within the allowed window.
6. Payment completes within the target SLA if there is no incident.

## Main Constraints and Risks

### Valuation Risk

There is no reliable fully on-chain way to synchronously value the full user position across chains at any moment.

### Rebalancing Complexity

Cross-chain rebalancing is substantially more complex than isolated vaults per chain.

### Gas and Bridge Cost Volatility

Routing decisions must use net yield after all frictions, not nominal APY.

### Redemption Semantics

The product no longer promises strict instant liquidity at every moment.

### Backend Dependency

The architecture explicitly depends on backend orchestration, ledger correctness, and monitoring.

## Relationship to Current `contracts`

The current repository already includes a dedicated `crosschain` surface:

- `CrossChainVault`;
- `StrategyRegistry`;
- `StrategyAllocator`;
- `ReportSettler`;
- `WithdrawalQueue`;
- `CrossChainTypes`;
- cross-chain role-based access control.

This codebase is closer to the target architecture than the old router-based prototypes, but it is still not a full implementation.

Main unfinished areas:

- full bridge transport;
- remote execution agents;
- booster / buffer vault decomposition;
- orchestration policies;
- production-grade valuation and reconciliation.

## Open Questions

- Should the share model be one global share class or chain-local receipts with global accounting?
- How should NAV for in-flight bridge capital be recognized?
- How much local buffer should be held per chain?
- What rebalance threshold is sufficient after accounting for bridge and gas costs?
- Is manual approval required for large rebalances in early versions?
- What redemption SLA is acceptable in normal mode and degraded mode?
- How should emergency mode behave when a given bridge or chain is unavailable?

## Suggested Next Documents

The natural follow-up documents are:

- `ADR-002 Ledger and NAV Model`
- `ADR-003 Redemption SLA and Liquidity Buffers`
- `ADR-004 Rebalancing Policy and Risk Limits`
- `PRD Entry Vault UX and Redemption Experience`
- backend orchestration system design
