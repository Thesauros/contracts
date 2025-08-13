# Thesauros Strategy Monitoring Guide

This guide will help you set up and run monitoring for your Thesauros strategy.

## What We've Created

We've built a comprehensive monitoring system for your Thesauros strategy with the following components:

### Monitoring Scripts
- **`monitor-vaults.ts`** - Real-time vault status monitoring
- **`monitor-apy-simple.ts`** - Simplified APY analysis
- **`monitor-apy-real.ts`** - Real APY data from APIs
- **`monitor-events.ts`** - Real-time event monitoring
- **`auto-rebalance.ts`** - Automated rebalancing bot

### Utility Scripts
- **`show-addresses.ts`** - Display all contract addresses
- **`setup-vaults.ts`** - Vault setup and configuration

### Documentation
- **`MONITORING.md`** - Complete monitoring guide (this file)
- **Updated `package.json`** - Added convenient npm scripts

### Configuration
- **Environment variables** - RPC URLs, private keys, API keys
- **Interval settings** - Configurable monitoring frequencies
- **Rebalancing parameters** - APY thresholds, gas limits

## Quick Start

### 1. Web Dashboard (Recommended)

For convenient monitoring through web interface:

```bash
# Start the dashboard
npm run ui:dev

# Open in browser
http://localhost:3001
```

**Web Dashboard Features:**
- Real-time data updates
- Mobile responsive design
- Live data visualization
- Simple and intuitive interface
- APY and TVL visualization

### 2. Command Line Scripts

For monitoring through command line:

```bash
# General vault monitoring
npm run monitor:vaults

# APY analysis (simple version)
npm run monitor:apy-simple

# APY analysis (real version)
npm run monitor:apy-real

# Event monitoring
npm run monitor:events

# Automatic rebalancing
npm run monitor:rebalance
```

### 3. Environment Setup

Create a `.env` file in the project root:

```bash
# Network Configuration (automatically set by update-config script)
ARBITRUM_ONE_RPC_URL=https://arb1.arbitrum.io/rpc
# or use Alchemy/Infura
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# Private key (for automatic rebalancing)
PRIVATE_KEY=your_private_key_here

# API keys (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key
ALCHEMY_API_KEY=your_alchemy_api_key
```

### 4. Network Configuration

The monitoring system automatically loads contract addresses from the deployment configuration. To switch networks:

```bash
# Update configuration for a different network
npm run update-config arbitrumOne    # Arbitrum One (mainnet)
npm run update-config arbitrumSepolia # Arbitrum Sepolia (testnet)
npm run update-config mainnet        # Ethereum mainnet
npm run update-config polygon        # Polygon

# This will update:
# - hardhat.config.ts network settings
# - .env file with correct RPC URLs
# - package.json scripts to use the new network
```

### 5. Install Dependencies

```bash
npm install
```

### 6. Start Monitoring

```bash
# Individual monitoring
npm run monitor:vaults        # Vault status
npm run monitor:apy-simple    # APY analysis (simplified - simulated data)
npm run monitor:apy-real      # APY analysis (real data from APIs)
npm run monitor:events        # Real-time events
npm run monitor:rebalance     # Automatic rebalancing
npm run show:addresses        # Show contract addresses
```

## Types of Monitoring

## Web Dashboard

### Features

**Dashboard Tab:**
- General overview of TVL, APY and provider status
- Quick actions (data refresh, Arbiscan links)
- Live network statistics

**Vaults Tab:**
- Detailed information for each vault
- TVL, number of shares, active provider
- Status and contract addresses

**Providers Tab:**
- Status of all liquidity providers
- Balances and contract state
- Error information

**APY Analysis Tab:**
- APY comparison by tokens
- Data sources (simulated/real)
- Statistics (average, maximum, minimum)

**Events Tab:**
- Recent blockchain events
- Links to transactions in Arbiscan
- Operation execution status

### Real-time Updates

Dashboard uses HTTP polling for updates:
- Automatic refresh every 30 seconds
- Instant event notifications
- Live network statistics

### Mobile Support

Fully responsive design:
- Optimized for mobile devices
- Touch-friendly interface
- Responsive grid layout

## Dynamic Address Configuration

The monitoring system now uses dynamic address loading instead of hardcoded addresses. This provides several benefits:

### How It Works

1. **Configuration Loading**: All contract addresses are loaded from `deployments/<network>/deployed-vaults.json`
2. **Network Flexibility**: Easy switching between networks without code changes
3. **Automatic Validation**: Configuration is validated before monitoring starts
4. **Error Handling**: Clear error messages if configuration is missing or invalid

### Configuration Structure

```json
{
  "network": "arbitrumOne",
  "chainId": 42161,
  "vaults": {
    "WETH": {
      "address": "0x78c11f63E6840820be18fDA461Ab16f23da5884f",
      "name": "Thesauros WETH Vault",
      "symbol": "tWETH",
      "asset": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
    }
  },
  "baseContracts": {
    "VaultManager": {
      "address": "0xAeEcf7F780e88B155df330434Ef29b2B077024e0"
    },
    "AaveV3Provider": {
      "address": "0xE1Cfb1BDb3901dcEe9F21146c1F299c775d9B65C"
    }
  },
  "tokenAddresses": {
    "WETH": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    "USDC": "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
  }
}
```

### Adding New Networks

1. Deploy contracts to the new network
2. Create `deployments/<network>/deployed-vaults.json`
3. Run `npm run update-config <network>`
4. Start monitoring with `npm run monitor`

## APY Data Sources Explained

### Simulated vs Real Data

Our monitoring system provides different levels of APY data accuracy:

#### 1. **Simulated Data** (`monitor-apy-simple.ts`)
- **Source**: Mathematical simulation based on provider balances
- **Accuracy**: Low - for demonstration purposes only
- **Formula**: `baseAPY + balanceFactor + randomFactor`
- **Use case**: Testing and development

#### 2. **Real Data** (`monitor-apy-real.ts`)
- **Source**: Multiple real-world APIs and smart contracts
- **Accuracy**: High - actual protocol data
- **Sources**: 
  - DefiLlama API (TVL data)
  - Aave API (official rates)
  - Compound API (official rates)
  - Smart contract queries (real-time)
- **Use case**: Production monitoring and decision making

### Current Real APY Data (as of latest run):
- **WETH**: 2.27% (Aave V3)
- **USDC**: 4.55% (Aave V3)
- **USDT**: 4.32% (Aave V3)
- **DAI**: 11.38% (Aave V3)

**Note**: These are real rates from Aave V3 on Arbitrum One, fetched directly from smart contracts.

## Detailed Monitoring Scripts

### 1. Vault Status Monitor (`monitor-vaults.ts`)

**What it tracks:**
- TVL (Total Value Locked) of each vault
- Active providers
- Total shares
- Recent rebalancing
- Overall statistics for all vaults

**Run:**
```bash
npm run monitor:vaults
```

**Example output:**
```
Thesauros Vaults Monitoring Dashboard
========================================

Vault Status Report
======================

WETH Vault
   Address: 0x78c11f63E6840820be18fDA461Ab16f23da5884f
   Symbol: tWETH
   TVL: 1250.5 WETH
   Total Shares: 1248.2
   Active Provider: AaveV3Provider
   Last Rebalance: Block 12345678
```

### 2. Simple APY Monitor (`monitor-apy-simple.ts`)

**What it tracks:**
- Provider status and availability
- Simulated APY based on provider balances
- Vault provider analysis
- Basic rebalancing recommendations

**Data Source:** Simulated data (for demonstration purposes)

**Run:**
```bash
npm run monitor:apy-simple
```

### 3. Real APY Monitor (`monitor-apy-real.ts`)

**What it tracks:**
- Real APY data from multiple sources
- DefiLlama API integration
- Aave and Compound protocol APIs
- Smart contract direct queries
- Cross-source data validation

**Data Sources:**
- **DefiLlama API**: Aggregated DeFi protocol data
- **Aave API**: Official Aave protocol data
- **Compound API**: Official Compound protocol data
- **Smart Contracts**: Direct blockchain queries

**Run:**
```bash
npm run monitor:apy-real
```

**Example output:**
```
Thesauros Real APY Data Monitor
===================================

Available APY Data Sources:
================================

DefiLlama API
   URL: https://api.llama.fi/protocols
   Description: Aggregated DeFi protocol data

Aave API
   URL: https://api.aave.com/v3/protocol-data
   Description: Official Aave protocol data

Attempting to fetch real APY data...
========================================

Fetching from DefiLlama API...
   Aave found: AAVE V3
   TVL: $39511.13M
   Compound found: Compound V3
   TVL: $2533.75M

Fetching from smart contracts...
   Aave V3 - WETH: 2.2719% APY
   Aave V3 - USDC: 4.5471% APY
   Aave V3 - USDT: 4.3165% APY
   Aave V3 - DAI: 11.3817% APY

Real APY Data Summary
=========================

WETH APY Data:
------------------------------
   Aave V3: 2.2719% (Smart Contract)
   Best: Aave V3 (2.2719%)

USDC APY Data:
------------------------------
   Aave V3: 4.5471% (Smart Contract)
   Best: Aave V3 (4.5471%)

Overall Statistics:
=====================
Average APY: 5.6293%
Highest APY: 11.3817%
Lowest APY: 2.2719%
APY Spread: 9.1098%
Total data points: 4
Data sources: 1
```

### 4. Real-time Event Monitor (`monitor-events.ts`)

**What it tracks:**
- Real-time rebalancing events
- Deposits and withdrawals
- Timelock events
- Fee events

**Run:**
```bash
npm run monitor:events
```

**Example output:**
```
Thesauros Real-time Event Monitor
====================================

New Event Detected!
   Contract: USDC Vault
   Event: RebalanceExecuted
   Block: 12345678
   Time: 12/19/2024, 3:45:30 PM
   TX: 0x1234...5678
   Assets From: 1000000.0
   Assets To: 1000000.0
   From Provider: 0xE1Cf...B65C
   To Provider: 0x4382...2aD5
```

### 5. Auto-Rebalancing Bot (`auto-rebalance.ts`)

**What it does:**
- Analyzes APY of all providers
- Finds rebalancing opportunities
- Calculates potential profit
- Performs automatic rebalancing (optional)

**Run:**
```bash
npm run monitor:rebalance
```

**Example output:**
```
Thesauros Auto-Rebalancing Bot
==================================

Analyzing rebalancing opportunities...

Analyzing USDC Vault...
   AaveV3Provider: 4.3300% APY
   CompoundV3Provider: 3.8500% APY
   Current Provider: AaveV3Provider (4.3300%)
   Best Provider: AaveV3Provider (4.3300%)
   APY Difference: 0.0000%

Rebalancing Opportunities Found:
===================================

No profitable rebalancing opportunities found
```

## Monitoring Configuration

### Interval Configuration

Edit the monitoring scripts to configure intervals:

```typescript
// Example: Set monitoring interval in seconds
const MONITORING_INTERVAL = 300; // 5 minutes
```

### Automatic Rebalancing Configuration

In the `scripts/auto-rebalance.ts` file, configure parameters:

```typescript
// Minimum APY difference for rebalancing
const MIN_APY_DIFFERENCE = 0.5; // 0.5%

// Minimum amount for rebalancing
const MIN_REBALANCE_AMOUNT = ethers.parseUnits('100', 6); // 100 USDC
```

## Metrics to Track

### Key Indicators

1. **TVL (Total Value Locked)**
   - Total value of locked assets
   - Growth/decline trend

2. **APY (Annual Percentage Yield)**
   - Yield for each provider
   - Comparison between providers

3. **Rebalancing Frequency**
   - Number of rebalancing per day/week
   - Strategy efficiency

4. **Fees**
   - Rebalancing fees
   - Withdrawal fees

5. **Gas**
   - Gas cost for operations
   - Optimal time for rebalancing

### Alerts and Notifications

It is recommended to set up alerts for:

- APY falling below a certain level
- Significant TVL changes
- Rebalancing errors
- High gas prices

## Troubleshooting

### Common Issues

1. **RPC Connection Error**
   ```
    Network connection failed
   ```
   **Solution:** Check the URL in the `.env` file

2. **Contract Not Found**
   ```
    Contract not found
   ```
   **Solution:** Make sure contracts are deployed on the correct network

3. **Private Key Error**
   ```
    Error: PRIVATE_KEY environment variable not set
   ```
   **Solution:** Add private key to the `.env` file

4. **High Gas Consumption**
   ```
    Gas cost exceeds daily profit
   ```
   **Solution:** Wait for gas prices to decrease

### Logs and Debugging

Enable detailed logs:

```bash
# With detailed output
DEBUG=* npm run monitor:vaults

# With log saving to file
npm run monitor:vaults > logs/vaults.log 2>&1
```

## Security

### Recommendations

1. **Private Keys**
   - Never commit private keys to Git
   - Use environment variables
   - Consider using hardware wallets

2. **RPC Endpoints**
   - Use reliable RPC providers
   - Set up backup endpoints
   - Monitor API limits

3. **Automatic Rebalancing**
   - Start with small amounts
   - Set operation limits
   - Regularly check logs

## Support

### Useful Commands

```bash
# Show contract addresses
npm run show:addresses

# Check network status
npx hardhat console --network arbitrumOne

# Run tests
npm run test:mocking
```

### Documentation

- [System Architecture](docs/architecture.md)
- [Contracts](docs/contracts/)
- [Security](docs/security/)

## Usage Examples

### Production Monitoring

```bash
# Run in background
nohup npm run monitor:vaults > monitoring.log 2>&1 &

# Check status
ps aux | grep "monitor"

# Stop
pkill -f "monitor"
```

### Setting up cron for regular checks

```bash
# Add to crontab
# Check every 5 minutes
*/5 * * * * cd /path/to/project && npm run monitor:vaults

# Check APY every hour
0 * * * * cd /path/to/project && npm run monitor:apy-real
```

### Integration with External Systems

```bash
# Send notifications to Slack
npm run monitor:apy-real | curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"APY Report: $(cat)"}' \
  https://hooks.slack.com/services/YOUR_WEBHOOK
```

---

**Happy monitoring!**
