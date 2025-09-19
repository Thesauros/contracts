# Thesauros Backend

[![Nx](https://img.shields.io/badge/Nx-16.5.1-blue)](https://nx.dev)
[![NestJS](https://img.shields.io/badge/NestJS-10.0.2-red)](https://nestjs.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.1.3-blue)](https://www.typescriptlang.org)

> **DeFi (Decentralized Finance) project for automatic rebalancing of crypto assets between various lending protocols**

## Project Overview

Thesauros Backend is a comprehensive system for automatic crypto asset management that maximizes user returns by automatically switching between various lending protocols based on current APR rates.

### Key Features

- **Automatic rebalancing** of assets between lending protocols
- **Real-time APR monitoring**
- **Points and rewards system** (RBLN tokens)
- **Asset lock management**
- **Gamification** with task system
- **Secure transactions** through Safe (Gnosis Safe)

## Architecture

The project is built on **Nx monorepo** using **NestJS**:

```
backend-ts/
├── apps/
│   ├── api/                 # REST API service
│   ├── rebalancer/          # Automatic rebalancing
│   ├── worker/              # Pool data collection
│   ├── worker-lockperm/     # Permanent lock processing
│   ├── worker-points/       # User points system
│   └── worker-rewards/      # Reward distribution
├── libs/                    # Shared libraries
│   ├── database/           # Database and entities
│   ├── enums/              # Enumerations
│   ├── providers/          # DeFi protocol integrations
│   ├── pools/              # Pool management
│   └── ...
└── abis/                   # Contract ABIs
```

## Supported Networks and Tokens

### Networks
- **Arbitrum** (main network)
- **BSC** (Binance Smart Chain)
- **Base**

### Tokens
- **Stablecoins:** USDT, USDC, USDC.e
- **Major tokens:** wBTC, wETH, wBNB, ARB

## Integrated Protocols

The project supports over 15 DeFi lending protocols:

- **Aave V3** - Largest lending protocol
- **Compound V3** - Protocol with algorithmic rates
- **Silo** - Protocol with isolated pools
- **Radiant V2** - Cross-chain protocol
- **And others...**

## Technical Stack

### Backend
- **NestJS** - Node.js framework
- **TypeScript** - Typed JavaScript
- **TypeORM** - ORM for database operations
- **PostgreSQL** - Relational database

### Blockchain
- **Ethers.js** - Ethereum library
- **TypeChain** - Smart contract type generation
- **Safe Protocol Kit** - Secure multisig transactions

### Infrastructure
- **Nx** - Monorepo and build tools
- **AWS Secrets Manager** - Secret management
- **Moralis** - Blockchain data API
- **Telegram Bot** - Notifications and monitoring

## Installation and Setup

### Prerequisites

- Node.js 18+
- Yarn
- PostgreSQL
- AWS CLI (for Secrets Manager)

### Installing Dependencies

```bash
yarn install
```

### Getting Contract ABIs

1. Clone the contracts repository:
```bash
git clone https://github.com/REBALANCE-Finance/lending-contracts
cd lending-contracts
npm install
npx hardhat compile
```

2. Copy `.json` files from `artifacts/contracts/` to the `abis/` folder

3. Generate types:
```bash
yarn typechain
```

### Environment Setup

Create a `.env` file with necessary variables:

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/rebalance_finance

# AWS Secrets Manager
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Blockchain
NETWORK=Arbitrum
PRIVATE_KEY=your_private_key

# Telegram Bot
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# Moralis
MORALIS_API_KEY=your_moralis_key
```

### Starting Services

```bash
# API service
yarn start:api

# Rebalancer
yarn start:rebalancer

# Worker services
nx serve worker
nx serve worker-lockperm
nx serve worker-points
nx serve worker-rewards
```

## API Endpoints

### Main Endpoints

- `GET /lending` - Get lending data
- `GET /lending/:token/apr-ticks/:interval/:intervals` - APR by intervals
- `GET /lending/:token/user-earned/:userAddress` - User earnings
- `GET /lending/user-points/:userAddress` - User points
- `GET /lending/user-locks/:userAddress` - User locks
- `GET /lending/rewards-claim-details/:userAddress` - Reward details

### Swagger Documentation

After starting the API service, documentation is available at:
```
http://localhost:3000/api
```

## Security

### Multisig Transactions
- All transactions are executed through **Safe (Gnosis Safe)**
- Support for modes: Propose → Approve → Execute
- Requires confirmation from multiple owners

### Secret Management
- **AWS Secrets Manager** for storing private keys
- Encryption of sensitive data
- Key rotation

## Monitoring and Analytics

### Telegram Notifications
- Rebalancing notifications
- Error monitoring
- Performance statistics

### Caching
- Subgraph data cache
- Token price cache
- User balance cache

## Rewards System

### RBLN Tokens
- Awarded for activity
- Calculated based on amount and lock time
- Merkle tree for reward distribution

### Points System
- Points for various actions
- Gamification to increase activity
- Task and achievement system

## Development

### Code Structure
- **TypeScript** for typing
- **ESLint** and **Prettier** for formatting
- **Jest** for testing

### Development Commands

```bash
# Generate contract types
yarn typechain

# Run tests
nx test

# Linting
nx lint

# Formatting
nx format:write
```

## License

MIT License

## Links

- [NestJS Documentation](https://nestjs.com)
- [Nx Documentation](https://nx.dev)
- [Safe Protocol Kit](https://docs.safe.global)
- [Moralis API](https://docs.moralis.io)

--