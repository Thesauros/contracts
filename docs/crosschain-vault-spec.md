# Cross-Chain Vault: ТЗ на реализацию

## 1. Цель

Реализовать `single-home-chain vault` для одного базового актива, в котором:

- единственный Vault и единственный ledger пользовательских shares существуют только в одной сети;
- ликвидность Vault может перемещаться в другие сети;
- позиции и стратегии могут открываться, управляться и закрываться в любой поддерживаемой сети;
- пользовательский accounting, mint/burn shares, NAV и withdraw settlement определяются только на home chain;
- remote-контракты не ведут пользовательский учет и не являются источником истины по shares.

## 2. Контекст и ограничения

- Базовый актив на первом этапе: один stable asset на Vault.
- Vault должен оставаться ERC4626-совместимым на home chain.
- Cross-chain execution допускается быть асинхронным.
- Withdraw не обязан быть мгновенным, если ликвидность находится в remote strategy.
- Remote contracts не должны иметь права самостоятельно менять user balances или share price.
- Любой cross-chain transport должен быть заменяемым модулем, а не вшитой бизнес-логикой Vault.

### 2.1 Transport stack для v1

Для первой реализации transport stack фиксируется явно:

- `LayerZero V2` как messaging layer;
- `Stargate V2` как settlement asset transfer layer.

Это обязательное решение для `v1`.
Абстракция transport-слоя сохраняется только для того, чтобы в будущем можно было заменить transport без миграции `CrossChainVault`.

## 3. Проблемы текущей архитектуры, которые нужно устранить

### 3.1 Проблемы `contracts`

Текущий `Vault` в [`Vault.sol`](contracts/base/Vault.sol) хорошо решает:

- ERC4626 accounting;
- on-chain shares;
- fee/governance;
- single-chain rebalance.

Но не решает:

- асинхронную доставку капитала между сетями;
- учет `assets in transit`;
- удаленный execution и delayed settlement;
- stale NAV для remote strategies.

### 3.2 Проблемы `crosschain_index`

Текущий `ThesaurosRouter` в [`crosschain_index/contracts/ThesaurosRouter.sol`](../../crosschain_index/contracts/ThesaurosRouter.sol):

- использует relayer-supplied TVL для расчета shares;
- использует relayer-supplied price для withdraw;
- смешивает user ledger, bridge orchestration и liquidity routing;
- делает relayer критическим trust-anchor для accounting;
- не является ERC4626 core.

Это запрещено переносить в целевую систему как есть.

## 4. Целевая архитектура

Система делится на два независимых слоя:

1. `Accounting Plane` на home chain.
2. `Execution Plane` на remote chains.

### 4.1 Accounting Plane

Состоит из:

- `CrossChainVault` - ERC4626 Vault и единственный источник истины по shares;
- `StrategyAllocator` - управление долгом Vault перед стратегиями;
- `StrategyRegistry` - реестр стратегий, сетей, лимитов и статусов;
- `WithdrawalQueue` - очередь асинхронных withdraw;
- `ReportSettler` - прием и фиксация отчетов remote strategies;
- `BridgeAdapter` - интерфейс отправки/получения капитала и сообщений.

### 4.2 Execution Plane

Состоит из:

- `RemoteStrategyAgent` - remote execution account для конкретной стратегии;
- `StrategyAdapter` - протокол-специфичный адаптер;
- `RemoteRiskModule` - набор локальных risk checks;
- `RemoteEscrow` при необходимости, если bridge требует отдельного receiver.

### 4.3 Архитектурный принцип

- `CrossChainVault` знает только aggregate state стратегий.
- `RemoteStrategyAgent` знает только локальный execution state.
- Пользователь никогда не взаимодействует с remote-контрактами.
- Remote execution не mint/burn shares.
- Любое изменение user accounting происходит только в `CrossChainVault`.

## 5. Состав контрактов

## 5.1 `CrossChainVault`

Назначение:

- принимать deposit;
- mint/redeem shares;
- считать `totalAssets()`;
- держать idle liquidity на home chain;
- инициировать allocate/recall через allocator;
- исполнять instant withdraw либо ставить request в очередь.

Обязательные свойства:

- наследование от ERC4626;
- pausable actions;
- fee model;
- timelock/governance;
- поддержка `assetsInTransit`;
- поддержка stale-report protection.

`CrossChainVault` не должен:

- напрямую управлять remote-протоколами;
- напрямую читать remote state;
- зависеть от relayer для расчета shares.

## 5.2 `StrategyRegistry`

Назначение:

- регистрировать стратегии;
- хранить соответствие `strategyId -> metadata`;
- хранить лимиты и статусы;
- хранить bridge routing.

### Структура `StrategyConfig`

```solidity
struct StrategyConfig {
    uint32 strategyId;
    uint32 chainId;
    address agent;
    address asset;
    uint96 debtLimit;
    uint96 maxSlippageBps;
    uint48 maxReportDelay;
    bool depositsEnabled;
    bool withdrawalsEnabled;
    bool emergencyExitOnly;
    StrategyKind kind;
}
```

### Структура `StrategyState`

```solidity
struct StrategyState {
    uint256 currentDebt;
    uint256 lastReportedValue;
    uint256 pendingBridgeIn;
    uint256 pendingBridgeOut;
    uint256 freeLiquidity;
    uint256 unrealizedLossBuffer;
    uint64 lastReportTimestamp;
    uint64 lastAckTimestamp;
    StrategyHealth health;
}
```

## 5.3 `StrategyAllocator`

Назначение:

- allocate funds из home vault в remote strategy;
- recall funds обратно;
- вести state machine операций;
- сверять confirmations bridge / agent reports.

### Обязательная логика

- allocator не mint/burn shares;
- allocator не должен менять user balances;
- allocator должен обновлять `pendingBridgeOut`, `pendingBridgeIn`, `currentDebt`;
- allocator обязан работать через `operationId`.

### Структура операции

```solidity
struct Operation {
    bytes32 opId;
    uint32 strategyId;
    OperationType opType;
    uint256 assets;
    uint256 minAssetsOut;
    uint64 createdAt;
    uint64 deadline;
    OperationStatus status;
}
```

`OperationType`:

- `Allocate`
- `Recall`
- `Harvest`
- `EmergencyExit`

`OperationStatus`:

- `Created`
- `Sent`
- `Received`
- `Executed`
- `Settled`
- `Cancelled`
- `Failed`

## 5.4 `WithdrawalQueue`

Назначение:

- хранить withdraw requests, которые нельзя исполнить мгновенно;
- резервировать доступную ликвидность;
- выдавать completed requests после возврата средств на home chain.

### Структура withdraw request

```solidity
struct WithdrawalRequest {
    uint256 requestId;
    address owner;
    address receiver;
    uint256 shares;
    uint256 assetsPreview;
    uint64 createdAt;
    WithdrawalStatus status;
}
```

`WithdrawalStatus`:

- `Pending`
- `Funded`
- `Claimed`
- `Cancelled`

## 5.5 `ReportSettler`

Назначение:

- принимать отчеты от remote strategies;
- валидировать freshness;
- обновлять `StrategyState`;
- участвовать в расчете `totalAssets()`.

### Структура отчета

```solidity
struct StrategyReport {
    uint32 strategyId;
    uint32 chainId;
    uint256 totalValue;
    uint256 freeLiquidity;
    uint256 totalDebt;
    int256 pnl;
    uint64 reportTimestamp;
    bytes32 positionsHash;
}
```

### Требования к отчету

- нельзя принимать отчет старше `maxReportDelay`;
- нельзя принимать отчет с неверным `strategyId/chainId`;
- должен существовать signer/attestation policy;
- отчет должен быть идемпотентным по `(strategyId, reportTimestamp, positionsHash)`.

## 5.6 `BridgeAdapter`

Назначение:

- унифицировать кросс-чейн transport;
- отправлять asset + payload;
- принимать acks;
- изолировать bridge-вендора от core logic.

### Интерфейс

```solidity
interface IBridgeAdapter {
    function sendAssetAndMessage(
        uint32 dstChainId,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) external payable returns (bytes32 opId);
}
```

На первом этапе допускается один bridge provider.
Архитектурно замена bridge не должна ломать `CrossChainVault`.

## 5.7 `RemoteStrategyAgent`

Назначение:

- получать капитал из bridge;
- исполнять команды allocator;
- хранить локальный idle balance;
- дергать `StrategyAdapter`;
- формировать отчеты и acks;
- возвращать ликвидность домой.

### Обязательные методы

- `receiveBridgeAsset(bytes payload)`
- `executeAllocate(bytes command)`
- `executeRecall(bytes command)`
- `harvest(bytes command)`
- `emergencyExit(bytes command)`
- `sweepToHome(uint256 amount, bytes command)`
- `report()`

### Требования

- только authorized messenger / relayer / governance;
- replay protection;
- command nonce;
- emergency pause;
- локальные лимиты по slippage и leverage.

## 5.8 `StrategyAdapter`

Назначение:

- протокол-специфичная логика для Aave / Perp / GMX;
- единый интерфейс для `RemoteStrategyAgent`.

### Базовый интерфейс адаптера

```solidity
interface IStrategyAdapter {
    function deployCapital(uint256 assets, bytes calldata params) external;
    function freeCapital(uint256 assets, bytes calldata params) external returns (uint256);
    function harvest(bytes calldata params) external returns (int256 pnl, uint256 assetsOut);
    function totalValue() external view returns (uint256);
    function freeLiquidity() external view returns (uint256);
    function emergencyExit(bytes calldata params) external returns (uint256 assetsOut);
}
```

Текущие building blocks из `crosschain_index` должны быть переработаны в эту роль.

## 6. Модель учета активов

## 6.1 Источник истины

Единственный источник истины по пользователям:

- `balanceOf(user)`
- `totalSupply()`
- `convertToAssets()`
- `convertToShares()`

находится только в `CrossChainVault`.

## 6.2 Формула `totalAssets()`

`totalAssets()` должно включать:

- idle asset на home chain;
- подтвержденный `lastReportedValue` всех стратегий;
- `pendingBridgeIn`, если asset уже покинул remote strategy и подтвержден в пути;
- `pendingBridgeOut`, если asset уже списан из idle, но еще не зачислен remote strategy;
- минус зафиксированные fees и realized losses.

Формально:

```text
totalAssets =
    homeIdle
    + sum(strategy.lastReportedValue)
    + sum(strategy.pendingBridgeOut)
    + sum(strategy.pendingBridgeIn)
    - realizedLosses
    - accruedFees
```

Примечание:

- `pendingBridgeOut` и `pendingBridgeIn` должны участвовать в учете ровно один раз;
- double counting запрещен;
- переход состояния операции обязан сохранять инвариант сохранения капитала.

## 6.3 Debt model

Для каждой стратегии:

- `currentDebt` = сколько капитала Vault аллоцировал стратегии;
- `lastReportedValue` = сколько стратегия реально стоит по последнему accepted report;
- `PnL = lastReportedValue - currentDebt`, если смотреть в разрезе стратегии.

Именно debt model должен заменить текущую relayer-driven share model из `ThesaurosRouter`.

## 7. Пользовательские сценарии

## 7.1 Deposit

1. Пользователь вызывает `deposit(assets, receiver)` в `CrossChainVault`.
2. Vault рассчитывает shares по последнему подтвержденному `totalAssets`.
3. Пользователь получает shares сразу.
4. Средства остаются в `homeIdle`.
5. Allocator позже отправляет часть idle в remote strategies.

Требование:

- deposit не должен ждать bridge;
- deposit не должен зависеть от remote tx finality.

## 7.2 Instant withdraw

1. Пользователь вызывает `withdraw` или `redeem`.
2. Если `homeIdle >= requiredAssets`, Vault исполняет withdraw сразу.
3. Shares burn происходят на home chain.

## 7.3 Queued withdraw

1. Если `homeIdle < requiredAssets`, request уходит в `WithdrawalQueue`.
2. Vault блокирует соответствующие shares.
3. Allocator инициирует recall из одной или нескольких стратегий.
4. После прихода средств на home chain request получает статус `Funded`.
5. Пользователь или keeper завершает claim.

## 7.4 Allocate в remote strategy

1. Governance/allocator выбирает стратегию.
2. Проверяются caps, slippage, health, report freshness.
3. Idle asset резервируется.
4. Создается `Operation`.
5. Bridge отправляет asset + command.
6. Agent подтверждает receipt.
7. Agent deploys capital в protocol adapter.
8. После ack/deploy operation переводится в `Settled`.

## 7.5 Recall из remote strategy

1. Allocator инициирует recall.
2. Agent закрывает/уменьшает позицию или извлекает idle liquidity.
3. Agent bridge-ит asset обратно домой.
4. Home chain получает funds и помечает operation как `Settled`.
5. Средства становятся `homeIdle`.

## 7.6 Emergency exit

1. Governance/guardian ставит стратегию в `emergencyExitOnly`.
2. Новые allocate запрещены.
3. Agent закрывает допустимые позиции.
4. Все доступные средства отправляются домой.
5. Strategy переводится в `Paused` или `Deprecated`.

## 8. Требования к ролям

Нужны роли:

- `DEFAULT_ADMIN_ROLE`
- `GOVERNANCE_ROLE`
- `GUARDIAN_ROLE`
- `ALLOCATOR_ROLE`
- `REPORTER_ROLE`
- `KEEPER_ROLE`
- `BRIDGE_ROLE` или trusted messenger role

### Права ролей

`GOVERNANCE_ROLE`:

- добавление/удаление стратегий;
- изменение caps;
- смена bridge adapter;
- upgrade;
- изменение report policy.

`GUARDIAN_ROLE`:

- pause deposits;
- pause withdraws;
- pause strategy;
- emergency exit.

`ALLOCATOR_ROLE`:

- allocate;
- recall;
- rebalance capital between strategies.

`REPORTER_ROLE`:

- submit report;
- submit NAV update;
- submit execution ack.

`KEEPER_ROLE`:

- process queue;
- finalize funded withdrawals;
- trigger harvest/report sync.

## 9. Инварианты

Ниже обязательные инварианты для реализации и тестов.

### 9.1 Accounting invariants

- shares существуют только на home chain;
- remote contracts не mint/burn shares;
- `totalAssets()` не должен double-count bridge state;
- accepted report не может увеличить активы без валидного источника данных;
- withdraw не может выплатить больше, чем доступно по user shares.

### 9.2 Operation invariants

- любой `opId` исполняется не более одного раза;
- один bridge ack не может сеттлить более одной операции;
- `pendingBridgeOut` и `pendingBridgeIn` сходятся к нулю после settlement;
- операция не может перейти из final state в non-final state.

### 9.3 Security invariants

- stale report не влияет на NAV;
- unauthorized caller не может запустить allocate/recall/report;
- replay command не должен менять state;
- emergency pause должен блокировать новые risky actions.

## 10. Требования к отчетности и NAV

## 10.1 Report freshness

Для каждой стратегии задается:

- `maxReportDelay`;
- `maxNavDeviationBps`;
- `maxLossPerReportBps`.

Если отчет stale:

- новые deposits могут быть ограничены глобально или по strategy exposure;
- новые allocate в stale strategy запрещаются;
- large withdraw может идти только через queue;
- governance/guardian получают alert.

## 10.2 NAV acceptance policy

Отчет принимается только если:

- signer авторизован;
- `reportTimestamp` монотонно возрастает;
- отклонение не превышает допустимый порог либо требует отдельного governance override;
- strategy не находится в hard-paused состоянии.

## 11. Требования к bridge layer

- Bridge не должен быть hard-coded в `CrossChainVault`.
- Логика bridge должна быть вынесена в adapter.
- Каждая cross-chain команда должна содержать:

```solidity
struct BridgeCommand {
    bytes32 opId;
    uint32 strategyId;
    uint32 srcChainId;
    uint32 dstChainId;
    CommandType commandType;
    uint256 assets;
    bytes params;
}
```

- Должен быть replay protection по `(srcChainId, opId)`.
- Должен быть failure path для неуспешной доставки.
- Должен быть manual recovery path под governance.

## 11.1 LayerZero как базовый transport v1

Для данной кодовой базы базовым transport слоем первой версии нужно считать `LayerZero + Stargate`.

Это связано с тем, что текущая cross-chain реализация уже использует:

- `nativeChainId` / `receiverLzId`;
- `sgBridge`;
- Stargate-style asset bridging;
- router-to-router / router-to-BB flows.

Следовательно, в версии `v1` нужно явно закладывать:

- `LayerZero` как messaging/control plane;
- `Stargate` как asset transfer plane для settlement asset;
- bridge abstraction поверх них, чтобы later можно было заменить transport без переписывания `CrossChainVault`.

Для новой реализации это уточняется до актуальных версий:

- `LayerZero V2`, а не legacy V1-style flow;
- `Stargate V2`, а не legacy Stargate integration pattern.

### 11.1.1 Что это означает технически

Нужно использовать:

- `LayerZero Endpoint V2`;
- `OApp`-паттерн для messaging между home chain и remote chains;
- `EID (uint32)` как канонический идентификатор destination/source chain;
- explicit peer wiring и config management для pathways;
- `Stargate V2` same-asset transfer path для settlement asset.

Текущие legacy `uint16` LayerZero-style ids из старой реализации не должны использоваться в новой архитектуре как канонический chain identifier.

## 11.2 Разделение ролей LayerZero и Stargate

В ТЗ нужно явно развести две задачи:

1. `Message transport`
2. `Asset transport`

### Message transport

Используется для доставки:

- `allocate` command;
- `recall` command;
- `harvest` command;
- `emergencyExit` command;
- `ack` и `report metadata`.

### Asset transport

Используется для доставки:

- settlement asset из home chain в remote strategy;
- settlement asset из remote strategy обратно в home vault.

Требование:

- управление позицией и перемещение капитала должны быть логически связаны одним `operationId`;
- но на уровне архитектуры это два разных потока: message и funds.

### 11.2.1 LayerZero V2 profile для проекта

Для MVP принимается следующий профиль:

- `RemoteStrategyAgent` реализуется как `OApp receiver/sender`;
- trusted peers выставляются явно через owner/governance-controlled config;
- unordered delivery используется по умолчанию;
- ordered delivery включается только там, где оно необходимо для корректности operation lifecycle;
- каждый command и ack должен быть идемпотентен по `opId`.

Ordered delivery допускается только для:

- pathway, где одна стратегия получает конкурентные stateful команды;
- flows `emergencyExit` и `forcedRecall`, если они должны линейно вытеснять обычные команды.

## 11.3 Рекомендуемый паттерн для v1

Для первой версии рекомендуется следующий flow:

### Allocate

1. Home chain создает `operationId`.
2. `BridgeAdapterLZ` отправляет settlement asset через `Stargate`.
3. Вместе с asset transfer отправляется `LayerZero payload` или compose-message с:
   - `operationId`
   - `strategyId`
   - `amount`
   - `commandType`
   - `adapterParams`
4. Remote `RemoteStrategyAgent` принимает asset и command.
5. Agent исполняет локальный strategy action.
6. Agent отправляет `ack/report` обратно через LayerZero messaging.

### Recall

1. Home chain отправляет recall command через LayerZero.
2. Remote agent сворачивает часть позиции и получает settlement asset локально.
3. Remote agent отправляет settlement asset обратно через Stargate.
4. Home chain получает asset и settlement confirmation.
5. `StrategyAllocator` закрывает операцию и обновляет debt state.

### 11.3.1 Payload format для LayerZero V2

Все команды и acknowledgements в MVP должны использовать versioned payload:

```solidity
enum CommandType {
    Allocate,
    Recall,
    Harvest,
    EmergencyExit,
    Ack,
    Report
}

struct CommandPayloadV1 {
    uint8 version;
    bytes32 opId;
    uint32 strategyId;
    CommandType commandType;
    uint256 assets;
    uint64 commandTimestamp;
    bytes params;
}
```

Требования:

- `version` обязателен;
- `opId` обязателен;
- `strategyId` обязателен;
- `params` содержит adapter-specific execution data;
- payload decoding ошибки не должны приводить к silent settlement.

### 11.3.2 Executor options policy

Для `LayerZero V2` сообщений должны использоваться enforced options.

В MVP нужно явно задавать:

- gas budget на `lzReceive`;
- compose gas, если используется compose pattern;
- refund address policy;
- native value policy на destination только при явной необходимости.

Пользовательские произвольные executor options в Vault logic запрещены.

## 11.4 Почему LayerZero не должен быть зашит прямо в Vault

Даже если в `v1` мы используем именно LayerZero, его нельзя зашивать в `CrossChainVault` по трем причинам:

- Vault должен оставаться accounting core, а не bridge-specific контрактом;
- замена transport слоя не должна требовать миграции пользовательских shares;
- message/bridge ошибки не должны разрушать логику ERC4626.

Поэтому правильная структура:

- `CrossChainVault`
- `StrategyAllocator`
- `IBridgeAdapter`
- `LayerZeroBridgeAdapter`

а не:

- `CrossChainVault` с прямыми вызовами LayerZero endpoint / Stargate router.

## 11.5 Что нужно реализовать в `LayerZeroBridgeAdapter`

`LayerZeroBridgeAdapter` должен:

- маппить internal `chainId` в `lzEid`/endpoint-specific chain identifier;
- отправлять settlement asset через Stargate;
- отправлять command payload через LayerZero;
- принимать inbound message только от trusted peer;
- валидировать source chain и source contract;
- обеспечивать replay protection;
- эмитить events для `messageSent`, `messageReceived`, `assetBridged`, `assetReceived`;
- поддерживать `retry / recover / force resume` operational flows, если transport их требует.

Дополнительно `LayerZeroBridgeAdapter` должен:

- работать с `uint32 eid`;
- хранить `strategyId -> remote peer -> eid`;
- отделять `message send`, `asset send`, `message receive`, `asset settlement`;
- уметь делать transport fee quote;
- не позволять менять pathway security config вне governance flow.

### 11.5.1 `StargateV2AssetRouter`

Логику asset movement лучше вынести в отдельный модуль даже при общем bridge adapter.

`StargateV2AssetRouter` должен:

- готовить `SendParam`/эквивалент V2 transfer params;
- поддерживать fee quoting;
- валидировать same-asset route;
- использовать только approved settlement assets;
- возвращать receipt, связанный с `opId`.

### 11.5.2 Taxi-only policy для MVP

В MVP разрешается только `taxi` mode.

`Bus` mode запрещен в первой версии, потому что batching и delayed execution усложняют:

- withdraw settlement;
- transit accounting;
- timeout policy;
- incident recovery.

## 11.6 Settlement asset policy для LayerZero/Stargate

В первой версии через LayerZero/Stargate должен перемещаться только `settlement asset`.

Не допускается:

- bridge LP tokens;
- bridge leveraged position state;
- bridge protocol-specific receipt tokens как основной capital path;
- bridge user shares.

Допускается:

- bridge `USDC` или другой утвержденный stable settlement asset;
- локальное разворачивание позиции уже после получения asset в remote chain;
- локальное сворачивание позиции в settlement asset перед отправкой обратно домой.

## 11.7 Риски LayerZero/Stargate, которые надо учесть в реализации

- message delivered, asset delayed;
- asset delivered, message failed;
- duplicate delivery / replay;
- peer misconfiguration;
- wrong destination mapping;
- partial fill / slippage на bridge;
- stuck funds / manual recovery case.

Для каждого такого случая должны быть:

- operation state;
- timeout policy;
- cancellation/recovery policy;
- governance recovery path;
- явные события для off-chain monitoring.

### 11.8 Migration constraints относительно текущего `crosschain_index`

Текущая реализация использует legacy assumptions:

- `uint16` ids;
- custom `sgBridge` abstraction;
- router-centric architecture;
- relayer-driven accounting.

Для перехода на `LayerZero V2 / Stargate V2` нужно считать incompatible и подлежащими замене:

- `ThesaurosRouter`;
- transport section в `BaseAppStorage`;
- текущий `transferDeposits / approveWithdraw` accounting flow;
- legacy payload formats, построенные вокруг router-centric model.

Допускается переиспользовать только:

- protocol-specific execution code как reference;
- deployment knowledge;
- chain configuration tables после перевода на `EID`.

## 12. Требования к remote adapters

### 12.1 Aave

Поддержать:

- supply;
- withdraw;
- borrow/repay только если стратегия явно leverage-enabled;
- reward claim;
- health factor checks;
- eMode config.

### 12.2 Perpetual

Поддержать:

- deposit collateral;
- open/adjust/close position;
- free collateral query;
- total value query;
- emergency reduce-only mode;
- liquidation threshold monitoring.

### 12.3 GMX

Поддержать:

- buy GLP / redeem GLP;
- reward compounding;
- TVL query;
- emergency unwind.

## 13. Upgradeability

### 13.1 Upgradeable контракты

Upgradeable должны быть:

- `StrategyAllocator`
- `StrategyRegistry`
- `ReportSettler`
- `RemoteStrategyAgent`
- `StrategyAdapter` implementations

`CrossChainVault` допустимо:

- либо immutable core + mutable modules;
- либо upgradeable proxy, если governance и storage discipline готовы.

Рекомендация:

- `CrossChainVault` делать upgradeable только если storage layout и governance process полностью стандартизированы.

### 13.2 Storage gap

Для всех upgradeable контрактов:

- storage gap;
- versioned initializer;
- layout review до каждого upgrade.

## 14. События

Минимальный набор событий:

```solidity
event StrategyAdded(uint32 indexed strategyId, uint32 indexed chainId, address agent);
event StrategyStatusChanged(uint32 indexed strategyId, StrategyHealth status);
event AllocationRequested(bytes32 indexed opId, uint32 indexed strategyId, uint256 assets);
event AllocationSettled(bytes32 indexed opId, uint32 indexed strategyId, uint256 assets);
event RecallRequested(bytes32 indexed opId, uint32 indexed strategyId, uint256 assets);
event RecallSettled(bytes32 indexed opId, uint32 indexed strategyId, uint256 assetsIn);
event StrategyReported(uint32 indexed strategyId, uint256 totalValue, uint256 freeLiquidity, uint64 reportTimestamp);
event WithdrawalQueued(uint256 indexed requestId, address indexed owner, uint256 shares, uint256 assetsPreview);
event WithdrawalFunded(uint256 indexed requestId, uint256 assets);
event WithdrawalClaimed(uint256 indexed requestId, address indexed receiver, uint256 assets);
event EmergencyExitTriggered(uint32 indexed strategyId, bytes32 indexed opId);
```

## 15. Права доступа и trust assumptions

Система должна быть спроектирована так, чтобы:

- bridge/operator не контролировал shares;
- reporter не мог произвольно рисовать NAV;
- remote agent не мог выпускать обязательства Vault;
- governance могло остановить систему и вернуть капитал.

На первом этапе допускается:

- trusted off-chain reporter/keeper set;
- multisig governance;
- whitelisted strategies.

На первом этапе не допускается:

- permissionless listing стратегий;
- permissionless report acceptance;
- user-level direct remote interaction.

## 16. Тестовый план

## 16.1 Unit tests

Покрыть:

- deposit/redeem/withdraw при idle liquidity;
- queue creation;
- allocation lifecycle;
- recall lifecycle;
- report acceptance/rejection;
- stale report handling;
- replay protection;
- emergency exit;
- strategy caps;
- bridge pending state accounting.

## 16.2 Integration tests

Покрыть:

- allocate в remote agent и обратный recall;
- partial liquidity recall;
- multiple strategies with mixed idle state;
- stale one strategy while others active;
- queued withdraw при illiquid home vault;
- report after loss scenario;
- emergency exit under open perp position.

## 16.3 Invariant tests

Проверить:

- сумма активов не исчезает без explicit loss;
- shares не меняются вне deposit/mint/withdraw/redeem;
- final state operations не переисполняются;
- `totalAssets` не double-count transit balances.

## 16.4 Fork tests

Нужны fork tests для:

- Aave;
- Perpetual/Hyperliquid-like integration если есть EVM target;
- GMX.

## 17. Этапы реализации

### Phase 1. Accounting core

Сделать:

- `CrossChainVault`;
- `StrategyRegistry`;
- `StrategyAllocator`;
- `WithdrawalQueue`;
- базовый `ReportSettler`;
- unit tests без реального bridge.

Критерий готовности:

- single-chain local mocks;
- debt accounting работает;
- queue работает;
- instant/queued withdraw покрыты тестами.

### Phase 2. Bridge and remote agent

Сделать:

- `BridgeAdapter`;
- `RemoteStrategyAgent`;
- command/ack state machine;
- mock cross-chain integration tests.

Критерий готовности:

- allocate/recall закрывает полный цикл;
- transit accounting не ломает `totalAssets`.

### Phase 3. Strategy adapters

Сделать:

- `AaveAdapter`;
- `PerpAdapter`;
- `GmxAdapter`;
- risk checks per adapter.

Критерий готовности:

- стратегии могут быть вызваны через единый agent interface;
- каждая стратегия возвращает `totalValue/freeLiquidity`.

### Phase 4. Security hardening

Сделать:

- access review;
- emergency flows;
- stale NAV policy;
- invariant tests;
- audit readiness checklist.

## 18. Non-goals для первой версии

В первую версию не входят:

- multi-asset vault;
- permissionless strategies;
- cross-chain share token;
- user deposits напрямую в remote chain с instant mint на home chain;
- optimistic proof system для NAV;
- fully trustless bridge verification.

## 19. Артефакты реализации

Команда разработки должна по итогу подготовить:

- набор контрактов accounting plane;
- набор контрактов execution plane;
- интерфейсы bridge/reporting;
- deployment scripts;
- threat model;
- unit/integration/invariant test suite;
- runbook на emergency exit и stale report incident.

## 20. Критерий приемки

Реализация считается соответствующей ТЗ, если:

- один Vault на home chain является единственным источником истины по shares;
- remote стратегии не ведут пользовательский accounting;
- `totalAssets()` корректно учитывает idle, debt reports и transit;
- queued withdraw корректно исполняется при дефиците home liquidity;
- allocate/recall проходят через идемпотентную operation state machine;
- stale/invalid report не может исказить NAV;
- emergency exit позволяет свернуть удаленную экспозицию и вернуть капитал домой.
