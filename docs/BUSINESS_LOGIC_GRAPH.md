# Thesauros Business Logic Graph

## Overall Business Logic Architecture

```mermaid
graph TB
    %% Main components
    subgraph " User Layer"
        UI[Frontend UI]
        API[API Gateway]
    end
    
    subgraph "Core Services"
        LENDING[Lending Service]
        REBALANCER[Rebalancer Service]
        WORKERS[Worker Services]
    end
    
    subgraph "DeFi Integrations"
        PROVIDERS[DeFi Providers]
        POOLS[Pool Management]
        VAULTS[Vault Contracts]
    end
    
    subgraph "Data"
        DB[(PostgreSQL)]
        CACHE[Cache Layer]
        SUBGRAPH[Subgraph Data]
    end
    
    subgraph "Security"
        SAFE[Safe Protocol]
        AWS[AWS Secrets]
    end
    
    %% Connections
    UI --> API
    API --> LENDING
    API --> REBALANCER
    LENDING --> DB
    LENDING --> CACHE
    REBALANCER --> PROVIDERS
    REBALANCER --> SAFE
    WORKERS --> DB
    WORKERS --> SUBGRAPH
    PROVIDERS --> POOLS
    POOLS --> VAULTS
    SAFE --> AWS
```

## Main Business Processes

### 1. Automatic Rebalancing

```mermaid
sequenceDiagram
    participant Cron as Cron Job
    participant Rebalancer as Rebalancer Service
    participant Pool as Pool Manager
    participant Providers as DeFi Providers
    participant Safe as Safe Protocol
    participant Blockchain as Blockchain
    
    Cron->>Rebalancer: Start rebalancing
    Rebalancer->>Pool: Get current rates
    Pool->>Providers: Multicall - deposit rates
    Providers-->>Pool: Rates from all providers
    Pool->>Pool: Find best provider
    Pool-->>Rebalancer: Rebalancing recommendation
    
    alt Better provider exists
        Rebalancer->>Safe: Create transaction
        Safe->>Blockchain: Propose transaction
        Blockchain-->>Safe: Transaction hash
        Safe-->>Rebalancer: Successfully proposed
    else No better provider
        Rebalancer->>Rebalancer: Skip rebalancing
    end
```

### 2. Rewards and Points System

```mermaid
graph LR
    subgraph "User Actions"
        DEPOSIT[Deposit]
        LOCK[Lock]
        TASKS[Task Completion]
        SOCIAL[Social Activity]
    end
    
    subgraph "Calculation System"
        POINTS[Points System]
        RBLN[RBLN Tokens]
        MERKLE[Merkle Tree]
    end
    
    subgraph "Distribution"
        REWARDS[Rewards]
        CLAIM[Reward Claims]
        DISTRIBUTION[Distribution]
    end
    
    DEPOSIT --> POINTS
    LOCK --> POINTS
    TASKS --> POINTS
    SOCIAL --> POINTS
    
    POINTS --> RBLN
    RBLN --> MERKLE
    MERKLE --> REWARDS
    REWARDS --> CLAIM
    CLAIM --> DISTRIBUTION
```

### 3. Monitoring and Data Collection

```mermaid
graph TB
    subgraph "Data Sources"
        BLOCKCHAIN[Blockchain Events]
        SUBGRAPH[Subgraph Queries]
        MORALIS[Moralis API]
    end
    
    subgraph "Worker Services"
        WORKER[Pool Data Worker]
        LOCKPERM[Lock Perm Worker]
        POINTS[Points Worker]
        REWARDS[Rewards Worker]
    end
    
    subgraph "Storage"
        POOL_ENTITIES[Pool Entities]
        PROVIDER_ENTITIES[Provider Entities]
        USER_ENTITIES[User Entities]
        CACHE_ENTITIES[Cache Entities]
    end
    
    BLOCKCHAIN --> WORKER
    SUBGRAPH --> LOCKPERM
    SUBGRAPH --> POINTS
    SUBGRAPH --> REWARDS
    MORALIS --> WORKER
    
    WORKER --> POOL_ENTITIES
    WORKER --> PROVIDER_ENTITIES
    LOCKPERM --> USER_ENTITIES
    POINTS --> USER_ENTITIES
    REWARDS --> USER_ENTITIES
    WORKER --> CACHE_ENTITIES
```

## DeFi Providers and Integrations

### Supported Protocols

```mermaid
graph LR
    subgraph "Lending Protocols"
        AAVE[Aave V3]
        COMPOUND[Compound V3]
        SILO[Silo]
        RADIANT[Radiant V2]
        KINZA[Kinza Binance]
        LODESTAR[Lodestar]
    end
    
    
    subgraph "Management"
        POOL_MANAGER[Pool Manager]
        VAULT_MANAGER[Vault Manager]
        REBALANCER[Rebalancer]
    end
    
    AAVE --> POOL_MANAGER
    COMPOUND --> POOL_MANAGER
    SILO --> POOL_MANAGER
    RADIANT --> POOL_MANAGER
    KINZA --> POOL_MANAGER
    LODESTAR --> POOL_MANAGER
    
    
    POOL_MANAGER --> VAULT_MANAGER
    VAULT_MANAGER --> REBALANCER
```

## API and Business Logic

### Main Endpoints and Their Logic

```mermaid
graph TB
    subgraph "Lending API"
        GET_LENDING[GET /lending]
        APR_TICKS[GET /lending/:token/apr-ticks]
        USER_EARNED[GET /lending/:token/user-earned]
        USER_POINTS[GET /lending/user-points]
        USER_LOCKS[GET /lending/user-locks]
        REWARDS_CLAIM[GET /lending/rewards-claim-details]
    end
    
    subgraph "Business Logic"
        CALC_APR[APR Calculation]
        CALC_EARNED[Earnings Calculation]
        CALC_POINTS[Points Calculation]
        CALC_RBLN[RBLN Calculation]
        MERKLE_TREE[Merkle Tree Generation]
    end
    
    subgraph "Data Sources"
        POOL_DATA[Pool Data]
        USER_DATA[User Data]
        CACHE_DATA[Cache Data]
        SUBGRAPH_DATA[Subgraph Data]
    end
    
    GET_LENDING --> CALC_APR
    APR_TICKS --> CALC_APR
    USER_EARNED --> CALC_EARNED
    USER_POINTS --> CALC_POINTS
    USER_LOCKS --> USER_DATA
    REWARDS_CLAIM --> CALC_RBLN
    
    CALC_APR --> POOL_DATA
    CALC_EARNED --> USER_DATA
    CALC_POINTS --> USER_DATA
    CALC_RBLN --> MERKLE_TREE
    
    POOL_DATA --> CACHE_DATA
    USER_DATA --> CACHE_DATA
    MERKLE_TREE --> SUBGRAPH_DATA
```

## Security and Transactions

### Secure Transaction Process

```mermaid
sequenceDiagram
    participant Rebalancer as Rebalancer
    participant Safe as Safe Protocol
    participant API as Safe API
    participant Blockchain as Blockchain
    participant Wallet as Wallet
    
    Rebalancer->>Safe: Create transaction
    Safe->>Safe: Sign transaction
    Safe->>API: Propose transaction
    API->>Blockchain: Save proposal
    
    Note over Rebalancer,Blockchain: Waiting for confirmation
    
    Wallet->>API: Approve transaction
    API->>Blockchain: Confirm transaction
    
    Note over Rebalancer,Blockchain: Waiting for execution
    
    Wallet->>API: Execute transaction
    API->>Blockchain: Execute transaction
    Blockchain-->>API: Transaction result
    API-->>Wallet: Successful execution
```

## Gamification System

### Points and Rewards Logic

```mermaid
graph TB
    subgraph "User Actions"
        CONNECT[Wallet Connection]
        DEPOSIT[Fund Deposit]
        LOCK[Asset Locking]
        SOCIAL[Social Activity]
        TASKS[Task Completion]
    end
    
    subgraph "Calculation System"
        POINTS_CALC[Points Calculation]
        RBLN_CALC[RBLN Calculation]
        WEIGHT[Weighted Calculation]
    end
    
    subgraph "Rewards"
        MERKLE_GEN[Merkle Tree Generation]
        REWARD_DIST[Reward Distribution]
        CLAIM_PROC[Claim Process]
    end
    
    CONNECT --> POINTS_CALC
    DEPOSIT --> POINTS_CALC
    LOCK --> POINTS_CALC
    SOCIAL --> POINTS_CALC
    TASKS --> POINTS_CALC
    
    POINTS_CALC --> WEIGHT
    WEIGHT --> RBLN_CALC
    RBLN_CALC --> MERKLE_GEN
    MERKLE_GEN --> REWARD_DIST
    REWARD_DIST --> CLAIM_PROC
```

## Monitoring and Analytics

### Monitoring System

```mermaid
graph LR
    subgraph " Metrics Collection"
        PERFORMANCE[Performance]
        ERRORS[Errors]
        TRANSACTIONS[Transactions]
        USER_ACTIVITY[User Activity]
    end
    
    subgraph " Notifications"
        TELEGRAM[Telegram Bot]
        ALERTS[Alert System]
        LOGS[Logging]
    end
    
    subgraph " Analytics"
        DASHBOARD[Dashboard]
        REPORTS[Reports]
        METRICS[Metrics]
    end
    
    PERFORMANCE --> TELEGRAM
    ERRORS --> ALERTS
    TRANSACTIONS --> LOGS
    USER_ACTIVITY --> DASHBOARD
    
    TELEGRAM --> REPORTS
    ALERTS --> METRICS
    LOGS --> DASHBOARD
```

## Data Lifecycle

### Data Flow in the System

```mermaid
graph TB
    subgraph " Sources"
        BLOCKCHAIN_EVENTS[Blockchain Events]
        SUBGRAPH_QUERIES[Subgraph Queries]
        USER_ACTIONS[User Actions]
    end
    
    subgraph " Processing"
        WORKERS[Worker Services]
        CACHE[Cache Services]
        API[API Services]
    end
    
    subgraph " Storage"
        POSTGRES[PostgreSQL]
        CACHE_STORAGE[Cache Storage]
        MERKLE_FILES[Merkle Tree Files]
    end
    
    subgraph " Presentation"
        API_RESPONSES[API Responses]
        DASHBOARDS[Dashboards]
        NOTIFICATIONS[Notifications]
    end
    
    BLOCKCHAIN_EVENTS --> WORKERS
    SUBGRAPH_QUERIES --> WORKERS
    USER_ACTIONS --> API
    
    WORKERS --> POSTGRES
    WORKERS --> CACHE_STORAGE
    API --> CACHE
    CACHE --> CACHE_STORAGE
    
    POSTGRES --> API_RESPONSES
    CACHE_STORAGE --> API_RESPONSES
    API_RESPONSES --> DASHBOARDS
    API_RESPONSES --> NOTIFICATIONS
```

## Key Business Metrics

### Main System KPIs

```mermaid
graph TB
    subgraph " Financial Metrics"
        TVL[Total Value Locked]
        APR[Average APR]
        EARNINGS[User Earnings]
        REBALANCE_FREQ[Rebalance Frequency]
    end
    
    subgraph " User Metrics"
        ACTIVE_USERS[Active Users]
        USER_RETENTION[User Retention]
        POINTS_DISTRIBUTION[Points Distribution]
        REWARDS_CLAIMED[Rewards Claimed]
    end
    
    subgraph "Technical Metrics"
        UPTIME[System Uptime]
        TRANSACTION_SUCCESS[Transaction Success Rate]
        CACHE_HIT_RATE[Cache Hit Rate]
        RESPONSE_TIME[API Response Time]
    end
    
    subgraph "Analytics"
        PERFORMANCE_DASHBOARD[Performance Dashboard]
        USER_ANALYTICS[User Analytics]
        FINANCIAL_REPORTS[Financial Reports]
        SYSTEM_HEALTH[System Health]
    end
    
    TVL --> PERFORMANCE_DASHBOARD
    APR --> FINANCIAL_REPORTS
    EARNINGS --> USER_ANALYTICS
    REBALANCE_FREQ --> SYSTEM_HEALTH
    
    ACTIVE_USERS --> USER_ANALYTICS
    USER_RETENTION --> PERFORMANCE_DASHBOARD
    POINTS_DISTRIBUTION --> USER_ANALYTICS
    REWARDS_CLAIMED --> FINANCIAL_REPORTS
    
    UPTIME --> SYSTEM_HEALTH
    TRANSACTION_SUCCESS --> PERFORMANCE_DASHBOARD
    CACHE_HIT_RATE --> SYSTEM_HEALTH
    RESPONSE_TIME --> PERFORMANCE_DASHBOARD
```

---

## Business Logic Summary

### Main Business Processes:

1. **Automatic Rebalancing** - continuous monitoring and switching between providers to maximize APR
2. **Rewards System** - gamification with points and RBLN tokens to increase user activity
3. **Secure Transactions** - multisig transactions through Safe Protocol
4. **Data Monitoring** - collection and analysis of data from blockchain and subgraph
5. **API Services** - providing data for frontend and external integrations

### Key Features:

- **Multi-chain Support** (Arbitrum, BSC, Base)
- **Integration with 15+ DeFi Protocols**
- **Caching System** for performance optimization
- **Telegram Notifications** for monitoring
- **Merkle Tree** for efficient reward distribution
- **TypeScript** for type safety
- **Nx Monorepo** for scalability