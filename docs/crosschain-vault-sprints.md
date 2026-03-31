# Cross-Chain Vault: План реализации спринтами

## 1. Формат плана

План рассчитан на `8 спринтов` по `2 недели`.

Допущения:

- 2 smart contract engineers;
- 1 protocol reviewer;
- 1 backend engineer на relayer/monitoring;
- 1 QA/SDET частично с 4-го спринта.

## 2. Этапы

- `S1-S2`: architecture freeze и accounting core
- `S3-S4`: operations engine, queue, governance
- `S5-S6`: LayerZero V2 / Stargate V2 integration
- `S7`: strategy adapters и fork tests
- `S8`: hardening, audit prep, RC

## 3. Sprint 1

### Цель

Зафиксировать архитектуру и контракты верхнего уровня.

### Scope

- утвердить home chain;
- утвердить settlement asset;
- утвердить remote chains MVP;
- утвердить strategy MVP;
- зафиксировать `LayerZero V2 + Stargate V2`;
- описать interfaces и storage layouts;
- зафиксировать `Operation`, `CommandPayloadV1`, `StrategyReport`.

### DoD

- architecture ADR подписан;
- нет открытых вопросов по transport stack;
- storage schemas утверждены.

## 4. Sprint 2

### Цель

Собрать accounting core без реального bridge.

### Scope

- `CrossChainVault`;
- `StrategyRegistry`;
- `ReportSettler`;
- `totalAssets()` c transit state;
- deposit/mint/redeem/withdraw baseline.

### DoD

- ERC4626 accounting детерминирован;
- shares только на home chain;
- transit accounting не double-count.

## 5. Sprint 3

### Цель

Добавить operation lifecycle и async withdraw.

### Scope

- `StrategyAllocator`;
- `WithdrawalQueue`;
- operation state machine;
- queued withdraw;
- recall requests на mocks.

### DoD

- queued withdraw работает end-to-end на mock settlement;
- operations идемпотентны;
- нет гонок в share locking.

## 6. Sprint 4

### Цель

Довести governance, pause, emergency и observability baseline.

### Scope

- roles and permissions;
- guardian pause;
- emergency exit hooks;
- event catalog;
- backend event schema;
- incident runbook drafts.

### DoD

- все critical functions имеют утвержденный access profile;
- emergency flows покрыты тестами;
- monitoring schema готова.

## 7. Sprint 5

### Цель

Интегрировать `LayerZero V2` messaging.

### Scope

- `LayerZeroBridgeAdapter`;
- `RemoteStrategyAgent` как `OApp`;
- peer wiring;
- EID-based config;
- message send/receive path;
- ack flow без asset transfer.

### DoD

- команды доходят по test pathways;
- replay protection работает;
- governance-controlled config реализован.

## 8. Sprint 6

### Цель

Интегрировать `Stargate V2` asset transport.

### Scope

- `StargateV2AssetRouter`;
- `taxi` mode only;
- allocate path с asset movement;
- recall path с asset return;
- timeout/recovery hooks.

### DoD

- `allocate -> remote receive -> ack` работает;
- `recall -> home receive -> settle` работает;
- transit accounting сходится после settlement.

## 9. Sprint 7

### Цель

Подключить стратегии MVP.

### Scope

- `AaveAdapter`;
- `PerpAdapter`;
- `GMXAdapter` только если входит в MVP;
- unified `totalValue/freeLiquidity`;
- fork tests;
- strategy risk limits.

### DoD

- минимум 2 стратегии проходят full lifecycle;
- fork tests стабильны;
- emergency unwind описан и проверен.

## 10. Sprint 8

### Цель

Hardening, audit prep и release candidate.

### Scope

- invariants;
- fuzzing;
- gas review;
- storage layout review;
- threat model;
- deployment runbook;
- RC testnet rehearsal.

### DoD

- internal critical findings закрыты;
- testnet dress rehearsal пройден;
- audit handoff package готов.

## 11. Критический путь

1. architecture freeze
2. accounting core
3. operation lifecycle
4. LayerZero V2 messaging
5. Stargate V2 taxi-only asset transport
6. one remote strategy in production quality
7. hardening and audit prep

## 12. Что не включать в MVP

- Stargate V2 `bus` mode;
- permissionless strategies;
- multi-asset vault;
- remote user deposits;
- more than 2-3 strategy types;
- cross-chain share token.
