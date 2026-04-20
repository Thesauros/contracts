# Contract Interaction Diagram

## System Overview

This diagram shows the relationships and interactions between all contracts in the Thesauros system.

## Contract Interaction Graph

```mermaid
graph TB
    %% User Layer
    User[  User]
    DAO[   DAO/Governance]
    
    %% Core Contracts
    VaultManager[  VaultManager]
    Timelock[⏰ Timelock]
    AccessManager[  AccessManager]
    
    %% Vault Contracts
    Vault[  Vault]
    Rebalancer[   Rebalancer]
    
    %% Provider Management
    ProviderManager[  ProviderManager]
    
    %% Provider Contracts
    AaveV3Provider[  AaveV3Provider]
    CompoundV3Provider[   CompoundV3Provider]
    
    %% External Protocols
    AaveV3[  Aave V3 Protocol]
    CompoundV3[   Compound V3 Protocol]
    
    %% Treasury and Tokens
    Treasury[   Treasury]
    ERC20Token[🪙 ERC20 Token]
    
    %% User Interactions
    User -->|deposit/withdraw| Vault
    User -->|rebalance| Rebalancer
    
    %% Governance Interactions
    DAO -->|governance| Timelock
    Timelock -->|critical operations| Vault
    Timelock -->|critical operations| VaultManager
    Timelock -->|critical operations| ProviderManager
    
    %% Access Control
    AccessManager -->|role management| Vault
    AccessManager -->|role management| Rebalancer
    AccessManager -->|role management| VaultManager
    AccessManager -->|role management| ProviderManager
    
    %% Vault Manager Interactions
    VaultManager -->|manage| Vault
    VaultManager -->|manage| Rebalancer
    
    %% Vault Interactions
    Vault -->|use| ProviderManager
    Vault -->|interact| AaveV3Provider
    Vault -->|interact| CompoundV3Provider
    Vault -->|send fees| Treasury
    Vault -->|hold| ERC20Token
    
    %% Rebalancer Interactions
    Rebalancer -->|inherit from| Vault
    Rebalancer -->|use| ProviderManager
    Rebalancer -->|interact| AaveV3Provider
    Rebalancer -->|interact| CompoundV3Provider
    Rebalancer -->|send fees| Treasury
    
    %% Provider Manager
    ProviderManager -->|manage| AaveV3Provider
    ProviderManager -->|manage| CompoundV3Provider
    
    %% Provider to Protocol Interactions
    AaveV3Provider -->|interact| AaveV3
    CompoundV3Provider -->|interact| CompoundV3
    
    %% Styling
    classDef userLayer fill:#e1f5fe
    classDef coreLayer fill:#f3e5f5
    classDef vaultLayer fill:#e8f5e8
    classDef providerLayer fill:#fff3e0
    classDef externalLayer fill:#fce4ec
    classDef treasuryLayer fill:#f1f8e9
    
    class User,DAO userLayer
    class VaultManager,Timelock,AccessManager coreLayer
    class Vault,Rebalancer vaultLayer
    class ProviderManager,AaveV3Provider,CompoundV3Provider providerLayer
    class AaveV3,CompoundV3 externalLayer
    class Treasury,ERC20Token treasuryLayer
```

## Detailed Interaction Flow

### 1. User Operations Flow

```mermaid
sequenceDiagram
    participant User
    participant Vault
    participant Provider
    participant Treasury
    participant ExternalProtocol
    
    User->>Vault: deposit(assets)
    Vault->>Provider: deposit(assets)
    Provider->>ExternalProtocol: supply(assets)
    Vault->>User: mint(shares)
    
    User->>Vault: withdraw(assets)
    Vault->>Provider: withdraw(assets)
    Provider->>ExternalProtocol: withdraw(assets)
    Vault->>Treasury: transfer(fee)
    Vault->>User: transfer(assets - fee)
```

### 2. Rebalancing Flow

```mermaid
sequenceDiagram
    participant Operator
    participant Rebalancer
    participant FromProvider
    participant ToProvider
    participant Treasury
    participant ExternalProtocolA
    participant ExternalProtocolB
    
    Operator->>Rebalancer: rebalance(assets, from, to, fee)
    Rebalancer->>FromProvider: withdraw(assets)
    FromProvider->>ExternalProtocolA: withdraw(assets)
    Rebalancer->>ToProvider: deposit(assets - fee)
    ToProvider->>ExternalProtocolB: supply(assets - fee)
    Rebalancer->>Treasury: transfer(fee)
    Rebalancer->>Operator: success
```

### 3. Governance Flow

```mermaid
sequenceDiagram
    participant DAO
    participant Timelock
    participant Vault
    participant ProviderManager
    
    DAO->>Timelock: queue(updateProviders)
    Note over Timelock: Wait for delay period
    Timelock->>Vault: setProviders(newProviders)
    Vault->>ProviderManager: update providers
    ProviderManager->>Vault: confirm update
```


## Contract Dependencies

### Inheritance Hierarchy

```mermaid
graph TD
    ERC4626[ERC4626 Standard]
    PausableActions[PausableActions]
    AccessManager[AccessManager]
    
    Vault --> ERC4626
    Vault --> PausableActions
    Vault --> AccessManager
    
    Rebalancer --> Vault
    
    VaultManager --> AccessManager
    
    ProviderManager --> AccessManager
```

### Interface Implementations

```mermaid
graph LR
    IProvider[IProvider Interface]
    IVault[IVault Interface]
    
    AaveV3Provider --> IProvider
    CompoundV3Provider --> IProvider
    
    Vault --> IVault
    Rebalancer --> IVault
```

## Access Control Matrix

| Contract | Admin | Operator | Executor | Timelock |
|----------|-------|----------|----------|----------|
| Vault |   |   |   |   |
| Rebalancer |   |   |   |   |
| VaultManager |   |   |   |   |
| ProviderManager |   |   |   |   |
| Timelock |   |   |   |   |

## Data Flow Patterns

### 1. Asset Flow
```
User → Vault → Provider → External Protocol
```

### 2. Fee Flow
```
Vault/Rebalancer → Treasury
```

### 3. Governance Flow
```
DAO → Timelock → Target Contract
```

## Security Boundaries

### Critical Operations (Timelock Required)
- Provider updates
- Timelock address changes
- Major parameter changes

### Admin Operations
- Fee adjustments
- Treasury updates
- Emergency pauses
- Provider management

### Operator Operations
- Rebalancing execution
- Provider activation

### User Operations
- Deposits and withdrawals
- Reward claims
- Vault interactions

## Integration Points

### External Protocol Integration
- Aave V3: Lending and borrowing
- Compound V3: Supply and borrow

### Token Integration
- ERC20: Standard token interface
- ERC4626: Vault token standard
- WETH: Wrapped ETH handling

### Governance Integration
- DAO: Decentralized governance
- Multi-sig: Multi-signature wallets
- Timelock: Delayed execution

This diagram provides a comprehensive view of how all contracts interact within the Thesauros ecosystem, showing the flow of assets, control mechanisms, and security boundaries. 